import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/app_config.dart';
import '../../services/database_service.dart';
import '../../services/payment_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'address_screen.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final DatabaseService _database = DatabaseService();
  final TextEditingController _couponController = TextEditingController();
  static const String _lastPaymentMethodKey = 'checkout_last_payment_method';

  bool _processing = false;
  bool _loadingAddresses = true;
  bool _loadingCredits = false;
  bool _loadingCouponOffer = false;
  bool _loadingPricing = false;
  bool _couponExpanded = false;
  String? _paymentMethod = 'COD';
  UserAddress? _selectedAddress;
  List<UserAddress> _savedAddresses = const [];
  SmartCreditDecision? _creditDecision;
  GrowthOffer? _bestCouponOffer;
  MasterPricingDecision? _pricingDecision;
  bool _useReferralCredits = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _buildIdempotencyKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _restorePaymentMethod(context.read<CartProvider>());
      _loadAddresses();
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  String _buildIdempotencyKey() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'ck-$millis-$random';
  }

  Future<void> _loadAddresses() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) {
        setState(() => _loadingAddresses = false);
      }
      return;
    }

    setState(() => _loadingAddresses = true);
    try {
      final addresses = await _database.getUserAddresses(user.id);
      if (!mounted) {
        return;
      }

      final fallbackAddress = _fallbackAddressFromUser(user);
      final allAddresses = [
        ...addresses,
        if (fallbackAddress != null && !addresses.any((item) => _sameAddress(item, fallbackAddress))) fallbackAddress,
      ];

      setState(() {
        _savedAddresses = allAddresses;
        _selectedAddress = _resolveSelectedAddress(allAddresses);
        _loadingAddresses = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses = const [];
        _selectedAddress ??= _fallbackAddressFromUser(user);
        _loadingAddresses = false;
      });
    }
  }

  Future<void> _restorePaymentMethod([CartProvider? cart]) async {
    final activeCart = cart ?? context.read<CartProvider>();
    final fallbackMethod = _isCodAvailable(activeCart) ? 'COD' : 'UPI';
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_lastPaymentMethodKey);
    if (!mounted) {
      return;
    }

    final normalized = (saved ?? '').trim().toUpperCase();
    final resolvedMethod = normalized.isEmpty
        ? fallbackMethod
        : (normalized == 'COD' && !_isCodAvailable(activeCart) ? fallbackMethod : normalized);

    if (_paymentMethod == resolvedMethod) {
      return;
    }
    setState(() => _paymentMethod = resolvedMethod);
  }

  Future<void> _rememberPaymentMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPaymentMethodKey, method);
  }

  Future<void> _loadSmartCredits() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingCredits = false;
          _creditDecision = null;
          _useReferralCredits = false;
        });
      }
      return;
    }
    setState(() => _loadingCredits = true);
    try {
      final decision = await _database.getSmartCreditDecision(
        user: user,
        cartValue: _preCreditTotal(context.read<CartProvider>()),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _creditDecision = decision;
        _useReferralCredits = decision.autoApplied && decision.appliedCredits > 0;
        _loadingCredits = false;
      });
      unawaited(_loadMasterPricing());
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _creditDecision = null;
        _useReferralCredits = false;
        _loadingCredits = false;
      });
      unawaited(_loadMasterPricing());
    }
  }

  Future<void> _loadBestCouponOffer() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bestCouponOffer = null;
        _loadingCouponOffer = false;
      });
      return;
    }
    setState(() => _loadingCouponOffer = true);
    try {
      final offer = await _database.getPersonalizedCouponForCheckout(
        user: user,
        cartValue: _preCreditTotal(context.read<CartProvider>()),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bestCouponOffer = offer;
        _loadingCouponOffer = false;
      });
      unawaited(_loadMasterPricing());
      if (offer != null && offer.autoApply && context.read<CartProvider>().appliedCoupon == null) {
        _couponController.text = offer.code;
        await _applyCoupon(context.read<CartProvider>());
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bestCouponOffer = null;
        _loadingCouponOffer = false;
      });
      unawaited(_loadMasterPricing());
    }
  }

  List<OrderItem> _currentOrderItems(CartProvider cart) {
    return cart.items
        .map(
          (item) => OrderItem(
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity,
            price: item.product.price,
            size: item.size,
            imageUrl: item.product.images.isNotEmpty ? item.product.images.first : '',
            isCustomTailoring: item.product.isCustomTailoring,
            neededBy: item.product.neededBy,
            tailoringDeliveryMode: item.product.tailoringDeliveryMode,
            measurementProfileLabel: item.product.measurementProfileLabel,
          ),
        )
        .toList();
  }

  Future<void> _loadMasterPricing() async {
    final user = context.read<AuthProvider>().user;
    final cart = context.read<CartProvider>();
    if (user == null || cart.items.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pricingDecision = null;
        _loadingPricing = false;
      });
      return;
    }

    setState(() => _loadingPricing = true);
    try {
      final decision = await _database.getMasterPricingDecision(
        user: user,
        items: _currentOrderItems(cart),
        extraCharges: cart.customTailoringCharges,
        couponCode: cart.appliedCoupon,
        useReferralCredits: _useReferralCredits || (_creditDecision?.autoApplied ?? false),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pricingDecision = decision;
        _loadingPricing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pricingDecision = null;
        _loadingPricing = false;
      });
    }
  }

  UserAddress? _resolveSelectedAddress(List<UserAddress> addresses) {
    if (addresses.isEmpty) {
      return _selectedAddress;
    }
    if (_selectedAddress == null) {
      return addresses.first;
    }
    return addresses.cast<UserAddress?>().firstWhere(
          (item) => item?.id == _selectedAddress?.id,
          orElse: () => addresses.first,
        );
  }

  bool _sameAddress(UserAddress left, UserAddress right) {
    return left.name == right.name &&
        left.phone == right.phone &&
        left.addressLine == right.addressLine &&
        left.city == right.city &&
        left.pincode == right.pincode;
  }

  UserAddress? _fallbackAddressFromUser(AppUser user) {
    if ((user.address ?? '').trim().isEmpty) {
      return null;
    }

    return UserAddress(
      id: 'profile-address',
      userId: user.id,
      name: user.name.trim().isEmpty ? 'ABZORA Member' : user.name.trim(),
      phone: user.phone ?? '',
      addressLine: user.address!.trim(),
      city: user.city ?? '',
      state: '',
      pincode: _extractPincode(user.address ?? ''),
      locality: user.area ?? '',
      latitude: user.latitude,
      longitude: user.longitude,
      type: 'home',
      createdAt: user.locationUpdatedAt ?? user.createdAt ?? DateTime.now().toIso8601String(),
    );
  }

  String _extractPincode(String address) {
    final match = RegExp(r'\\b\\d{6}\\b').firstMatch(address);
    return match?.group(0) ?? '';
  }

  Future<void> _showAddressSheet() async {
    final selected = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.abzioBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Choose delivery address', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Select the address for this order or add a new one.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                if (_savedAddresses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.abzioBorder),
                    ),
                    child: Text(
                      'No saved addresses yet. Add one to continue.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ..._savedAddresses.map(
                    (address) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AddressOptionTile(
                        address: address,
                        selected: _selectedAddress?.id == address.id,
                        onTap: () => Navigator.of(sheetContext).pop(address),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop('add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add new address'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (selected is UserAddress) {
      setState(() => _selectedAddress = selected);
      return;
    }

    if (selected != 'add') {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddressScreen()),
    );
    if (!mounted) {
      return;
    }
    await _loadAddresses();
  }

  Future<void> _applyCoupon(CartProvider cart) async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final rawCode = _couponController.text.trim();
    var ok = false;
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      final personalized = await _database.validateCouponForUser(
        user: user,
        code: rawCode,
        cartValue: _preCreditTotal(cart),
      );
      if (personalized != null) {
        ok = cart.applyCoupon(
          personalized.code,
          discountPercentage: personalized.discountPercent / 100,
          fixedDiscountAmount: personalized.discountAmount,
        );
      }
    }
    ok = ok || cart.applyCoupon(rawCode);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(ok ? 'Coupon applied successfully.' : 'That coupon code is not valid.'),
      ),
    );
    unawaited(_loadSmartCredits());
    unawaited(_loadBestCouponOffer());
    unawaited(_loadMasterPricing());
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  bool _usesOnlinePayment(String? method) {
    return method == 'UPI' || method == 'CARDS';
  }

  bool _isCodAvailable(CartProvider cart) {
    return !cart.hasCustomTailoring;
  }

  void _changePaymentMethod(String value, CartProvider cart) {
    if (value == 'COD' && !_isCodAvailable(cart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Cash on Delivery is not available for custom-fit orders.'),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _paymentMethod = value);
  }

  Future<void> _placeOrder(CartProvider cart) async {
    debugPrint('ABZORA checkout: place order tapped');
    if (_processing) {
      debugPrint('ABZORA checkout: ignored because processing is true');
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your bag is empty. Add a style to continue.')),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a delivery address to place your order.')),
      );
      return;
    }

    final selectedPaymentMethod = _paymentMethod ?? '';
    if (selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment method to continue.')),
      );
      return;
    }
    if (selectedPaymentMethod == 'WALLET') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ABZORA Credit will be available soon. Please choose another method.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final currentUser = auth.user;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to place your order.')),
      );
      return;
    }
    if (_usesOnlinePayment(selectedPaymentMethod) && !AppConfig.hasRazorpayKey) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Online payment is not available right now. Please choose Cash on Delivery.'),
        ),
      );
      return;
    }
    if (_usesOnlinePayment(selectedPaymentMethod) &&
        _database.usesBackendCommerce &&
        (!AppConfig.hasRazorpayOrderEndpoint || !AppConfig.hasRazorpayVerificationEndpoint)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Secure online payment is not ready right now. Please choose another payment method.'),
        ),
      );
      return;
    }

    setState(() => _processing = true);
    debugPrint('ABZORA checkout: processing started with method=$selectedPaymentMethod');
    unawaited(_rememberPaymentMethod(selectedPaymentMethod));

    try {
      final payableAmount = _totalAmount(cart);
      debugPrint('ABZORA checkout: payable amount=$payableAmount items=${cart.items.length}');
      final orderItems = cart.items
          .map(
            (item) => OrderItem(
              productId: item.product.id,
              productName: item.product.name,
              quantity: item.quantity,
              price: item.product.price,
              size: item.size,
              imageUrl: item.product.images.isNotEmpty ? item.product.images.first : '',
              isCustomTailoring: item.product.isCustomTailoring,
              neededBy: item.product.neededBy,
              tailoringDeliveryMode: item.product.tailoringDeliveryMode,
              measurementProfileLabel: item.product.measurementProfileLabel,
            ),
          )
          .toList();
      String? paymentReference;
      var paymentVerified = false;
      final paymentMethodForOrder =
          _usesOnlinePayment(selectedPaymentMethod) ? 'RAZORPAY' : selectedPaymentMethod;
      late final OrderModel placedOrder;

      if (_database.usesBackendCommerce && _usesOnlinePayment(selectedPaymentMethod)) {
        debugPrint('ABZORA checkout: backend commerce online payment branch');
        final pendingOrder = await _database.placeOrdersForCart(
          actor: currentUser,
          items: orderItems,
          paymentMethod: paymentMethodForOrder,
          shippingLabel: _selectedAddress!.name,
          shippingAddress: _composeFullAddress(_selectedAddress!),
          extraCharges: cart.customTailoringCharges,
          discountAmount: cart.discountAmount,
          walletCreditUsed: _appliedCredits,
          paymentReference: 'pending',
          idempotencyKey: _idempotencyKey,
          isPaymentVerified: false,
        );
        if (!mounted) {
          debugPrint('ABZORA checkout: unmounted after pending order creation');
          return;
        }
        debugPrint('ABZORA checkout: pending order created id=${pendingOrder.id}');
        final paymentResult = await PaymentService().processCheckout(
          context: context,
          userId: currentUser.id,
          backendOrderId: pendingOrder.id,
          name: currentUser.name.trim().isEmpty ? 'ABZORA Member' : currentUser.name.trim(),
          amount: payableAmount,
          email: currentUser.email.isEmpty ? 'guest@abzora.app' : currentUser.email,
          contact: currentUser.phone ?? _selectedAddress!.phone,
          description: cart.hasCustomTailoring ? 'Custom clothing checkout' : 'Marketplace checkout',
        );
        if (!paymentResult.success) {
          debugPrint('ABZORA checkout: payment failed or cancelled');
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Payment was not completed.')),
            );
          }
          return;
        }
        paymentReference = paymentResult.paymentId ?? paymentResult.externalWallet ?? paymentResult.orderId;
        paymentVerified = paymentResult.isVerified;
        debugPrint('ABZORA checkout: payment success verified=$paymentVerified ref=$paymentReference');
        final refreshedOrders = await _database.getUserOrdersOnce(currentUser.id);
        placedOrder = refreshedOrders.cast<OrderModel?>().firstWhere(
              (item) => item?.id == pendingOrder.id,
              orElse: () => pendingOrder,
            )!;
      } else {
        debugPrint('ABZORA checkout: direct order branch online=${_usesOnlinePayment(selectedPaymentMethod)}');
        if (_usesOnlinePayment(selectedPaymentMethod)) {
          final paymentResult = await PaymentService().processCheckout(
            context: context,
            userId: currentUser.id,
            name: currentUser.name.trim().isEmpty ? 'ABZORA Member' : currentUser.name.trim(),
            amount: payableAmount,
            email: currentUser.email.isEmpty ? 'guest@abzora.app' : currentUser.email,
            contact: currentUser.phone ?? _selectedAddress!.phone,
            description: cart.hasCustomTailoring ? 'Custom clothing checkout' : 'Marketplace checkout',
          );
          if (!paymentResult.success) {
            debugPrint('ABZORA checkout: direct payment failed or cancelled');
            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Payment was not completed.')),
              );
            }
            return;
          }
          paymentReference = paymentResult.paymentId ?? paymentResult.externalWallet ?? paymentResult.orderId;
          paymentVerified = paymentResult.isVerified;
          debugPrint('ABZORA checkout: direct payment success verified=$paymentVerified ref=$paymentReference');
        }

        placedOrder = await _database.placeOrdersForCart(
          actor: currentUser,
          items: orderItems,
          paymentMethod: paymentMethodForOrder,
          shippingLabel: _selectedAddress!.name,
          shippingAddress: _composeFullAddress(_selectedAddress!),
          extraCharges: cart.customTailoringCharges,
          discountAmount: cart.discountAmount,
          walletCreditUsed: _appliedCredits,
          paymentReference: paymentReference,
          idempotencyKey: _idempotencyKey,
          isPaymentVerified: paymentVerified,
        );
      }

      debugPrint('ABZORA checkout: placed order id=${placedOrder.id}');

      if (!mounted) {
        debugPrint('ABZORA checkout: unmounted before success navigation');
        return;
      }

      debugPrint('ABZORA checkout: navigating to success screen');
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: placedOrder.invoiceNumber.isEmpty ? placedOrder.id : placedOrder.invoiceNumber,
            estimatedDelivery: _estimateDeliveryDate(placedOrder),
            paymentMethod: selectedPaymentMethod,
          ),
        ),
      );
    } catch (error) {
      debugPrint('ABZORA checkout: exception=$error');
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message.isEmpty ? 'Order could not be placed right now.' : message),
        ),
      );
    } finally {
      if (mounted) {
        debugPrint('ABZORA checkout: processing finished');
        setState(() => _processing = false);
      }
    }
  }

  DateTime _estimateDeliveryDate(OrderModel order) {
    final days = order.orderType == 'custom_tailoring' ? 6 : 3;
    return DateTime.now().add(Duration(days: days));
  }

  String _composeFullAddress(UserAddress address) {
    return [
      if (address.houseDetails.trim().isNotEmpty) address.houseDetails.trim(),
      if (address.addressLine.trim().isNotEmpty) address.addressLine.trim(),
      if (address.landmark.trim().isNotEmpty) address.landmark.trim(),
      if (address.locality.trim().isNotEmpty) address.locality.trim(),
      if (address.city.trim().isNotEmpty) address.city.trim(),
      if (address.state.trim().isNotEmpty) address.state.trim(),
      if (address.pincode.trim().isNotEmpty) address.pincode.trim(),
    ].join(', ');
  }

  double _discountedSubtotal(CartProvider cart) {
    final decision = _pricingDecision;
    if (decision != null) {
      return decision.discountedSubtotal;
    }
    return (cart.subtotal - cart.discountAmount).clamp(0.0, double.infinity).toDouble();
  }

  double _taxAmount(CartProvider cart) {
    final decision = _pricingDecision;
    if (decision != null) {
      return decision.taxAmount;
    }
    return _discountedSubtotal(cart) * 0.05;
  }

  double _preCreditTotal(CartProvider cart) {
    return _discountedSubtotal(cart) + _taxAmount(cart) + cart.customTailoringCharges;
  }

  double get _appliedCredits {
    final masterDecision = _pricingDecision;
    if (masterDecision != null) {
      return masterDecision.creditsApplied;
    }
    final creditDecision = _creditDecision;
    if (creditDecision == null || !_useReferralCredits) {
      return 0;
    }
    return creditDecision.appliedCredits;
  }

  double _totalAmount(CartProvider cart) {
    final decision = _pricingDecision;
    if (decision != null) {
      return decision.finalPrice;
    }
    return (_preCreditTotal(cart) - _appliedCredits).clamp(0.0, double.infinity).toDouble();
  }

  String _deliveryEta(CartProvider cart) {
    final eta = cart.hasCustomTailoring
        ? DateTime.now().add(const Duration(days: 6))
        : DateTime.now().add(const Duration(days: 1));
    return 'Deliver by ${DateFormat('EEE, d MMM').format(eta)}';
  }

  Future<void> _applyBestOffer(CartProvider cart) async {
    if (cart.appliedCoupon != null) {
      return;
    }
    _couponController.text = _bestCouponOffer?.code ?? (cart.hasCustomTailoring ? 'ELITE20' : 'ABZORA10');
    await _applyCoupon(cart);
  }

  String _ctaLabel(CartProvider cart, NumberFormat currency) {
    final amount = currency.format(_totalAmount(cart));
    if (_paymentMethod == 'UPI') {
      return 'Pay $amount via UPI';
    }
    if (_paymentMethod == 'CARDS') {
      return 'Pay $amount by Card';
    }
    if (_paymentMethod == 'COD') {
      return 'Confirm Order (COD)';
    }
    if (_usesOnlinePayment(_paymentMethod)) {
      return 'Continue to Pay';
    }
    return 'Place Order • $amount';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final total = _totalAmount(cart);

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        appBar: AppBar(
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                'Secure ABZORA finish',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.abzioSecondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: _goBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompactHeroRow(deliveryLabel: _deliveryEta(cart)),
              const SizedBox(height: 12),
              _SectionShell(
                title: 'Delivery Address',
                actionLabel: _selectedAddress == null ? 'Add' : 'Change',
                onAction: _showAddressSheet,
                child: _loadingAddresses
                    ? const _LoadingCard()
                    : _CompactAddressCard(
                        address: _selectedAddress,
                        onChange: _showAddressSheet,
                      ),
              ),
              const SizedBox(height: 12),
              _SectionShell(
                title: 'Order Summary',
                subtitle: '${cart.items.length} item${cart.items.length == 1 ? '' : 's'} in your bag',
                child: _CompactOrderSummary(
                  items: cart.items,
                  formatter: currency,
                ),
              ),
              const SizedBox(height: 12),
              _SectionShell(
                title: 'Offers & Coupons',
                subtitle: cart.appliedCoupon == null ? 'Best offer ready for this order' : 'Savings applied to your bag',
                child: Column(
                  children: [
                    _CouponCard(
                      controller: _couponController,
                      appliedCoupon: cart.appliedCoupon,
                      expanded: _couponExpanded,
                      onToggle: () => setState(() => _couponExpanded = !_couponExpanded),
                      onApply: () => _applyCoupon(cart),
                      onRemove: () {
                        _couponController.clear();
                        cart.removeCoupon();
                        unawaited(_loadSmartCredits());
                        unawaited(_loadBestCouponOffer());
                      },
                    ),
                    const SizedBox(height: 10),
                    _BestOfferBanner(
                      loading: _loadingCouponOffer,
                      title: _bestCouponOffer?.title ?? 'Special offer for you',
                      subtitle: _bestCouponOffer?.subtitle,
                      code: _bestCouponOffer?.code ?? (cart.hasCustomTailoring ? 'ELITE20' : 'ABZORA10'),
                      discountLabel: _bestCouponOffer == null
                          ? (cart.hasCustomTailoring ? '20% off tailoring' : '10% off this checkout')
                          : _bestCouponOffer!.discountAmount > 0
                              ? '₹${_bestCouponOffer!.discountAmount.toStringAsFixed(0)} off for this order'
                              : '${_bestCouponOffer!.discountPercent.toStringAsFixed(0)}% off for this order',
                      onApply: cart.appliedCoupon != null ? null : () => _applyBestOffer(cart),
                    ),
                    const SizedBox(height: 10),
                    _ReferralCreditCard(
                      loading: _loadingCredits,
                      decision: _creditDecision,
                      enabled: _useReferralCredits,
                      onChanged: (value) {
                        setState(() => _useReferralCredits = value);
                        unawaited(_loadMasterPricing());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
                _SectionShell(
                  title: 'Payment Method',
                  subtitle: 'Fast, secure checkout tailored for you.',
                  child: _PremiumPaymentSelector(
                    selectedMethod: _paymentMethod,
                    codAvailable: _isCodAvailable(cart),
                    amountLabel: currency.format(total),
                    onChanged: (value) => _changePaymentMethod(value, cart),
                  ),
                ),
              const SizedBox(height: 12),
              _SectionShell(
                title: 'Price Breakdown',
                child: _loadingPricing
                    ? const _LoadingCard()
                    : _PriceBreakdownCard(
                        originalSubtotal: _pricingDecision?.originalPrice ?? cart.subtotal,
                        dynamicSubtotal: _pricingDecision?.dynamicPrice ?? cart.subtotal,
                        discount: _pricingDecision?.couponAmount ?? cart.discountAmount,
                        tax: _taxAmount(cart),
                        customCharge: cart.customTailoringCharges,
                        walletCredit: _appliedCredits,
                        total: total,
                        formatter: currency,
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFEFDFC),
                  Colors.white,
                ],
              ),
              border: Border(top: BorderSide(color: context.abzioBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackVertically = constraints.maxWidth < 340;
                    final totalBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F1DF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Secure total',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF8D6D20),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Secure total',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currency.format(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    );

                    final actionButton = DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE1C768), AbzioTheme.accentColor],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                        child: ElevatedButton(
                          onPressed: _processing ? null : () => _placeOrder(cart),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _processing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Processing...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _ctaLabel(cart, currency),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );

                    if (stackVertically) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          totalBlock,
                          const SizedBox(height: 12),
                          actionButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Flexible(
                          flex: 4,
                          child: totalBlock,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 6,
                          child: actionButton,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  _isCodAvailable(cart)
                      ? '100% secure payments • COD available'
                      : '100% secure payments • Fast delivery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E3C5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8963F).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.abzioSecondaryText,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CompactHeroRow extends StatelessWidget {
  const _CompactHeroRow({required this.deliveryLabel});

  final String deliveryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E3C5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, size: 18, color: AbzioTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              deliveryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AbzioTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFB8B2A6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_outline_rounded, size: 16, color: AbzioTheme.accentColor),
          const SizedBox(width: 6),
          Text(
            '100% secure',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompactAddressCard extends StatelessWidget {
  const _CompactAddressCard({
    required this.address,
    required this.onChange,
  });

  final UserAddress? address;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: onChange,
          child: const Text('Add address'),
        ),
      );
    }

    final locationLine = [
      if (address!.houseDetails.trim().isNotEmpty) address!.houseDetails.trim(),
      if (address!.addressLine.trim().isNotEmpty) address!.addressLine.trim(),
      if (address!.locality.trim().isNotEmpty) address!.locality.trim(),
      if (address!.city.trim().isNotEmpty) address!.city.trim(),
      if (address!.pincode.trim().isNotEmpty) address!.pincode.trim(),
    ].join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${address!.name} • ${address!.phone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AbzioTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                locationLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.abzioSecondaryText,
                      height: 1.25,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _CompactOrderSummary extends StatelessWidget {
  const _CompactOrderSummary({
    required this.items,
    required this.formatter,
  });

  final List<CartItem> items;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: item == items.last ? 0 : 10),
              child: _CompactOrderRow(
                item: item,
                formatter: formatter,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CompactOrderRow extends StatelessWidget {
  const _CompactOrderRow({
    required this.item,
    required this.formatter,
  });

  final CartItem item;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 70,
            height: 70,
            child: AbzioNetworkImage(
              imageUrl: product.images.isNotEmpty ? product.images.first : '',
              fallbackLabel: product.name,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AbzioTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _SummaryChip(label: 'Qty ${item.quantity}'),
                  _SummaryChip(label: 'Size ${item.size}'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatter.format(product.effectivePrice * item.quantity),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _BestOfferBanner extends StatelessWidget {
  const _BestOfferBanner({
    required this.loading,
    required this.title,
    required this.code,
    required this.discountLabel,
    this.subtitle,
    this.onApply,
  });

  final bool loading;
  final String title;
  final String code;
  final String discountLabel;
  final String? subtitle;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF8E9),
            AbzioTheme.accentColor.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? 'Finding your best offer' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  loading
                      ? 'Checking your activity, cart value, and recent behavior.'
                      : subtitle == null || subtitle!.trim().isEmpty
                          ? '$code suggested for you. $discountLabel'
                          : '$subtitle $discountLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: loading ? null : onApply,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(72, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(loading ? 'Loading' : onApply == null ? 'Applied' : 'Apply'),
          ),
        ],
      ),
    );
  }
}

class _PremiumPaymentSelector extends StatelessWidget {
  const _PremiumPaymentSelector({
    required this.selectedMethod,
    required this.codAvailable,
    required this.amountLabel,
    required this.onChanged,
  });

  final String? selectedMethod;
  final bool codAvailable;
  final String amountLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeMethod = selectedMethod == null || selectedMethod!.isEmpty ? 'UPI' : selectedMethod!;
    return InkWell(
      onTap: () => _showPaymentSheet(context, activeMethod),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _methodAccent(activeMethod).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_methodIcon(activeMethod), color: _methodAccent(activeMethod)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _methodTitle(activeMethod),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EBCB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          activeMethod == 'UPI' ? 'Fastest' : activeMethod == 'COD' ? 'Flexible' : 'Secure',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF7B5A12),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _methodSummary(activeMethod),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _methodFeedback(activeMethod),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9C7A22),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.unfold_more_rounded, color: context.abzioSecondaryText),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentSheet(BuildContext context, String initialMethod) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PaymentMethodSheet(
        initialMethod: initialMethod,
        codAvailable: codAvailable,
        amountLabel: amountLabel,
      ),
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'CARDS':
        return Icons.credit_card_rounded;
      case 'COD':
        return Icons.payments_outlined;
      default:
        return Icons.qr_code_2_rounded;
    }
  }

  Color _methodAccent(String method) {
    switch (method) {
      case 'CARDS':
        return const Color(0xFFB28A2C);
      case 'COD':
        return const Color(0xFF8E6D38);
      default:
        return AbzioTheme.accentColor;
    }
  }

  String _methodTitle(String method) {
    switch (method) {
      case 'CARDS':
        return 'Credit / Debit Card';
      case 'COD':
        return 'Cash on Delivery';
      default:
        return 'UPI';
    }
  }

  String _methodSummary(String method) {
    switch (method) {
      case 'CARDS':
        return 'Visa, Mastercard, RuPay with EMI support.';
      case 'COD':
        return codAvailable ? 'Pay when your order arrives.' : 'Unavailable for custom-fit orders.';
      default:
        return 'Pay instantly via Google Pay, PhonePe, or Paytm.';
    }
  }

  String _methodFeedback(String method) {
    switch (method) {
      case 'CARDS':
        return 'Processing may take 10–15 seconds';
      case 'COD':
        return 'Order confirmation only • no online payment';
      default:
        return 'Estimated payment time: < 5 seconds';
    }
  }
}

class _PaymentMethodSheet extends StatefulWidget {
  const _PaymentMethodSheet({
    required this.initialMethod,
    required this.codAvailable,
    required this.amountLabel,
  });

  final String initialMethod;
  final bool codAvailable;
  final String amountLabel;

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  late String _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F4EA).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6CCBC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Choose Payment Method',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Fast, secure checkout tailored for you',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.grey600),
              ),
              const SizedBox(height: 18),
              _recommendedCard(context),
              const SizedBox(height: 14),
              _PaymentOptionCard(
                icon: Icons.qr_code_2_rounded,
                title: 'UPI',
                subtitle: 'Pay instantly via Google Pay, PhonePe, Paytm',
                hint: 'Last used: PhonePe',
                extra: '98% success rate with UPI',
                badge: 'Fastest',
                selected: _selectedMethod == 'UPI',
                enabled: true,
                onTap: () => _select('UPI'),
              ),
              const SizedBox(height: 10),
              _PaymentOptionCard(
                icon: Icons.credit_card_rounded,
                title: 'Credit / Debit Card',
                subtitle: 'Visa, Mastercard, RuPay',
                hint: 'Supports EMI',
                extra: 'Processing may take 10–15 seconds',
                selected: _selectedMethod == 'CARDS',
                enabled: true,
                onTap: () => _select('CARDS'),
              ),
              const SizedBox(height: 10),
              _PaymentOptionCard(
                icon: Icons.payments_outlined,
                title: 'Cash on Delivery',
                subtitle: widget.codAvailable ? 'Pay when order arrives' : 'Unavailable for custom-fit orders',
                hint: widget.codAvailable ? 'Extra ₹40 handling fee may apply' : 'Choose UPI or cards instead',
                extra: 'Confirms the order without online payment',
                selected: _selectedMethod == 'COD',
                enabled: widget.codAvailable,
                onTap: () => _select('COD'),
              ),
              const SizedBox(height: 14),
              _securityCard(context),
              const SizedBox(height: 12),
              _liveFeedbackCard(context),
              if (_selectedMethod == 'COD' && widget.codAvailable) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7EA),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Are you sure? UPI is faster and safer for most orders.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8B6620),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0C36C), Color(0xFFC89D34)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC89D34).withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selectedMethod),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    child: Text(_ctaLabelForSheet()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(String method) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMethod = method);
  }

  Widget _recommendedCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF201A12), Color(0xFF47341A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recommended for you ⚡',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAE7AA).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '1-tap payment',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFF4DEAC),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'UPI',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Faster checkout + ₹50 cashback available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _select('UPI'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF4DEAC),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Pay instantly'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your payment is protected 🔒',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _trustPoint(context, 'Bank-level encryption'),
          _trustPoint(context, 'No card details stored without consent'),
          _trustPoint(context, 'Secure gateway powered by Razorpay'),
        ],
      ),
    );
  }

  Widget _trustPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF9C7A22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AbzioTheme.grey600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveFeedbackCard(BuildContext context) {
    final isCod = _selectedMethod == 'COD';
    final isUpi = _selectedMethod == 'UPI';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUpi ? '98% success rate with UPI' : isCod ? 'Manual confirmation flow' : 'Card processing insight',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9C7A22),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            isUpi
                ? 'Estimated payment time: < 5 seconds • Save ₹120 using this method'
                : isCod
                    ? 'Processing may take longer at delivery. UPI usually confirms faster.'
                    : 'Processing may take 10–15 seconds depending on bank verification.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AbzioTheme.grey600),
          ),
        ],
      ),
    );
  }

  String _ctaLabelForSheet() {
    switch (_selectedMethod) {
      case 'CARDS':
        return 'Pay ${widget.amountLabel} by Card';
      case 'COD':
        return 'Confirm Order (COD)';
      default:
        return 'Pay ${widget.amountLabel} via UPI';
    }
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.extra,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String hint;
  final String extra;
  final bool selected;
  final bool enabled;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AbzioTheme.accentColor : const Color(0xFFEAE0CF),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: selected ? const Color(0xFFFAF0D5) : const Color(0xFFF7F1E6),
                ),
                child: Icon(icon, color: selected ? AbzioTheme.accentColor : const Color(0xFF8F7A56)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AbzioTheme.textPrimary,
                                ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EBCB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF7B5A12),
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: title == 'Cash on Delivery' ? const Color(0xFF8B6620) : const Color(0xFF8C7446),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      extra,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AbzioTheme.grey600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.controller,
    required this.appliedCoupon,
    required this.expanded,
    required this.onToggle,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String? appliedCoupon;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined, size: 18, color: AbzioTheme.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Apply Coupon',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_right_rounded,
                  color: context.abzioSecondaryText,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Enter coupon code',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onApply,
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (appliedCoupon != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 16, color: AbzioTheme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$appliedCoupon applied',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AbzioTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReferralCreditCard extends StatelessWidget {
  const _ReferralCreditCard({
    required this.loading,
    required this.decision,
    required this.enabled,
    required this.onChanged,
  });

  final bool loading;
  final SmartCreditDecision? decision;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.abzioBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Checking your ABZORA Credits...')),
          ],
        ),
      );
    }
    final current = decision;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final highlight = current.appliedCredits > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFFBF0) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AbzioTheme.accentColor.withValues(alpha: 0.24)
              : context.abzioBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.autoApplied && current.appliedCredits > 0
                      ? 'Rs ${current.appliedCredits.toStringAsFixed(0)} credits applied automatically'
                      : current.message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Available credits: Rs ${current.availableCredits.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          if (current.eligible && current.appliedCredits > 0 && !current.autoApplied)
            Switch.adaptive(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AbzioTheme.accentColor,
              activeTrackColor: AbzioTheme.accentColor.withValues(alpha: 0.35),
            ),
        ],
      ),
    );
  }
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({
    required this.originalSubtotal,
    required this.dynamicSubtotal,
    required this.discount,
    required this.tax,
    required this.customCharge,
    required this.walletCredit,
    required this.total,
    required this.formatter,
  });

  final double originalSubtotal;
  final double dynamicSubtotal;
  final double discount;
  final double tax;
  final double customCharge;
  final double walletCredit;
  final double total;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        children: [
          _PriceLine(label: 'Base Price', value: formatter.format(originalSubtotal)),
          if ((dynamicSubtotal - originalSubtotal).abs() > 0.01) ...[
            const SizedBox(height: 6),
            _PriceLine(
              label: 'Dynamic Price',
              value: formatter.format(dynamicSubtotal),
              valueColor: dynamicSubtotal < originalSubtotal ? const Color(0xFF218B5B) : null,
            ),
          ],
          if ((dynamicSubtotal - originalSubtotal).abs() <= 0.01) ...[
            const SizedBox(height: 6),
            _PriceLine(label: 'Subtotal', value: formatter.format(dynamicSubtotal)),
          ],
          const SizedBox(height: 6),
          const _PriceLine(label: 'Delivery fee', value: 'Free'),
          if (customCharge > 0) ...[
            const SizedBox(height: 6),
            _PriceLine(label: 'Custom fit service', value: formatter.format(customCharge)),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 6),
            _PriceLine(
              label: 'Discount',
              value: '- ${formatter.format(discount)}',
              valueColor: const Color(0xFF218B5B),
            ),
          ],
          if (walletCredit > 0) ...[
            const SizedBox(height: 6),
            _PriceLine(
              label: 'ABZORA Credits',
              value: '- ${formatter.format(walletCredit)}',
              valueColor: const Color(0xFF218B5B),
            ),
          ],
          const SizedBox(height: 6),
          _PriceLine(label: 'Taxes', value: formatter.format(tax)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _PriceLine(
            label: 'Total amount',
            value: formatter.format(total),
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: const Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Loading your saved addresses...')),
        ],
      ),
    );
  }
}

class _AddressOptionTile extends StatelessWidget {
  const _AddressOptionTile({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final UserAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : context.abzioBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (address.locality.trim().isNotEmpty) address.locality.trim(),
                      if (address.city.trim().isNotEmpty) address.city.trim(),
                      if (address.pincode.trim().isNotEmpty) address.pincode.trim(),
                    ].join(', '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

