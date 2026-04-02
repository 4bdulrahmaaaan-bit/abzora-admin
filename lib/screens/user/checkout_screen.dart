import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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
import '../../widgets/address_card.dart';
import '../../widgets/order_summary_widget.dart';
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
    if (_usesOnlinePayment(_paymentMethod)) {
      return 'Pay $amount';
    }
    return 'Place Order | $amount';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
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
              const Text('Checkout'),
              Text(
                'Secure ABZORA finish',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.abzioSecondaryText,
                      fontWeight: FontWeight.w600,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFF8E7),
                      AbzioTheme.accentColor.withValues(alpha: 0.16),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkout',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A fast, secure ABZORA finish with premium delivery and flexible payment options.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TrustChip(icon: Icons.local_shipping_outlined, label: _deliveryEta(cart)),
                        const _TrustChip(icon: Icons.lock_outline_rounded, label: '100% secure payments'),
                        const _TrustChip(icon: Icons.autorenew_rounded, label: 'Easy returns'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SectionShell(
                title: 'Delivery Address',
                actionLabel: _selectedAddress == null ? 'Add' : 'Change',
                onAction: _showAddressSheet,
                child: _loadingAddresses
                    ? const _LoadingCard()
                    : Column(
                        children: [
                          AddressCard(
                            address: _selectedAddress,
                            onChange: _showAddressSheet,
                          ),
                          if (_selectedAddress != null) ...[
                            const SizedBox(height: 12),
                            _EtaBanner(label: _deliveryEta(cart)),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              _SectionShell(
                title: 'Order Summary',
                subtitle: '${cart.items.length} item${cart.items.length == 1 ? '' : 's'} in your bag',
                child: OrderSummaryWidget(items: cart.items),
              ),
              const SizedBox(height: 18),
              _SectionShell(
                title: 'Offers & Coupons',
                subtitle: cart.appliedCoupon == null ? 'Best offer ready for this order' : 'Savings applied to your bag',
                child: Column(
                  children: [
                    _CouponCard(
                      controller: _couponController,
                      appliedCoupon: cart.appliedCoupon,
                      onApply: () => _applyCoupon(cart),
                      onRemove: () {
                        _couponController.clear();
                        cart.removeCoupon();
                        unawaited(_loadSmartCredits());
                        unawaited(_loadBestCouponOffer());
                      },
                    ),
                    const SizedBox(height: 12),
                    _BestOfferBanner(
                      loading: _loadingCouponOffer,
                      title: _bestCouponOffer?.title ?? 'Special offer for you',
                      subtitle: _bestCouponOffer?.subtitle,
                      code: _bestCouponOffer?.code ?? (cart.hasCustomTailoring ? 'ELITE20' : 'ABZORA10'),
                      discountLabel: _bestCouponOffer == null
                          ? (cart.hasCustomTailoring ? '20% off tailoring' : '10% off this checkout')
                          : _bestCouponOffer!.discountAmount > 0
                              ? 'Rs ${_bestCouponOffer!.discountAmount.toStringAsFixed(0)} off for this order'
                              : '${_bestCouponOffer!.discountPercent.toStringAsFixed(0)}% off for this order',
                      onApply: cart.appliedCoupon != null ? null : () => _applyBestOffer(cart),
                    ),
                    const SizedBox(height: 12),
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
              const SizedBox(height: 18),
                _SectionShell(
                  title: 'Payment Method',
                  subtitle: 'UPI is recommended for the fastest secure checkout.',
                  child: _PremiumPaymentSelector(
                    selectedMethod: _paymentMethod,
                    codAvailable: _isCodAvailable(cart),
                    onChanged: (value) => _changePaymentMethod(value, cart),
                  ),
                ),
              const SizedBox(height: 18),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        const SizedBox(height: 8),
                        Text(
                          'Total amount',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currency.format(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                        borderRadius: BorderRadius.circular(18),
                      ),
                        child: ElevatedButton(
                          onPressed: _processing ? null : () => _placeOrder(cart),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
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
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: context.abzioSecondaryText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCodAvailable(cart)
                            ? '100% secure payments | COD available | Easy returns'
                            : '100% secure payments | Fast delivery | Easy returns',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.abzioSecondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.abzioBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.abzioSecondaryText,
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EtaBanner extends StatelessWidget {
  const _EtaBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AbzioTheme.accentColor.withValues(alpha: 0.14),
            ),
            child: const Icon(Icons.local_shipping_outlined, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label - Premium express dispatch for your ABZORA order.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AbzioTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF8E9),
            AbzioTheme.accentColor.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? 'Finding your best offer' : title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Checking your activity, cart value, and recent behavior.'
                      : subtitle == null || subtitle!.trim().isEmpty
                          ? '$code suggested for you. $discountLabel'
                          : '$subtitle $discountLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: loading ? null : onApply,
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
    required this.onChanged,
  });

  final String? selectedMethod;
  final bool codAvailable;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentMethodTile(
          icon: Icons.qr_code_2_rounded,
          title: 'UPI',
          subtitle: 'Google Pay, PhonePe, Paytm',
          badge: 'Recommended',
          selected: selectedMethod == 'UPI',
          enabled: true,
          onTap: () => onChanged('UPI'),
        ),
        const SizedBox(height: 12),
        _PaymentMethodTile(
          icon: Icons.credit_card_rounded,
          title: 'Cards',
          subtitle: 'Credit and debit cards',
          selected: selectedMethod == 'CARDS',
          enabled: true,
          onTap: () => onChanged('CARDS'),
        ),
        const SizedBox(height: 12),
        _PaymentMethodTile(
          icon: Icons.payments_outlined,
          title: 'Cash on Delivery',
          subtitle: codAvailable
              ? 'Pay when your order arrives'
              : 'Unavailable for custom-fit orders',
          selected: selectedMethod == 'COD',
          enabled: codAvailable,
          onTap: () => onChanged('COD'),
        ),
        const SizedBox(height: 12),
        _PaymentMethodTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'ABZORA Credit',
          subtitle: 'Wallet checkout will be available soon',
          selected: selectedMethod == 'WALLET',
          enabled: false,
          onTap: () => onChanged('WALLET'),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFFBF0) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AbzioTheme.accentColor : context.abzioBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? AbzioTheme.accentColor.withValues(alpha: 0.16)
                      : context.abzioMuted,
                ),
                child: Icon(icon, color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AbzioTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
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
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String? appliedCoupon;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apply Coupon', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter coupon code',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onApply,
                child: const Text('Apply'),
              ),
            ],
          ),
          if (appliedCoupon != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 18, color: AbzioTheme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$appliedCoupon applied',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFFBF0) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? AbzioTheme.accentColor.withValues(alpha: 0.24)
              : context.abzioBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  'Available credits: Rs ${current.availableCredits.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        children: [
          _PriceLine(label: 'Base Price', value: formatter.format(originalSubtotal)),
          if ((dynamicSubtotal - originalSubtotal).abs() > 0.01) ...[
            const SizedBox(height: 10),
            _PriceLine(
              label: 'Dynamic Price',
              value: formatter.format(dynamicSubtotal),
              valueColor: dynamicSubtotal < originalSubtotal ? const Color(0xFF218B5B) : null,
            ),
          ],
          if ((dynamicSubtotal - originalSubtotal).abs() <= 0.01) ...[
            const SizedBox(height: 10),
            _PriceLine(label: 'Subtotal', value: formatter.format(dynamicSubtotal)),
          ],
          const SizedBox(height: 10),
          const _PriceLine(label: 'Delivery fee', value: 'Free'),
          if (customCharge > 0) ...[
            const SizedBox(height: 10),
            _PriceLine(label: 'Custom fit service', value: formatter.format(customCharge)),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 10),
            _PriceLine(
              label: 'Discount',
              value: '- ${formatter.format(discount)}',
              valueColor: const Color(0xFF218B5B),
            ),
          ],
          if (walletCredit > 0) ...[
            const SizedBox(height: 10),
            _PriceLine(
              label: 'ABZORA Credits',
              value: '- ${formatter.format(walletCredit)}',
              valueColor: const Color(0xFF218B5B),
            ),
          ],
          const SizedBox(height: 10),
          _PriceLine(label: 'Taxes', value: formatter.format(tax)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
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
        : Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style?.copyWith(color: valueColor)),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.abzioSecondaryText),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: context.abzioSecondaryText,
              ),
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

