import 'dart:async';

import 'dart:math';

import 'dart:ui';



import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../../models/models.dart';

import '../../models/delivery_serviceability.dart';

import '../../providers/auth_provider.dart';

import '../../providers/cart_provider.dart';

import '../../services/app_config.dart';

import '../../services/database_service.dart';

import '../../services/delivery_service.dart';

import '../../services/payment_service.dart';

import '../../theme.dart';

import '../../utils/app_error_text.dart';

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
  final DeliveryService _deliveryService = DeliveryService();

  final TextEditingController _couponController = TextEditingController();

  static const String _lastPaymentMethodKey = 'checkout_last_payment_method';



  bool _processing = false;

  ProductServiceability? _checkoutServiceabilitySnapshot;
  String _checkoutServiceabilityCacheKey = '';

  bool _loadingAddresses = true;

  bool _loadingCredits = false;

  bool _loadingBestCoupon = false;
  bool _loadingCouponCatalog = false;

  bool _loadingPricing = false;

  String? _paymentMethod = 'COD';

  UserAddress? _selectedAddress;

  List<UserAddress> _savedAddresses = const [];

  SmartCreditDecision? _creditDecision;

  Coupon? _bestCoupon;
  List<Coupon> _couponCatalog = const [];

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
      unawaited(_loadCouponCatalog());
      unawaited(_loadBestCoupon());
      unawaited(_loadSmartCredits());

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



  void _logCheckout(String message) {

    if (kDebugMode) {

      debugPrint(message);

    }

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

        if (fallbackAddress != null &&

            !addresses.any((item) => _sameAddress(item, fallbackAddress)))

          fallbackAddress,

      ];



      setState(() {

        _savedAddresses = allAddresses;

        _selectedAddress = _resolveSelectedAddress(allAddresses);

        _loadingAddresses = false;

      });
      unawaited(_refreshCheckoutServiceability(context.read<CartProvider>(), force: true));

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _savedAddresses = const [];

        _selectedAddress ??= _fallbackAddressFromUser(user);

        _loadingAddresses = false;

      });
      unawaited(_refreshCheckoutServiceability(context.read<CartProvider>(), force: true));

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

        : (normalized == 'COD' && !_isCodAvailable(activeCart)

              ? fallbackMethod

              : normalized);



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

        _useReferralCredits =

            decision.autoApplied && decision.appliedCredits > 0;

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



  Future<void> _loadCouponCatalog() async {
    final user = context.read<AuthProvider>().user;
    final cart = context.read<CartProvider>();

    if (user == null || cart.items.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _couponCatalog = const [];
        _loadingCouponCatalog = false;
      });
      return;
    }

    setState(() => _loadingCouponCatalog = true);

    try {
      final coupons = await _database.getCouponsForCheckout(
        user: user,
        cartValue: _preCreditTotal(cart),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _couponCatalog = coupons.take(4).toList();
        _loadingCouponCatalog = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _couponCatalog = const [];
        _loadingCouponCatalog = false;
      });
    }
  }

  Future<void> _loadBestCoupon() async {
    final user = context.read<AuthProvider>().user;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bestCoupon = null;
        _loadingBestCoupon = false;
      });
      return;
    }

    setState(() => _loadingBestCoupon = true);

    try {
      final coupons = await _database.getCouponsForCheckout(
        user: user,
        cartValue: _preCreditTotal(context.read<CartProvider>()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _bestCoupon = coupons.isEmpty ? null : coupons.first;
        _loadingBestCoupon = false;
      });

      unawaited(_loadMasterPricing());
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bestCoupon = null;
        _loadingBestCoupon = false;
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

            imageUrl: item.product.images.isNotEmpty

                ? item.product.images.first

                : '',

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

        useReferralCredits:

            _useReferralCredits || (_creditDecision?.autoApplied ?? false),

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

      name: user.name.trim().isEmpty ? 'Abianzo Member' : user.name.trim(),

      phone: user.phone ?? '',

      addressLine: user.address!.trim(),

      city: user.city ?? '',

      state: '',

      pincode: _extractPincode(user.address ?? ''),

      locality: user.area ?? '',

      latitude: user.latitude,

      longitude: user.longitude,

      type: 'home',

      createdAt:

          user.locationUpdatedAt ??

          user.createdAt ??

          DateTime.now().toIso8601String(),

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

                Text(

                  'Choose delivery address',

                  style: Theme.of(context).textTheme.titleLarge,

                ),

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
      unawaited(_refreshCheckoutServiceability(context.read<CartProvider>(), force: true));

      return;

    }



    if (selected != 'add') {

      return;

    }



    await Navigator.of(

      context,

    ).push(MaterialPageRoute(builder: (_) => const AddressScreen()));

    if (!mounted) {

      return;

    }

    await _loadAddresses();

  }




  String _checkoutServiceabilitySignature(CartProvider cart, UserAddress address) {
    final itemsSignature = cart.items
        .map((item) {
          final variantId = item.product.colorVariants.isNotEmpty
              ? item.product.colorVariants.first.variantId
              : '';
          return '${item.product.id}:$variantId:${item.size}:${item.quantity}';
        })
        .join('|');
    return [
      address.latitude?.toStringAsFixed(5) ?? 'na',
      address.longitude?.toStringAsFixed(5) ?? 'na',
      address.pincode.trim(),
      itemsSignature,
    ].join('|');
  }

  Future<void> _refreshCheckoutServiceability(
    CartProvider cart, {
    bool force = false,
  }) async {
    final address = _selectedAddress;
    if (address == null || cart.items.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkoutServiceabilitySnapshot = null;
        _checkoutServiceabilityCacheKey = '';
      });
      return;
    }

    final cacheKey = _checkoutServiceabilitySignature(cart, address);
    if (!force &&
        cacheKey == _checkoutServiceabilityCacheKey &&
        _checkoutServiceabilitySnapshot != null) {
      return;
    }

    try {
      ProductServiceability? tryAtHome;
      ProductServiceability? localDelivery;
      ProductServiceability? courierDelivery;
      for (final item in cart.items) {
        final serviceability = await _deliveryService.getServiceability(
          product: item.product,
          address: address,
        );
        if (!serviceability.isDeliverable) {
          if (!mounted) {
            return;
          }
          setState(() {
            _checkoutServiceabilitySnapshot = serviceability;
            _checkoutServiceabilityCacheKey = cacheKey;
          });
          return;
        }
        if (serviceability.supportsTryAtHome) {
          tryAtHome ??= serviceability;
        }
        if (serviceability.supportsInstantDelivery) {
          localDelivery ??= serviceability;
        }
        if (serviceability.supportsCourierDelivery) {
          courierDelivery ??= serviceability;
        }
      }

      final resolved = tryAtHome ?? localDelivery ?? courierDelivery;
      if (!mounted) {
        return;
      }
      setState(() {
        _checkoutServiceabilitySnapshot = resolved;
        _checkoutServiceabilityCacheKey = cacheKey;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkoutServiceabilitySnapshot = null;
        _checkoutServiceabilityCacheKey = cacheKey;
      });
    }
  }

  Future<String?> _checkoutDeliveryIssue(CartProvider cart) async {
    final address = _selectedAddress;
    if (address == null) {
      return 'Add your delivery address to unlock faster checkout.';
    }
    final supportedModes = <DeliveryMode>{};
    for (final item in cart.items) {
      final serviceability = await _deliveryService.getServiceability(
        product: item.product,
        address: address,
      );
      if (!serviceability.isDeliverable) {
        final reason = serviceability.reason.trim();
        return reason.isNotEmpty
            ? reason
            : 'Unable to determine delivery availability.';
      }
      supportedModes.add(serviceability.deliveryMode);
    }
    if (supportedModes.length > 1) {
      return 'This item uses a different delivery method.\n\nPlease complete your current cart before adding products with another delivery method.';
    }
    return null;
  }

  Future<void> _applyCoupon(
    CartProvider cart, {
    String? code,
  }) async {

    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    final rawCode = (code ?? _couponController.text).trim();

    var ok = false;

    final user = context.read<AuthProvider>().user;

    if (user != null) {

      final coupon = await _database.validateCouponForUser(
        user: user,
        code: rawCode,
        cartValue: _preCreditTotal(cart),
      );

      if (coupon != null) {
        final discountPercentage =
            coupon.discountType == 'percentage'
                ? coupon.discountValue / 100
                : null;
        final fixedDiscountAmount = coupon.discountType == 'fixed'
            ? coupon.discountValue
            : null;
        ok = cart.applyCoupon(
          coupon.couponCode,
          discountPercentage: discountPercentage,
          fixedDiscountAmount: fixedDiscountAmount,
          maximumDiscount: coupon.maximumDiscount,
        );
      }

    }

    if (!mounted) {
      return;
    }

    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('That coupon code is not valid.'),
        ),
      );
    }

    unawaited(_loadCouponCatalog());
    unawaited(_loadSmartCredits());
    unawaited(_loadBestCoupon());

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

          content: Text(

            'Cash on Delivery is not available for custom-fit orders.',

          ),

        ),

      );

      return;

    }

    HapticFeedback.selectionClick();

    setState(() => _paymentMethod = value);

  }



  Future<void> _placeOrder(CartProvider cart) async {

    _logCheckout('Abianzo checkout: place order tapped');

    if (_processing) {

      _logCheckout('Abianzo checkout: ignored because processing is true');

      return;

    }



    if (cart.items.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Your bag is empty. Add a style to continue.'),

        ),

      );

      return;

    }



    if (_selectedAddress == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Choose a delivery address to place your order.'),

        ),

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

        const SnackBar(

          content: Text(

            'Abianzo Credit will be available soon. Please choose another method.',

          ),

        ),

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

    if (auth.requiresProfileSetup) {

      messenger.showSnackBar(

        const SnackBar(

          content: Text(

            'Please complete your profile before placing an order.',

          ),

        ),

      );

      navigator.pushNamed('/profile-completion');

      return;

    }

    if (_usesOnlinePayment(selectedPaymentMethod) &&

        !AppConfig.hasRazorpayKey) {

      messenger.showSnackBar(

        const SnackBar(

          content: Text(

            'Online payment is not available right now. Please choose Cash on Delivery.',

          ),

        ),

      );

      return;

    }

    if (_usesOnlinePayment(selectedPaymentMethod) &&

        _database.usesBackendCommerce &&

        (!AppConfig.hasRazorpayOrderEndpoint ||

            !AppConfig.hasRazorpayVerificationEndpoint)) {

      messenger.showSnackBar(

        const SnackBar(

          content: Text(

            'Secure online payment is not ready right now. Please choose another payment method.',

          ),

        ),

      );

      return;

    }



    await _refreshCheckoutServiceability(cart);
    final checkoutIssue = await _checkoutDeliveryIssue(cart);
    if (checkoutIssue != null) {
      if (checkoutIssue.toLowerCase().contains('different delivery method')) {
        await _showMixedDeliveryDialog(checkoutIssue);
      } else {
        await _showServiceabilityUnavailableDialog();
      }
      return;
    }
    setState(() => _processing = true);

    _logCheckout(

      'Abianzo checkout: processing started with method=$selectedPaymentMethod',

    );

    unawaited(_rememberPaymentMethod(selectedPaymentMethod));



    try {

      final checkoutServiceability = _checkoutServiceabilitySnapshot;

      if (checkoutServiceability == null) {
        await _showServiceabilityUnavailableDialog();
        return;
      }

      final payableAmount = _totalAmount(cart, checkoutServiceability);
      final deliveryType = checkoutServiceability.deliveryMode.name.toUpperCase();
      final deliveryProvider = checkoutServiceability.deliveryProvider.trim();
      final shippingCharge = checkoutServiceability.shippingCharge;
      final estimatedDeliveryDate = checkoutServiceability.estimatedDeliveryDate.trim();
      final estimatedInstantDeliveryTime =
          checkoutServiceability.estimatedInstantDeliveryTime.trim();

      _logCheckout(

        'Abianzo checkout: payable amount=$payableAmount items=${cart.items.length}',

      );

      final orderItems = cart.items

          .map(

            (item) => OrderItem(

              productId: item.product.id,

              productName: item.product.name,

              quantity: item.quantity,

              price: item.product.price,

              size: item.size,

              imageUrl: item.product.images.isNotEmpty

                  ? item.product.images.first

                  : '',

              isCustomTailoring: item.product.isCustomTailoring,

              neededBy: item.product.neededBy,

              tailoringDeliveryMode: item.product.tailoringDeliveryMode,

              measurementProfileLabel: item.product.measurementProfileLabel,

            ),

          )

          .toList();

      String? paymentReference;

      var paymentVerified = false;

      final paymentMethodForOrder = _usesOnlinePayment(selectedPaymentMethod)

          ? 'RAZORPAY'

          : selectedPaymentMethod;

      late final OrderModel placedOrder;



      if (_database.usesBackendCommerce &&

          _usesOnlinePayment(selectedPaymentMethod)) {

        _logCheckout(

          'Abianzo checkout: backend commerce online payment branch',

        );

        final pendingOrder = await _database.placeOrdersForCart(

          actor: currentUser,

          items: orderItems,

          paymentMethod: paymentMethodForOrder,

          shippingLabel: _selectedAddress!.name,

          shippingAddress: _composeFullAddress(_selectedAddress!),

          extraCharges: cart.customTailoringCharges,

          deliveryType: deliveryType,

          deliveryProvider: deliveryProvider,

          shippingCharge: shippingCharge,

          estimatedDeliveryDate: estimatedDeliveryDate,

          estimatedInstantDeliveryTime: estimatedInstantDeliveryTime,

          discountAmount: cart.discountAmount,

          walletCreditUsed: _appliedCredits,

          paymentReference: 'pending',

          idempotencyKey: _idempotencyKey,

          isPaymentVerified: false,

        );

        if (!mounted) {

          _logCheckout(

            'Abianzo checkout: unmounted after pending order creation',

          );

          return;

        }

        _logCheckout('Abianzo checkout: pending order created');

        final paymentResult = await PaymentService().processCheckout(userId: currentUser.id,

          backendOrderId: pendingOrder.id,

          name: currentUser.name.trim().isEmpty

              ? 'Abianzo Member'

              : currentUser.name.trim(),

          amount: payableAmount,

          email: currentUser.email.isEmpty

              ? 'guest@abianzo.app'

              : currentUser.email,

          contact: currentUser.phone ?? _selectedAddress!.phone,

          description: cart.hasCustomTailoring

              ? 'Custom clothing checkout'

              : 'Marketplace checkout',

        );

        if (!paymentResult.success) {

          _logCheckout('Abianzo checkout: payment failed or cancelled');

          if (mounted) {

            messenger.showSnackBar(

              const SnackBar(content: Text('Payment was not completed.')),

            );

          }

          return;

        }

        paymentReference =

            paymentResult.paymentId ??

            paymentResult.externalWallet ??

            paymentResult.orderId;

        paymentVerified = paymentResult.isVerified;

        _logCheckout(

          'Abianzo checkout: payment success verified=$paymentVerified',

        );

        final refreshedOrders = await _database.getUserOrdersOnce(

          currentUser.id,

        );

        placedOrder = refreshedOrders.cast<OrderModel?>().firstWhere(

          (item) => item?.id == pendingOrder.id,

          orElse: () => pendingOrder,

        )!;

      } else {

        _logCheckout(

          'Abianzo checkout: direct order branch online=${_usesOnlinePayment(selectedPaymentMethod)}',

        );

        if (_usesOnlinePayment(selectedPaymentMethod)) {

          final paymentResult = await PaymentService().processCheckout(userId: currentUser.id,

            name: currentUser.name.trim().isEmpty

                ? 'Abianzo Member'

                : currentUser.name.trim(),

            amount: payableAmount,

            email: currentUser.email.isEmpty

                ? 'guest@abianzo.app'

                : currentUser.email,

            contact: currentUser.phone ?? _selectedAddress!.phone,

            description: cart.hasCustomTailoring

                ? 'Custom clothing checkout'

                : 'Marketplace checkout',

          );

          if (!paymentResult.success) {

            _logCheckout(

              'Abianzo checkout: direct payment failed or cancelled',

            );

            if (mounted) {

              messenger.showSnackBar(

                const SnackBar(content: Text('Payment was not completed.')),

              );

            }

            return;

          }

          paymentReference =

              paymentResult.paymentId ??

              paymentResult.externalWallet ??

              paymentResult.orderId;

          paymentVerified = paymentResult.isVerified;

          _logCheckout(

            'Abianzo checkout: direct payment success verified=$paymentVerified',

          );

        }



        placedOrder = await _database.placeOrdersForCart(

          actor: currentUser,

          items: orderItems,

          paymentMethod: paymentMethodForOrder,

          shippingLabel: _selectedAddress!.name,

          shippingAddress: _composeFullAddress(_selectedAddress!),

          extraCharges: cart.customTailoringCharges,

          deliveryType: deliveryType,

          deliveryProvider: deliveryProvider,

          shippingCharge: shippingCharge,

          estimatedDeliveryDate: estimatedDeliveryDate,

          estimatedInstantDeliveryTime: estimatedInstantDeliveryTime,

          discountAmount: cart.discountAmount,

          walletCreditUsed: _appliedCredits,

          paymentReference: paymentReference,

          idempotencyKey: _idempotencyKey,

          isPaymentVerified: paymentVerified,

        );

      }



      _logCheckout('Abianzo checkout: placed order');



      if (!mounted) {

        _logCheckout('Abianzo checkout: unmounted before success navigation');

        return;

      }



      _logCheckout('Abianzo checkout: navigating to success screen');

      navigator.pushReplacement(

        MaterialPageRoute(

          builder: (_) => OrderSuccessScreen(

            orderId: placedOrder.invoiceNumber.isEmpty

                ? placedOrder.id

                : placedOrder.invoiceNumber,

            estimatedDelivery: _estimateDeliveryDate(placedOrder),

            paymentMethod: selectedPaymentMethod,

          ),

        ),

      );

    } catch (error) {

      _logCheckout('Abianzo checkout: exception=$error');

      if (!mounted) {

        return;

      }

      final message = AppErrorText.from(error);

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          behavior: SnackBarBehavior.floating,

          content: Text(

            message.isEmpty ? 'Order could not be placed right now.' : message,

          ),

        ),

      );

    } finally {

      if (mounted) {

        _logCheckout('Abianzo checkout: processing finished');

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

    return (cart.subtotal - cart.discountAmount)

        .clamp(0.0, double.infinity)

        .toDouble();

  }



  double _taxAmount(CartProvider cart) {

    final decision = _pricingDecision;

    if (decision != null) {

      return decision.taxAmount;

    }

    return _discountedSubtotal(cart) * 0.05;

  }



  double _preCreditTotal(CartProvider cart) {

    return _discountedSubtotal(cart) +

        _taxAmount(cart) +

        cart.customTailoringCharges;

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



  double _totalAmount(

    CartProvider cart, [

    ProductServiceability? serviceability,

  ]) {

    final decision = _pricingDecision;

    final resolvedServiceability = serviceability ?? _checkoutServiceabilitySnapshot;

    final shippingAmount =

        resolvedServiceability?.isDeliverable == true
            ? (resolvedServiceability?.shippingCharge ?? 0)
            : 0;

    if (decision != null) {

      return (decision.finalPrice + shippingAmount)

          .clamp(0.0, double.infinity)

          .toDouble();

    }

    return ((_preCreditTotal(cart) - _appliedCredits) + shippingAmount)

        .clamp(0.0, double.infinity)

        .toDouble();

  }



  String _deliveryEta(CartProvider cart) {

    final eta = cart.hasCustomTailoring

        ? DateTime.now().add(const Duration(days: 6))

        : DateTime.now().add(const Duration(days: 1));

    return 'Deliver by ${DateFormat('EEE, d MMM').format(eta)}';

  }



  Future<void> _showServiceabilityUnavailableDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delivery availability'),
        content: const Text('Unable to determine delivery availability.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Change Address'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_refreshCheckoutServiceability(context.read<CartProvider>(), force: true));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMixedDeliveryDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Different delivery method'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _ctaLabel(CartProvider cart, NumberFormat currency) {

    final amount = currency.format(_totalAmount(cart, _checkoutServiceabilitySnapshot));

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

    return 'Place Order ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ $amount';

  }



  @override

  Widget build(BuildContext context) {

    final cart = context.watch<CartProvider>();

    final currency = NumberFormat.currency(

      locale: 'en_IN',

      symbol: '?',

      decimalDigits: 0,

    );

    final total = _totalAmount(cart, _checkoutServiceabilitySnapshot);



    return AbzioThemeScope.light(

      child: Scaffold(

        backgroundColor: const Color(0xFFFAF9F6),

        appBar: AppBar(

          scrolledUnderElevation: 0,

          backgroundColor: const Color(0xFFFAF9F6),

          foregroundColor: const Color(0xFF1F1F1C),

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

                'Secure Abianzo finish',

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

                subtitle:

                    '${cart.items.length} item${cart.items.length == 1 ? '' : 's'} in your bag',

                child: _CompactOrderSummary(

                  items: cart.items,

                  formatter: currency,

                ),

              ),

              const SizedBox(height: 12),

              _SectionShell(

                title: 'Offers & Coupons',

                subtitle: cart.appliedCoupon == null

                    ? 'Best coupon ready for this order'

                    : 'Savings applied to your bag',

                child: _PremiumCouponExperience(
                  loadingCatalog: _loadingCouponCatalog,
                  loadingBestCoupon: _loadingBestCoupon,
                  appliedCoupon: cart.appliedCoupon,
                  savingsAmount:
                      _pricingDecision?.couponAmount ?? cart.discountAmount,
                  availableCoupons: _couponCatalog,
                  bestCoupon: _bestCoupon,
                  customCodeController: _couponController,
                  onApplyCode: (code) => _applyCoupon(cart, code: code),
                  onApplyBestCoupon: cart.appliedCoupon != null
                      ? null
                      : (code) async {
                          _couponController.text = code;
                          await _applyCoupon(cart, code: code);
                        },
                  onRemoveCoupon: () {
                    _couponController.clear();
                    cart.removeCoupon();
                    unawaited(_loadCouponCatalog());
                    unawaited(_loadSmartCredits());
                    unawaited(_loadBestCoupon());
                    unawaited(_loadMasterPricing());
                  },
                  onRefreshCoupons: () {
                    unawaited(_loadCouponCatalog());
                    unawaited(_loadBestCoupon());
                  },
                ),

              ),

              const SizedBox(height: 12),

              if ((_creditDecision?.availableCredits ?? 0) > 0 ||
                  (_creditDecision?.appliedCredits ?? 0) > 0 ||
                  _loadingCredits)
                _SectionShell(
                  title: 'Referral Credits',
                  subtitle: 'Apply your available Abianzo Credits.',
                  child: _ReferralCreditCard(
                    loading: _loadingCredits,
                    decision: _creditDecision,
                    enabled: _useReferralCredits,
                    onChanged: (value) {
                      setState(() => _useReferralCredits = value);
                      unawaited(_loadMasterPricing());
                    },
                  ),
                ),

              if ((_creditDecision?.availableCredits ?? 0) > 0 ||
                  (_creditDecision?.appliedCredits ?? 0) > 0 ||
                  _loadingCredits)
                const SizedBox(height: 12),

              _SectionShell(

                title: 'Payment Method',

                subtitle: 'A quiet, secure final review before you pay.',

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

                        originalSubtotal:

                            _pricingDecision?.originalPrice ?? cart.subtotal,

                        dynamicSubtotal:

                            _pricingDecision?.dynamicPrice ?? cart.subtotal,

                        discount:

                            _pricingDecision?.couponAmount ??

                            cart.discountAmount,

                        tax: _taxAmount(cart),

                        shippingCharge: _checkoutServiceabilitySnapshot?.shippingCharge ?? 0,

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

              color: const Color(0xFFFCFBF8),

              border: Border(top: BorderSide(color: const Color(0xFFE8E0D2))),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.045),

                  blurRadius: 18,

                  offset: const Offset(0, -8),

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

                          padding: const EdgeInsets.symmetric(

                            horizontal: 8,

                            vertical: 4,

                          ),

                          decoration: BoxDecoration(

                            color: const Color(0xFFF7F1DF),

                            borderRadius: BorderRadius.circular(999),

                          ),

                          child: Text(

                            'Secure total',

                            style: Theme.of(context).textTheme.bodySmall

                                ?.copyWith(

                                  color: const Color(0xFF8D6D20),

                                  fontWeight: FontWeight.w800,

                                  letterSpacing: 0.2,

                                ),

                          ),

                        ),

                        const SizedBox(height: 6),

                        Text(

                          'Secure total',

                          style: Theme.of(

                            context,

                          ).textTheme.bodySmall?.copyWith(fontSize: 11),

                        ),

                        const SizedBox(height: 2),

                        Text(

                          currency.format(total),

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: Theme.of(context).textTheme.titleMedium

                              ?.copyWith(fontWeight: FontWeight.w800),

                        ),

                      ],

                    );



                    final actionButton = DecoratedBox(

                      decoration: BoxDecoration(

                        gradient: const LinearGradient(

                          colors: [Color(0xFFD9C27A), Color(0xFFC6A769)],

                        ),

                        borderRadius: BorderRadius.circular(12),

                      ),

                      child: ElevatedButton(

                        onPressed: _processing ||
                                _checkoutServiceabilitySnapshot?.isDeliverable != true
                            ? null
                            : () => _placeOrder(cart),

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

                                  const Icon(

                                    Icons.lock_rounded,

                                    size: 18,

                                    color: Colors.white,

                                  ),

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

                        Flexible(flex: 4, child: totalBlock),

                        const SizedBox(width: 16),

                        Expanded(flex: 6, child: actionButton),

                      ],

                    );

                  },

                ),

                const SizedBox(height: 12),

                Text(

                  _isCodAvailable(cart)

                      ? '100% secure payments ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ COD available'

                      : '100% secure payments ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ Fast delivery',

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

                TextButton(onPressed: onAction, child: Text(actionLabel!)),

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

          const Icon(

            Icons.local_shipping_outlined,

            size: 18,

            color: AbzioTheme.accentColor,

          ),

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

          const Icon(

            Icons.lock_outline_rounded,

            size: 16,

            color: AbzioTheme.accentColor,

          ),

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

  const _CompactAddressCard({required this.address, required this.onChange});



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

                '${address!.name} ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ ${address!.phone}',

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

  const _CompactOrderSummary({required this.items, required this.formatter});



  final List<CartItem> items;

  final NumberFormat formatter;



  @override

  Widget build(BuildContext context) {

    return Column(

      children: items

          .map(

            (item) => Padding(

              padding: EdgeInsets.only(bottom: item == items.last ? 0 : 10),

              child: _CompactOrderRow(item: item, formatter: formatter),

            ),

          )

          .toList(),

    );

  }

}



class _CompactOrderRow extends StatelessWidget {

  const _CompactOrderRow({required this.item, required this.formatter});



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

                style: Theme.of(

                  context,

                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),

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

    final activeMethod = selectedMethod == null || selectedMethod!.isEmpty

        ? 'UPI'

        : selectedMethod!;

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

              height: 56,

              width: 48,

              decoration: BoxDecoration(

                color: _methodAccent(activeMethod).withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(16),

              ),

              child: Icon(

                _methodIcon(activeMethod),

                color: _methodAccent(activeMethod),

              ),

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

                          style: Theme.of(context).textTheme.titleMedium

                              ?.copyWith(fontWeight: FontWeight.w700),

                        ),

                      ),

                      const SizedBox(width: 8),

                      Container(

                        padding: const EdgeInsets.symmetric(

                          horizontal: 9,

                          vertical: 4,

                        ),

                        decoration: BoxDecoration(

                          color: const Color(0xFFF6EBCB),

                          borderRadius: BorderRadius.circular(999),

                        ),

                        child: Text(

                          activeMethod == 'UPI'

                              ? 'Fastest'

                              : activeMethod == 'COD'

                              ? 'Flexible'

                              : 'Secure',

                          style: Theme.of(context).textTheme.labelSmall

                              ?.copyWith(

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



  Future<void> _showPaymentSheet(

    BuildContext context,

    String initialMethod,

  ) async {

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

        return 'Visa \u2022 Mastercard \u2022 RuPay';

      case 'COD':

        return codAvailable

            ? 'Pay when your order arrives.'

            : 'Unavailable for custom-fit orders.';

      default:

        return 'Use UPI via Google Pay, PhonePe, Paytm, or BHIM.';

    }

  }



  String _methodFeedback(String method) {

    switch (method) {

      case 'CARDS':

        return 'Secure card payment';

      case 'COD':

        return 'No online payment required.';

      default:

        return 'Recommended payment method';

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

          padding: EdgeInsets.fromLTRB(

            20,

            14,

            20,

            MediaQuery.of(context).padding.bottom + 18,

          ),

          decoration: BoxDecoration(

            color: const Color(0xFFF9F4EA).withValues(alpha: 0.94),

            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),

            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),

          ),

          child: ConstrainedBox(

            constraints: BoxConstraints(

              maxHeight: MediaQuery.of(context).size.height * 0.88,

            ),

            child: SingleChildScrollView(

              physics: const ClampingScrollPhysics(),

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

                    style: Theme.of(context).textTheme.titleLarge?.copyWith(

                      fontWeight: FontWeight.w800,

                    ),

                  ),

                  const SizedBox(height: 4),

                  Text(
                    'UPI is highlighted as the recommended option.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AbzioTheme.grey600,
                        ),
                  ),

                  const SizedBox(height: 18),

                  _recommendedCard(context),

                  const SizedBox(height: 14),

                  _PaymentOptionCard(

                    icon: Icons.qr_code_2_rounded,

                    title: 'UPI',

                    subtitle: 'Google Pay, PhonePe, Paytm, BHIM',

                    hint: 'Recommended',

                    extra: '',

                    badge: 'Recommended',

                    selected: _selectedMethod == 'UPI',

                    enabled: true,

                    onTap: () => _select('UPI'),

                  ),

                  const SizedBox(height: 10),

                  _PaymentOptionCard(

                    icon: Icons.credit_card_rounded,

                    title: 'Credit / Debit Card',

                    subtitle: 'Visa \u2022 Mastercard \u2022 RuPay',

                    hint: 'Secure card payment',

                    extra: '',

                    selected: _selectedMethod == 'CARDS',

                    enabled: true,

                    onTap: () => _select('CARDS'),

                  ),

                  const SizedBox(height: 10),

                  _PaymentOptionCard(

                    icon: Icons.payments_outlined,

                    title: 'Cash on Delivery',

                    subtitle: widget.codAvailable

                        ? 'Pay when your order arrives.'

                        : 'Unavailable for custom-fit orders',

                    hint: widget.codAvailable

                        ? 'No online payment required.'

                        : 'Choose UPI or cards instead',

                    extra: '',

                    selected: _selectedMethod == 'COD',

                    enabled: widget.codAvailable,

                    onTap: () => _select('COD'),

                  ),

                  const SizedBox(height: 14),

                  _securityCard(context),

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

                            color: const Color(

                              0xFFC89D34,

                            ).withValues(alpha: 0.22),

                            blurRadius: 18,

                            offset: const Offset(0, 10),

                          ),

                        ],

                      ),

                      child: ElevatedButton(

                        onPressed: () =>

                            Navigator.of(context).pop(_selectedMethod),

                        style: ElevatedButton.styleFrom(

                          backgroundColor: Colors.transparent,

                          shadowColor: Colors.transparent,

                          foregroundColor: Colors.black,

                          shape: RoundedRectangleBorder(

                            borderRadius: BorderRadius.circular(999),

                          ),

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
                'Recommended',

                style: Theme.of(context).textTheme.titleMedium?.copyWith(

                  color: Colors.white,

                  fontWeight: FontWeight.w800,

                ),

              ),

              const Spacer(),

              Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 10,

                  vertical: 5,

                ),

                decoration: BoxDecoration(

                  color: const Color(0xFFFAE7AA).withValues(alpha: 0.18),

                  borderRadius: BorderRadius.circular(999),

                ),

                child: Text(

                  'Recommended',

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

            'Google Pay, PhonePe, Paytm, and BHIM support UPI payments.',

            style: Theme.of(context).textTheme.bodyMedium?.copyWith(

              color: Colors.white.withValues(alpha: 0.78),

            ),

          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PaymentAppChip(label: 'Google Pay'),
              _PaymentAppChip(label: 'PhonePe'),
              _PaymentAppChip(label: 'Paytm'),
              _PaymentAppChip(label: 'BHIM'),
            ],
          ),

          const SizedBox(height: 14),

          Align(

            alignment: Alignment.centerLeft,

            child: TextButton(

              onPressed: () => _select('UPI'),

              style: TextButton.styleFrom(

                backgroundColor: const Color(0xFFF4DEAC),

                foregroundColor: Colors.black,

                padding: const EdgeInsets.symmetric(

                  horizontal: 16,

                  vertical: 10,

                ),

              ),

              child: const Text('Continue with UPI'),

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
            'Secure checkout',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),

          const SizedBox(height: 10),

          _trustPoint(context, 'Encrypted payment flow'),

          _trustPoint(context, 'Card payments are handled by Razorpay'),

          _trustPoint(context, 'COD stays offline until delivery'),

        ],

      ),

    );

  }



  Widget _trustPoint(BuildContext context, String text) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 8),

      child: Row(

        children: [

          const Icon(

            Icons.verified_user_outlined,

            size: 16,

            color: Color(0xFF9C7A22),

          ),

          const SizedBox(width: 8),

          Expanded(

            child: Text(

              text,

              style: Theme.of(

                context,

              ).textTheme.bodySmall?.copyWith(color: AbzioTheme.grey600),

            ),

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



class _PaymentAppChip extends StatelessWidget {
  const _PaymentAppChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
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

  final String? extra;

  final bool selected;

  final bool enabled;

  final String? badge;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Opacity(

      opacity: enabled ? 1 : 0.58,

      child: InkWell(

        onTap: enabled ? onTap : null,

        borderRadius: BorderRadius.circular(22),

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 220),

          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(

            gradient: selected

                ? const LinearGradient(

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                    colors: [Color(0xFFCDAE58), Color(0xFFB88D31)],

                  )

                : null,

            color: selected ? null : Colors.white.withValues(alpha: 0.92),

            borderRadius: BorderRadius.circular(22),

            border: Border.all(

              color: selected

                  ? const Color(0xFFDDC67D)

                  : const Color(0xFFE7DECF),

              width: selected ? 1.5 : 1,

            ),

            boxShadow: [

              BoxShadow(

                color: selected

                    ? const Color(0xFFB88D31).withValues(alpha: 0.18)

                    : Colors.black.withValues(alpha: 0.035),

                blurRadius: selected ? 20 : 14,

                offset: const Offset(0, 8),

              ),

            ],

          ),

          child: Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(

                width: 46,

                height: 46,

                decoration: BoxDecoration(

                  borderRadius: BorderRadius.circular(16),

                  color: selected

                      ? Colors.white.withValues(alpha: 0.16)

                      : const Color(0xFFF6F1E4),

                ),

                child: Icon(

                  icon,

                  color: selected

                      ? Colors.white

                      : const Color(0xFF8F7A56),

                ),

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

                            style: Theme.of(context).textTheme.bodyLarge

                                ?.copyWith(

                                  fontWeight: FontWeight.w700,

                                  color: selected

                                      ? Colors.white

                                      : AbzioTheme.textPrimary,

                                ),

                          ),

                        ),

                        if (badge != null)

                          Container(

                            padding: const EdgeInsets.symmetric(

                              horizontal: 8,

                              vertical: 3,

                            ),

                            decoration: BoxDecoration(

                              color: selected

                                  ? Colors.white.withValues(alpha: 0.18)

                                  : const Color(0xFFF6EBCB),

                              borderRadius: BorderRadius.circular(999),

                            ),

                            child: Text(

                              badge!,

                              style: Theme.of(context).textTheme.labelSmall

                                  ?.copyWith(

                                    color: selected

                                        ? Colors.white

                                        : const Color(0xFF7B5A12),

                                    fontWeight: FontWeight.w700,

                                  ),

                            ),

                          ),

                      ],

                    ),

                    const SizedBox(height: 6),

                    Text(

                      subtitle,

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(

                            color: selected

                                ? Colors.white.withValues(alpha: 0.9)

                                : AbzioTheme.textSecondary,

                            height: 1.3,

                          ),

                    ),

                    const SizedBox(height: 6),

                    Text(

                      hint,

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(

                        color: selected

                            ? Colors.white.withValues(alpha: 0.84)

                            : (title == 'Cash on Delivery'

                                ? const Color(0xFF8B6620)

                                : const Color(0xFF8C7446)),

                        fontWeight: FontWeight.w600,

                      ),

                    ),

                    const SizedBox(height: 5),

                    if (extra != null && extra!.trim().isNotEmpty)
                      Text(
                        extra!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.76)
                                  : AbzioTheme.grey600,
                            ),
                      ),

                  ],

                ),

              ),

              const SizedBox(width: 8),

              Icon(

                selected

                    ? Icons.check_circle_rounded

                    : Icons.radio_button_off_rounded,

                size: 20,

                color: selected

                    ? Colors.white

                    : context.abzioSecondaryText,

              ),

            ],

          ),

        ),

      ),

    );

  }

}

class _PremiumCouponExperience extends StatelessWidget {
  const _PremiumCouponExperience({
    required this.loadingCatalog,
    required this.loadingBestCoupon,
    required this.appliedCoupon,
    required this.savingsAmount,
    required this.availableCoupons,
    required this.bestCoupon,
    required this.customCodeController,
    required this.onApplyCode,
    required this.onRemoveCoupon,
    required this.onRefreshCoupons,
    this.onApplyBestCoupon,
  });

  final bool loadingCatalog;
  final bool loadingBestCoupon;
  final String? appliedCoupon;
  final double savingsAmount;
  final List<Coupon> availableCoupons;
  final Coupon? bestCoupon;
  final TextEditingController customCodeController;
  final Future<void> Function(String code) onApplyCode;
  final VoidCallback onRemoveCoupon;
  final VoidCallback onRefreshCoupons;
  final Future<void> Function(String code)? onApplyBestCoupon;

  @override
  Widget build(BuildContext context) {
    final appliedCode = appliedCoupon?.trim().toUpperCase() ?? '';
    Coupon? appliedCouponData;
    for (final coupon in availableCoupons) {
      if (coupon.couponCode.toUpperCase() == appliedCode) {
        appliedCouponData = coupon;
        break;
      }
    }
    appliedCouponData ??= Coupon(
      id: '',
      couponCode: appliedCode,
      discountType: 'fixed',
      discountValue: savingsAmount,
      minimumOrderValue: 0,
      startDate: '',
      endDate: '',
    );
    final Coupon resolvedAppliedCoupon = appliedCouponData;

    final Coupon recommendation = bestCoupon != null &&
            bestCoupon!.couponCode.toUpperCase() != appliedCode
        ? bestCoupon!
        : availableCoupons.firstWhere(
            (coupon) => coupon.couponCode.toUpperCase() != appliedCode,
            orElse: () => Coupon(
              id: '',
              couponCode: '',
              discountType: 'fixed',
              discountValue: 0,
              minimumOrderValue: 0,
              startDate: '',
              endDate: '',
            ),
          );
    final hasRecommendation = recommendation.couponCode.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey<String>(
          [
            appliedCode,
            availableCoupons.map((coupon) => coupon.couponCode).join('|'),
            recommendation.couponCode,
          ].join('::'),
        ),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loadingCatalog || loadingBestCoupon) ...[
            const _LoadingCard(),
            const SizedBox(height: 10),
          ],
          if (appliedCode.isNotEmpty) ...[
            _PremiumAppliedCouponCard(
              coupon: resolvedAppliedCoupon,
              savedAmount: savingsAmount,
              onRemove: onRemoveCoupon,
            ),
            const SizedBox(height: 10),
          ],
          if (hasRecommendation) ...[
            _PremiumBestSavingsCard(
              coupon: recommendation,
              onSwitchCoupon: onApplyBestCoupon == null
                  ? null
                  : () => onApplyBestCoupon!(recommendation.couponCode),
            ),
            const SizedBox(height: 10),
          ],
          _SectionLabelRow(
            title: 'Available Coupons',
            actionLabel: 'Refresh',
            onAction: onRefreshCoupons,
          ),
          const SizedBox(height: 10),
          if (availableCoupons.isEmpty)
            _PremiumEmptyCouponCard(
              loading: loadingCatalog,
              onRefresh: onRefreshCoupons,
            )
          else
            Column(
              children: availableCoupons
                  .take(3)
                  .map(
                    (coupon) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PremiumCouponCard(
                        coupon: coupon,
                        isApplied: coupon.couponCode.toUpperCase() == appliedCode,
                        onApply: () => onApplyCode(coupon.couponCode),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 4),
          _CouponEntryCard(
            controller: customCodeController,
            onApply: () => onApplyCode(customCodeController.text.trim()),
          ),
        ],
      ),
    );
  }
}

class _SectionLabelRow extends StatelessWidget {
  const _SectionLabelRow({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF201F1B),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _PremiumCouponCard extends StatelessWidget {
  const _PremiumCouponCard({
    required this.coupon,
    required this.onApply,
    required this.isApplied,
  });

  final Coupon coupon;
  final VoidCallback onApply;
  final bool isApplied;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final discountLabel = coupon.discountType == 'fixed'
        ? '${money.format(coupon.discountValue)} OFF'
        : '${coupon.discountValue.toStringAsFixed(0)}% OFF';
    final minOrder = coupon.minimumOrderValue > 0
        ? 'Valid above ${money.format(coupon.minimumOrderValue)}'
        : 'No minimum order';
    final expiryDate = DateTime.tryParse(coupon.endDate);
    final expiry = coupon.endDate.trim().isEmpty || expiryDate == null
        ? ''
        : 'Expires ${DateFormat('d MMM').format(expiryDate)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isApplied ? const Color(0xFFFFFBF1) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isApplied
              ? const Color(0xFFC8A95D).withValues(alpha: 0.35)
              : const Color(0xFFE7DFD0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isApplied ? 0.05 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F1DC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.confirmation_num_outlined,
              color: Color(0xFFC8A95D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coupon.couponCode,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                      ),
                    ),
                    if (isApplied)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF1D8B4D),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  discountLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1E1A14),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  minOrder,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6A655A),
                      ),
                ),
                if (expiry.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expiry,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8A7B61),
                        ),
                  ),
                ],
                if (coupon.firstOrderOnly || coupon.eligibleUserIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    coupon.firstOrderOnly
                        ? 'First order only'
                        : 'Limited to selected accounts',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8A7B61),
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isApplied ? null : onApply,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC8A95D),
              foregroundColor: Colors.white,
              minimumSize: const Size(84, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(isApplied ? 'Applied' : 'Apply'),
          ),
        ],
      ),
    );
  }
}

class _PremiumAppliedCouponCard extends StatelessWidget {
  const _PremiumAppliedCouponCard({
    required this.coupon,
    required this.savedAmount,
    required this.onRemove,
  });

  final Coupon coupon;
  final double savedAmount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFE3CB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFDDF2E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF1D8B4D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${coupon.couponCode} Applied',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You saved ${money.format(savedAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRemove,
            child: const Text('Remove Coupon'),
          ),
        ],
      ),
    );
  }
}

class _PremiumBestSavingsCard extends StatelessWidget {
  const _PremiumBestSavingsCard({
    required this.coupon,
    required this.onSwitchCoupon,
  });

  final Coupon coupon;
  final VoidCallback? onSwitchCoupon;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final amount = coupon.discountType == 'fixed'
        ? money.format(coupon.discountValue)
        : '${coupon.discountValue.toStringAsFixed(0)}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF8EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D2A3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E6C3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFC8A95D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Savings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Apply ${coupon.couponCode} and save $amount instead.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSwitchCoupon,
            child: const Text('Switch Coupon'),
          ),
        ],
      ),
    );
  }
}

class _PremiumEmptyCouponCard extends StatelessWidget {
  const _PremiumEmptyCouponCard({
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DFD0)),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(
              Icons.local_offer_outlined,
              color: Color(0xFFC8A95D),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading ? 'Loading available coupons...' : 'No available coupons right now.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _CouponEntryCard extends StatelessWidget {
  const _CouponEntryCard({
    required this.controller,
    required this.onApply,
  });

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DFD0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Enter coupon code',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC8A95D),
              foregroundColor: Colors.white,
              minimumSize: const Size(84, 44),
            ),
            child: const Text('Apply'),
          ),
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

            Expanded(child: Text('Checking your Abianzo Credits...')),

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

        color: highlight

            ? const Color(0xFFFFFBF0)

            : Theme.of(context).cardColor,

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

            child: const Icon(

              Icons.account_balance_wallet_outlined,

              size: 18,

              color: AbzioTheme.accentColor,

            ),

          ),

          const SizedBox(width: 10),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  current.autoApplied && current.appliedCredits > 0

                      ? '\u20B9${current.appliedCredits.toStringAsFixed(0)} credits applied automatically'

                      : current.message,

                  style: Theme.of(context).textTheme.titleMedium?.copyWith(

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 2),

                Text(

                  'Available credits: \u20B9${current.availableCredits.toStringAsFixed(0)}',

                  style: Theme.of(context).textTheme.bodySmall?.copyWith(

                    color: context.abzioSecondaryText,

                    fontSize: 11,

                  ),

                ),

              ],

            ),

          ),

          if (current.eligible &&

              current.appliedCredits > 0 &&

              !current.autoApplied)

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

    required this.shippingCharge,

    required this.customCharge,

    required this.walletCredit,

    required this.total,

    required this.formatter,

  });



  final double originalSubtotal;

  final double dynamicSubtotal;

  final double discount;

  final double tax;

  final double shippingCharge;
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

          _PriceLine(

            label: 'Base Price',

            value: formatter.format(originalSubtotal),

          ),

          if ((dynamicSubtotal - originalSubtotal).abs() > 0.01) ...[

            const SizedBox(height: 6),

            _PriceLine(

              label: 'Dynamic Price',

              value: formatter.format(dynamicSubtotal),

              valueColor: dynamicSubtotal < originalSubtotal

                  ? const Color(0xFF218B5B)

                  : null,

            ),

          ],

          if ((dynamicSubtotal - originalSubtotal).abs() <= 0.01) ...[

            const SizedBox(height: 6),

            _PriceLine(

              label: 'Subtotal',

              value: formatter.format(dynamicSubtotal),

            ),

          ],

          const SizedBox(height: 6),

          _PriceLine(label: 'Delivery fee', value: shippingCharge > 0 ? formatter.format(shippingCharge) : 'Free'),

          if (customCharge > 0) ...[

            const SizedBox(height: 6),

            _PriceLine(

              label: 'Custom fit service',

              value: formatter.format(customCharge),

            ),

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

              label: 'Abianzo Credits',

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

        ? Theme.of(

            context,

          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)

        : Theme.of(

            context,

          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

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

                  Text(

                    address.name,

                    style: Theme.of(context).textTheme.titleMedium,

                  ),

                  const SizedBox(height: 4),

                  Text(

                    [

                      if (address.locality.trim().isNotEmpty)

                        address.locality.trim(),

                      if (address.city.trim().isNotEmpty) address.city.trim(),

                      if (address.pincode.trim().isNotEmpty)

                        address.pincode.trim(),

                    ].join(', '),

                    style: Theme.of(context).textTheme.bodyMedium,

                  ),

                ],

              ),

            ),

            Icon(

              selected ? Icons.check_circle_rounded : Icons.circle_outlined,

              color: selected

                  ? AbzioTheme.accentColor

                  : context.abzioSecondaryText,

            ),

          ],

        ),

      ),

    );

  }

}

