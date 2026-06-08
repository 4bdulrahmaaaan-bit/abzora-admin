import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/trial_session.dart';
import '../services/trial_home_api.dart';
import '../utils/app_error_text.dart';

class TrialHomeProvider with ChangeNotifier {
  TrialHomeProvider({TrialHomeApi? api}) : _api = api ?? TrialHomeApi();

  final TrialHomeApi _api;

  TrialSession? _currentTrial;
  bool _loading = false;
  String? _error;
  String? _lastActionKey;

  TrialSession? get currentTrial => _currentTrial;
  bool get loading => _loading;
  String? get error => _error;
  bool get isConfigured => _api.isConfigured;

  Future<TrialSession?> fetchMyTrial() async {
    return _runGuarded(() async {
      _currentTrial = await _api.getMyTrial();
      return _currentTrial;
    });
  }

  Future<TrialSession> fetchTrialById(String trialId) async {
    return _runGuarded(() async {
      final session = await _api.getTrialById(trialId);
      _currentTrial = session;
      return session;
    });
  }

  Future<TrialSession> requestTrial({
    required List<Product> items,
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    int trialDurationMinutes = 30,
  }) async {
    final actionKey = 'request:${items.map((item) => item.id).join(',')}';
    return _runGuarded(
      () async {
        final session = await _api.requestTrial(
          items: items
              .map((product) => TrialSessionItem.fromProduct(
                    product,
                    recommendedSize: product.sizes.isNotEmpty ? product.sizes.first : 'M',
                    fitConfidence: 99,
                  ).toMap())
              .toList(),
          addressLabel: addressLabel,
          deliverySlot: deliverySlot,
          deliveryWindowLabel: deliveryWindowLabel,
          trialDurationMinutes: trialDurationMinutes,
        );
        _currentTrial = session;
        return session;
      },
      actionKey: actionKey,
    );
  }

  Future<TrialSession> bookTrial({
    required List<Product> items,
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    int trialDurationMinutes = 30,
    String? bookingPaymentId,
    String? bookingOrderId,
  }) async {
    final actionKey = 'book:${items.map((item) => item.id).join(',')}';
    return _runGuarded(
      () async {
        final session = await _api.bookTrial(
          items: items
              .map((product) => TrialSessionItem.fromProduct(
                    product,
                    recommendedSize: product.sizes.isNotEmpty ? product.sizes.first : 'M',
                    fitConfidence: 99,
                  ).toMap())
              .toList(),
          addressLabel: addressLabel,
          deliverySlot: deliverySlot,
          deliveryWindowLabel: deliveryWindowLabel,
          trialDurationMinutes: trialDurationMinutes,
          bookingPaymentId: bookingPaymentId,
          bookingOrderId: bookingOrderId,
        );
        _currentTrial = session;
        return session;
      },
      actionKey: actionKey,
    );
  }

  Future<TrialSession> modifyTrial({
    required String trialId,
    List<Product>? items,
    String? addressLabel,
    String? deliverySlot,
    String recommendedSize = 'M',
    double fitConfidence = 92,
  }) async {
    return _runGuarded(() async {
      final session = await _api.modifyTrial(
        trialId,
        items: items
            ?.map((product) => TrialSessionItem.fromProduct(
                  product,
                  recommendedSize: recommendedSize,
                  fitConfidence: fitConfidence,
                ).toMap())
            .toList(),
        addressLabel: addressLabel,
        deliverySlot: deliverySlot,
      );
      _currentTrial = session;
      return session;
    }, actionKey: 'modify:$trialId');
  }

  Future<TrialSession> cancelTrial(String trialId, {String note = ''}) async {
    return _runGuarded(() async {
      final session = await _api.cancelTrial(trialId, note: note);
      _currentTrial = session;
      return session;
    }, actionKey: 'cancel:$trialId');
  }

  Future<TrialSession> submitFeedback({
    required String trialId,
    required String fit,
    required String note,
    required String tailoringRecommendation,
    String? status,
  }) async {
    return _runGuarded(() async {
      final session = await _api.modifyTrial(trialId, note: '$note\nFit: $fit\nRecommendation: $tailoringRecommendation');
      _currentTrial = session;
      return session;
    }, actionKey: 'feedback:$trialId');
  }

  Future<TrialSession> awaitFinalPayment({
    required String trialId,
    required List<String> keptItems,
    required List<String> returnedItems,
  }) async {
    return _runGuarded(() async {
      final session = await _api.awaitFinalPayment(
        trialId,
        keptItems: keptItems,
        returnedItems: returnedItems,
      );
      _currentTrial = session;
      return session;
    }, actionKey: 'await_payment:$trialId');
  }

  Future<TrialSession> completeTrial({
    required String trialId,
    required List<String> keptItems,
    required List<String> returnedItems,
    String paymentMethod = 'online',
    String? finalPaymentId,
    String? finalOrderId,
    double? finalAmount,
  }) async {
    return _runGuarded(() async {
      final session = await _api.convertToOrder(
        trialId,
        keptItems: keptItems,
        returnedItems: returnedItems,
        paymentMethod: paymentMethod,
        finalPaymentId: finalPaymentId,
        finalOrderId: finalOrderId,
        finalAmount: finalAmount,
      );
      _currentTrial = session;
      return session;
    }, actionKey: 'complete:$trialId:order');
  }

  Future<T> _runGuarded<T>(
    Future<T> Function() action, {
    String? actionKey,
  }) async {
    if (_loading && actionKey != null && actionKey == _lastActionKey) {
      throw StateError('Please wait while we finish your last action.');
    }

    _loading = true;
    _error = null;
    _lastActionKey = actionKey;
    notifyListeners();

    try {
      return await action();
    } catch (error) {
      _error = AppErrorText.from(error);
      rethrow;
    } finally {
      _loading = false;
      _lastActionKey = null;
      notifyListeners();
    }
  }
}
