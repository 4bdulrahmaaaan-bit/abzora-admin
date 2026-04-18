import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'app_config.dart';
import 'card_vault_service.dart';

class PaymentCheckoutResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? externalWallet;
  final bool isVerified;

  const PaymentCheckoutResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.externalWallet,
    this.isVerified = false,
  });
}

class PaymentRefundResult {
  final bool success;
  final String? refundId;
  final String? message;

  const PaymentRefundResult({
    required this.success,
    this.refundId,
    this.message,
  });
}

class PaymentService {
  Razorpay? _razorpay;
  Completer<PaymentCheckoutResult>? _paymentCompleter;
  Completer<PaymentCardVaultResult>? _cardVaultCompleter;

  Future<PaymentCheckoutResult> processCheckout({
    required BuildContext context,
    required String userId,
    String? backendOrderId,
    required String name,
    required double amount,
    required String email,
    required String contact,
    required String description,
  }) async {
    if (!AppConfig.hasRazorpayKey) {
      throw StateError('Online payments are not configured right now. Please use Cash on Delivery.');
    }

    _paymentCompleter = Completer<PaymentCheckoutResult>();
    _razorpay = Razorpay();
    _razorpay!
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    final orderPayload = await _createCheckoutOrder(
      backendOrderId: backendOrderId,
      amount: amount,
      description: description,
    );

    final options = {
      'key': AppConfig.razorpayKey,
      'amount': orderPayload.amountInPaise,
      if (orderPayload.orderId.isNotEmpty) 'order_id': orderPayload.orderId,
      'currency': orderPayload.currency,
      'name': 'ABZORA',
      'description': description,
      'prefill': {
        'contact': contact,
        'email': email,
        'name': name,
      },
      'method': {
        'upi': true,
        'card': true,
        'wallet': true,
        'netbanking': false,
        'emi': false,
      },
      'external': {
        'wallets': ['paytm']
      },
      'notes': {
        'flow': 'checkout',
        'userId': userId,
      },
    };

    try {
      _razorpay!.open(options);
      final result = await _paymentCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          if (!(_paymentCompleter?.isCompleted ?? true)) {
            _paymentCompleter?.complete(const PaymentCheckoutResult(success: false));
          }
          return const PaymentCheckoutResult(success: false);
        },
      );
      if (!result.success) {
        return result;
      }
      return _verifyPaymentIfNeeded(result, backendOrderId: backendOrderId);
    } catch (error) {
      debugPrint('Razorpay error: $error');
      _paymentCompleter?.complete(const PaymentCheckoutResult(success: false));
      return const PaymentCheckoutResult(success: false);
    } finally {
      dispose();
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!(_paymentCompleter?.isCompleted ?? true)) {
      _paymentCompleter?.complete(
        PaymentCheckoutResult(
          success: true,
          paymentId: response.paymentId,
          orderId: response.orderId,
          signature: response.signature,
          isVerified: false,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!(_paymentCompleter?.isCompleted ?? true)) {
      _paymentCompleter?.complete(const PaymentCheckoutResult(success: false));
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!(_paymentCompleter?.isCompleted ?? true)) {
      _paymentCompleter?.complete(
        PaymentCheckoutResult(
          success: true,
          externalWallet: response.walletName,
          isVerified: false,
        ),
      );
    }
  }

  Future<PaymentCheckoutResult> _verifyPaymentIfNeeded(
    PaymentCheckoutResult result, {
    String? backendOrderId,
  }) async {
    if (!result.success) {
      return result;
    }
    if (result.externalWallet != null && result.externalWallet!.isNotEmpty) {
      return PaymentCheckoutResult(
        success: true,
        paymentId: result.paymentId,
        orderId: result.orderId,
        signature: result.signature,
        externalWallet: result.externalWallet,
        isVerified: true,
      );
    }
    if (!AppConfig.hasRazorpayVerificationEndpoint) {
      throw StateError('Online payment verification is not configured right now.');
    }
    if (backendOrderId == null || backendOrderId.isEmpty) {
      throw StateError('Secure payment verification requires a valid backend order.');
    }
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Please sign in again before continuing to payment.');
    }
    final response = await http
        .post(
          Uri.parse(AppConfig.effectiveRazorpayVerificationEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'orderId': backendOrderId,
            'paymentId': result.paymentId,
            'signature': result.signature,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Payment verification failed. Please try again.');
    }
    final payload = jsonDecode(response.body);
    final data = payload is Map && payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload is Map
            ? Map<String, dynamic>.from(payload)
            : const <String, dynamic>{};
    final verified = data['verified'] == true;
    if (!verified) {
      throw StateError('Payment verification failed. Please contact support if you were charged.');
    }
    return PaymentCheckoutResult(
      success: true,
      paymentId: result.paymentId,
      orderId: result.orderId,
      signature: result.signature,
      externalWallet: result.externalWallet,
      isVerified: true,
    );
  }

  Future<PaymentRefundResult> refundPayment({
    required String paymentId,
    required String refundRequestId,
    String? reason,
  }) async {
    if (!AppConfig.hasRazorpayRefundEndpoint) {
      throw StateError('Refund processing is not configured right now.');
    }

    final response = await http
        .post(
          Uri.parse(AppConfig.razorpayRefundEndpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'paymentId': paymentId,
            'refundRequestId': refundRequestId,
            'reason': reason?.trim() ?? '',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Refund could not be processed right now.');
    }

    final payload = jsonDecode(response.body);
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const <String, dynamic>{};
    final success = map['success'] == true || map['refunded'] == true;
    if (!success) {
      throw StateError(map['message']?.toString() ?? 'Refund could not be processed right now.');
    }

    return PaymentRefundResult(
      success: true,
      refundId: map['refundId']?.toString() ?? map['id']?.toString(),
      message: map['message']?.toString(),
    );
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  Future<_RazorpayOrderPayload> _createCheckoutOrder({
    String? backendOrderId,
    required double amount,
    required String description,
  }) async {
    final amountInPaise = (amount * 100).round();
    if (!AppConfig.hasRazorpayOrderEndpoint) {
      return _RazorpayOrderPayload(
        orderId: '',
        currency: 'INR',
        amountInPaise: amountInPaise,
      );
    }

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Please sign in again before continuing to payment.');
    }

    if (backendOrderId == null || backendOrderId.isEmpty) {
      throw StateError('Secure payment setup requires a valid backend order.');
    }

    final response = await http
        .post(
          Uri.parse(AppConfig.effectiveRazorpayOrderEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'orderId': backendOrderId,
            'amount': amount,
            'description': description,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('We could not start secure payment right now.');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map) {
      throw StateError('Secure payment setup returned an unexpected response.');
    }

    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;

    return _RazorpayOrderPayload(
      orderId: data['orderId']?.toString() ?? '',
      currency: data['currency']?.toString() ?? 'INR',
      amountInPaise: (data['amount'] as num?)?.toInt() ?? amountInPaise,
    );
  }

  Future<PaymentCardVaultResult> tokenizeCard({
    required String userId,
    required String name,
    required String email,
    required String contact,
  }) async {
    if (!AppConfig.hasRazorpayCardVaulting) {
      throw StateError('Saved cards are not configured yet. Add the card vaulting endpoints to continue.');
    }

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Please sign in again before saving a card.');
    }

    final setupResponse = await http
        .post(
          Uri.parse(AppConfig.razorpayCardSetupEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'userId': userId,
            'name': name.trim(),
            'email': email.trim(),
            'contact': contact.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (setupResponse.statusCode < 200 || setupResponse.statusCode >= 300) {
      throw StateError('We could not start secure card setup right now.');
    }

    final setupPayload = jsonDecode(setupResponse.body);
    if (setupPayload is! Map) {
      throw StateError('Secure card setup returned an unexpected response.');
    }

    final orderId = setupPayload['orderId']?.toString() ?? '';
    final amount = (setupPayload['amount'] as num?)?.toDouble() ?? 1;
    final currency = setupPayload['currency']?.toString() ?? 'INR';
    if (orderId.isEmpty) {
      throw StateError('Secure card setup is missing an order id.');
    }

    _cardVaultCompleter = Completer<PaymentCardVaultResult>();
    _razorpay = Razorpay();
    _razorpay!
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleCardVaultSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleCardVaultError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleCardVaultExternalWallet);

    final options = {
      'key': AppConfig.razorpayKey,
      'order_id': orderId,
      'amount': (amount * 100).toInt(),
      'currency': currency,
      'name': 'ABZORA',
      'description': 'Secure card verification',
      'prefill': {
        'contact': contact,
        'email': email,
        'name': name,
      },
      'method': {
        'card': true,
        'upi': false,
        'netbanking': false,
        'wallet': false,
        'emi': false,
      },
      'notes': {
        'flow': 'card_vault',
        'userId': userId,
      },
    };

    try {
      _razorpay!.open(options);
      final checkoutResult = await _cardVaultCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          if (!(_cardVaultCompleter?.isCompleted ?? true)) {
            _cardVaultCompleter?.complete(
              const PaymentCardVaultResult(success: false, message: 'Card setup timed out.'),
            );
          }
          return const PaymentCardVaultResult(success: false, message: 'Card setup timed out.');
        },
      );

      if (!checkoutResult.success) {
        return checkoutResult;
      }

      final finalizeResponse = await http
          .post(
            Uri.parse(AppConfig.razorpayCardFinalizeEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'userId': userId,
              'paymentId': checkoutResult.paymentId,
              'razorpayOrderId': checkoutResult.orderId,
              'signature': checkoutResult.signature,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (finalizeResponse.statusCode < 200 || finalizeResponse.statusCode >= 300) {
        throw StateError('Card verification finished, but the secure token could not be saved.');
      }

      final finalizePayload = jsonDecode(finalizeResponse.body);
      if (finalizePayload is! Map) {
        throw StateError('Saved card response is invalid.');
      }

      return PaymentCardVaultResult(
        success: true,
        paymentId: checkoutResult.paymentId,
        orderId: checkoutResult.orderId,
        signature: checkoutResult.signature,
        card: SavedCardSummary(
          id: finalizePayload['cardId']?.toString() ?? '',
          userId: userId,
          last4: finalizePayload['last4']?.toString() ?? '0000',
          cardType: finalizePayload['cardType']?.toString() ?? 'Card',
          gatewayCustomerId: finalizePayload['gatewayCustomerId']?.toString(),
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      dispose();
    }
  }

  void _handleCardVaultSuccess(PaymentSuccessResponse response) {
    if (!(_cardVaultCompleter?.isCompleted ?? true)) {
      _cardVaultCompleter?.complete(
        PaymentCardVaultResult(
          success: true,
          paymentId: response.paymentId,
          orderId: response.orderId,
          signature: response.signature,
        ),
      );
    }
  }

  void _handleCardVaultError(PaymentFailureResponse response) {
    if (!(_cardVaultCompleter?.isCompleted ?? true)) {
      _cardVaultCompleter?.complete(
        PaymentCardVaultResult(
          success: false,
          message: response.message ?? 'Payment failed, try again.',
        ),
      );
    }
  }

  void _handleCardVaultExternalWallet(ExternalWalletResponse response) {
    if (!(_cardVaultCompleter?.isCompleted ?? true)) {
      _cardVaultCompleter?.complete(
        PaymentCardVaultResult(
          success: false,
          message: '${response.walletName ?? 'Wallet'} is not supported for saved cards.',
        ),
      );
    }
  }
}

class PaymentCardVaultResult {
  const PaymentCardVaultResult({
    required this.success,
    this.card,
    this.message,
    this.paymentId,
    this.orderId,
    this.signature,
  });

  final bool success;
  final SavedCardSummary? card;
  final String? message;
  final String? paymentId;
  final String? orderId;
  final String? signature;
}

class _RazorpayOrderPayload {
  const _RazorpayOrderPayload({
    required this.orderId,
    required this.currency,
    required this.amountInPaise,
  });

  final String orderId;
  final String currency;
  final int amountInPaise;
}
