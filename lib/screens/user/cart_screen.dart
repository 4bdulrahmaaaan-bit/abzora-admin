// ignore_for_file: unused_element
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/location_selection_sheet.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/database_service.dart';
import '../../services/delivery_service.dart';
import '../../models/delivery_serviceability.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
import '../../utils/soft_auth_gate.dart';
import '../../widgets/state_views.dart';
import 'checkout_screen.dart';

UserAddress? _cartAddressFromUser(AppUser? user) {
  if (user == null) {
    return null;
  }
  return UserAddress(
    id: user.id,
    userId: user.id,
    name: user.name,
    phone: user.phone ?? '',
    addressLine: [
      user.address?.trim() ?? '',
      user.area?.trim() ?? '',
      user.city?.trim() ?? '',
    ].where((item) => item.isNotEmpty).join(', '),
    city: user.city?.trim() ?? '',
    state: '',
    pincode: '',
    houseDetails: '',
    landmark: user.area?.trim() ?? '',
    locality: user.area?.trim() ?? '',
    latitude: user.latitude,
    longitude: user.longitude,
    createdAt: user.createdAt ?? DateTime.now().toIso8601String(),
  );
}

String _cartServiceabilityLabel(CartProvider cart, ProductServiceability? serviceability) {
  if (serviceability == null) {
    return 'Select a delivery address to calculate delivery options.';
  }
  if (!serviceability.isDeliverable) {
    return 'Not deliverable to selected address';
  }
  if (serviceability.supportsTryAtHome) {
    return 'Try At Home - 15-minute Home Trial';
  }
  if (serviceability.supportsInstantDelivery) {
    final eta = serviceability.estimatedInstantDeliveryTime.trim();
    return eta.isEmpty ? 'Local Delivery - Today Delivery' : 'Local Delivery - $eta';
  }
  final eta = serviceability.estimatedDeliveryDate.trim();
  String displayEta = eta;
  try {
    if (eta.contains('-') && eta.length >= 10) {
      final parsed = DateTime.parse(eta);
      displayEta = DateFormat('MMM d').format(parsed);
    }
  } catch (_) {}

  final freeDeliverySuffix = cart.totalAmount >= 999 ? ' • Free Delivery' : '';

  if (displayEta.isEmpty) return 'Courier Delivery$freeDeliverySuffix';
  if (displayEta == 'Today' || displayEta == 'Tomorrow' || displayEta.startsWith('In ')) {
    return 'Arrives $displayEta$freeDeliverySuffix';
  }
  return 'Arrives by $displayEta$freeDeliverySuffix';
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with AutomaticKeepAliveClientMixin {
  final DatabaseService _database = DatabaseService();
  final DeliveryService _deliveryService = DeliveryService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  Future<List<Product>>? _completeTheLookFuture;
  Future<List<Product>>? _dealsFuture;
  String? _anchorProductId;
  final Set<String> _animatingAddIds = <String>{};
  bool _openingCheckout = false;
  UserAddress? _guestDeliveryAddress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureRecommendations(context.read<CartProvider>());
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _showAddressSheet() async {
    final result = await LocationSelectionSheet.show(context);
    if (!mounted || result == null) return;
    
    if (result is UserAddress) {
      setState(() => _guestDeliveryAddress = result);
    } else if (result is String) {
      final dummyAddress = UserAddress(
        id: '',
        userId: '',
        name: '',
        phone: '',
        addressLine: '',
        city: '',
        state: '',
        pincode: result,
        houseDetails: '',
        landmark: '',
        locality: '',
        type: 'home',
        createdAt: '',
      );
      setState(() => _guestDeliveryAddress = dummyAddress);
    }
  }

  void _ensureRecommendations(CartProvider cart) {
    if (cart.items.isEmpty) {
      _anchorProductId = null;
      _completeTheLookFuture = null;
      _dealsFuture = null;
      return;
    }

    final product = cart.items.first.product;
    if (_anchorProductId == product.id &&
        _completeTheLookFuture != null &&
        _dealsFuture != null) {
      return;
    }

    _anchorProductId = product.id;
    _completeTheLookFuture = _database.getCompleteTheLook(product);
    _dealsFuture = _database.getTrendingProducts();
  }

  Future<void> _addSuggestionToCart(Product product) async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Add to bag',
      trigger: AuthPromptTrigger.cart,
      productId: product.id,
      productPreview: AuthPromptProductPreview(
        name: product.name,
        imageUrl: product.images.isEmpty ? null : product.images.first,
      ),
      promptStyle: AuthPromptStyle.softSheet,
    );
    if (!allowed || !mounted) {
      return;
    }
    if (_animatingAddIds.contains(product.id)) {
      return;
    }
    setState(() => _animatingAddIds.add(product.id));
    final cart = context.read<CartProvider>();
    final result = cart.addToCart(
      product,
      product.sizes.isNotEmpty ? product.sizes.first : 'M',
    );
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) {
      return;
    }
    setState(() => _animatingAddIds.remove(product.id));
    final message = result == CartAddResult.storeConflict
        ? 'Your bag already has items from another store.'
        : '${product.name} added to your bag.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _moveToWishlist(CartItem item) async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Save to wishlist',
      trigger: AuthPromptTrigger.wishlist,
      productId: item.product.id,
      productPreview: AuthPromptProductPreview(
        name: item.product.name,
        imageUrl: item.product.images.isEmpty
            ? null
            : item.product.images.first,
      ),
      promptStyle: AuthPromptStyle.softSheet,
    );
    if (!allowed || !mounted) {
      return;
    }
    final wishlist = context.read<WishlistProvider>();
    try {
      await wishlist.addToWishlist(item.product);
      if (!mounted) {
        return;
      }
      context.read<CartProvider>().removeFromCart(item.product.id, item.size);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.product.name} moved to wishlist.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    }
  }

  void _changeSize(CartProvider cart, CartItem item, String size) {
    if (size == item.size) {
      return;
    }
    final quantity = item.quantity;
    cart.removeFromCart(item.product.id, item.size);
    for (var index = 0; index < quantity; index++) {
      cart.addToCart(item.product, size);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Size updated to $size.')));
  }
  String _addressLine(AppUser? user, UserAddress? guestAddress) {
    if (user != null) {
      final address = _cartAddressFromUser(user);
      if (address != null) {
        final parts = [
          address.houseDetails,
          address.addressLine,
          address.locality,
          address.city,
          address.state,
          address.pincode,
        ].where((s) => s.trim().isNotEmpty).toList();
        return parts.join(', ');
      }
      return 'No saved address';
    } else if (guestAddress != null && guestAddress.pincode.isNotEmpty) {
      return guestAddress.pincode;
    }
    return 'Select a location to see exact delivery date';
  }
  double _originalMrp(CartProvider cart) {
    return cart.items.fold<double>(0, (sum, item) {
      final original =
          item.product.originalPrice ??
          item.product.basePrice ??
          item.product.effectivePrice;
      return sum + (original * item.quantity);
    });
  }

  double _platformFee(CartProvider cart) => cart.customTailoringCharges;

  double _deliveryFee(CartProvider cart) => 0;

  double _catalogSavings(CartProvider cart) {
    return (_originalMrp(cart) - cart.subtotal).clamp(0.0, double.infinity);
  }

  double _totalSavings(CartProvider cart) {
    return (_catalogSavings(cart) + cart.discountAmount).clamp(
      0.0,
      double.infinity,
    );
  }

  double _totalAmount(CartProvider cart) {
    return cart.totalAmount + _platformFee(cart) + _deliveryFee(cart);
  }

  UserAddress? _selectedCartAddress(AppUser? user) => user != null ? _cartAddressFromUser(user) : _guestDeliveryAddress;

  Future<ProductServiceability?> _cartServiceabilitySummary(
    CartProvider cart,
    AppUser? user,
  ) async {
    final address = _selectedCartAddress(user);
    if (address == null || cart.items.isEmpty) {
      return null;
    }
    ProductServiceability? tryAtHome;
    ProductServiceability? localDelivery;
    ProductServiceability? courierDelivery;
    for (final item in cart.items) {
      final serviceability = await _deliveryService.getServiceability(
        product: item.product,
        address: address,
      );
      if (!serviceability.isDeliverable) {
        return serviceability;
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
    return tryAtHome ?? localDelivery ?? courierDelivery;
  }

  double _cartShippingCharge(CartProvider cart, ProductServiceability? serviceability) {
    if (cart.totalAmount >= 999) {
      return 0;
    }
    return serviceability?.shippingCharge ?? 0;
  }

  Future<String?> _cartCheckoutIssue(CartProvider cart, AppUser? user) async {
    final address = _selectedCartAddress(user);
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
      return 'This item uses a different delivery method. Please complete your current cart before adding products with another delivery method.';
    }
    return null;
  }

  Future<void> _showMixedDeliveryDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Different delivery method'),
        content: const Text(
          'This item uses a different delivery method.\n\nPlease complete your current cart before adding products with another delivery method.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  Future<void> _openCheckout() async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Checkout',
      trigger: AuthPromptTrigger.cart,
      promptStyle: AuthPromptStyle.fullScreen,
    );
    if (!allowed || !mounted) {
      return;
    }
    final cart = context.read<CartProvider>();
    final authUser = context.read<AuthProvider>().user;
    final messenger = ScaffoldMessenger.of(context);
    final checkoutIssue = await _cartCheckoutIssue(cart, authUser);
    if (checkoutIssue != null) {
      if (checkoutIssue.toLowerCase().contains('different delivery method')) {
        await _showMixedDeliveryDialog();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(checkoutIssue),
          ),
        );
      }
      return;
    }
    if (_openingCheckout || !mounted) {
      return;
    }
    _openingCheckout = true;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
    } finally {
      _openingCheckout = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: Consumer<CartProvider>(
          builder: (context, cart, child) {
            _ensureRecommendations(cart);

            if (cart.items.isEmpty) {
              return _EmptyBagView(onBack: () => Navigator.pop(context));
            }

            final totalSavings = _totalSavings(cart);
            final totalAmount = _totalAmount(cart);
            final dealsFuture =
                _dealsFuture ?? Future<List<Product>>.value(const []);
            final completeLookFuture =
                _completeTheLookFuture ?? Future<List<Product>>.value(const []);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _BagHeader(
                    savingsLabel: _currency.format(totalSavings),
                    onBack: () => Navigator.pop(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 108),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FutureBuilder<ProductServiceability?>(
                        future: _cartServiceabilitySummary(cart, auth.user),
                        builder: (context, snapshot) {
                          return _AddressCard(
                            user: auth.user,
                            deliveryEstimate: _cartServiceabilityLabel(cart, snapshot.data),
                            addressLine: _addressLine(auth.user, _guestDeliveryAddress),
                            onChange: _showAddressSheet,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Product>>(
                        future: dealsFuture,
                        builder: (context, snapshot) {
                          final products = (snapshot.data ?? const <Product>[])
                              .where(
                                (product) => !cart.items.any(
                                  (item) => item.product.id == product.id,
                                ),
                              )
                              .take(6)
                              .toList();
                          return _DealsUnlockSection(
                            amountLeft: (500 - cart.subtotal).clamp(
                              0.0,
                              double.infinity,
                            ),
                            products: products,
                            currency: _currency,
                            animatingIds: _animatingAddIds,
                            onAdd: _addSuggestionToCart,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ...cart.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CartLineItem(
                                item: item,
                                currency: _currency,
                                onDecrease: () => cart.updateQuantity(
                                  item.product.id,
                                  item.size,
                                  -1,
                                ),
                                onIncrease: () => cart.updateQuantity(
                                  item.product.id,
                                  item.size,
                                  1,
                                ),
                                onRemove: () =>
                                    cart.removeFromCart(item.product.id, item.size),
                                onMoveToWishlist: () => _moveToWishlist(item),
                                onSelectSize: (size) =>
                                    _changeSize(cart, item, size),
                              ),
                              const SizedBox(height: 8),
                                      _CartServiceabilityRow(
                                item: item,
                                address: _selectedCartAddress(auth.user),
                                deliveryService: _deliveryService,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PremiumCouponSummaryCard(
                        appliedCoupon: cart.appliedCoupon,
                        savingsAmount: totalSavings,
                        onChangeCoupon: _openCheckout,
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Product>>(
                        future: completeLookFuture,
                        builder: (context, snapshot) {
                          final fallback = productProvider.trendingProducts
                              .where(
                                (product) => !cart.items.any(
                                  (item) => item.product.id == product.id,
                                ),
                              )
                              .take(6)
                              .toList();
                          final suggestions =
                              (snapshot.data?.isNotEmpty ?? false)
                              ? snapshot.data!
                              : fallback;
                          return _RecommendationsSection(
                            title: 'You may also like',
                            products: suggestions,
                            currency: _currency,
                            animatingIds: _animatingAddIds,
                            onAdd: _addSuggestionToCart,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<ProductServiceability?>(
                        future: _cartServiceabilitySummary(cart, auth.user),
                        builder: (context, snapshot) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (cart.totalAmount < 999)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Add ${_currency.format(999 - cart.totalAmount)} more to get free delivery!',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF1D8B4D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              _PriceDetailsCard(
                                currency: _currency,
                                totalMrp: _originalMrp(cart),
                                discount: _totalSavings(cart),
                                deliveryFee: _cartShippingCharge(cart, snapshot.data),
                                platformFee: _platformFee(cart),
                                totalAmount: totalAmount,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _ReminderButton(
                        onTap: () async {
                          final user = auth.user;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sign in to save a reminder for this bag.',
                                ),
                              ),
                            );
                            return;
                          }
                          final items = cart.items
                              .map(
                                (item) => OrderItem(
                                  productId: item.product.id,
                                  productName: item.product.name,
                                  quantity: item.quantity,
                                  price: item.product.effectivePrice,
                                  size: item.size,
                                  imageUrl: item.product.images.isNotEmpty
                                      ? item.product.images.first
                                      : '',
                                ),
                              )
                              .toList();
                          await _database.createAbandonedCartReminder(
                            user: user,
                            items: items,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'We will remind you to come back to your bag.',
                              ),
                            ),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.items.isEmpty) {
              return const SizedBox.shrink();
            }
            return _BagFooter(
              amountLabel: _currency.format(_totalAmount(cart)),
              onViewDetails: () {},
              onPlaceOrder: _openCheckout,
            );
          },
        ),
      ),
    );
  }
}

class _BagHeader extends StatelessWidget {
  const _BagHeader({required this.savingsLabel, required this.onBack});

  final String savingsLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBF8),
          border: Border(bottom: BorderSide(color: const Color(0xFFE8E0D2))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HeaderCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Bag',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF202020),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You are saving $savingsLabel on this bag',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1D8B4D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _ProgressStepper(),
          ],
        ),
      ),
    );
  }
}

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 0.34),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Row(
          children: [
            const _StepperDot(label: 'Bag', active: true, complete: true),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 2, color: const Color(0xFFE6E3D7)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(height: 2, color: const Color(0xFFC8A95D)),
                  ),
                ],
              ),
            ),
            const _StepperDot(label: 'Address'),
            Expanded(
              child: Container(height: 2, color: const Color(0xFFE6E3D7)),
            ),
            const _StepperDot(label: 'Payment'),
          ],
        );
      },
    );
  }
}

class _StepperDot extends StatelessWidget {
  const _StepperDot({
    required this.label,
    this.active = false,
    this.complete = false,
  });

  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final dotColor = active || complete
        ? const Color(0xFFC8A95D)
        : const Color(0xFFCAC7BF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: active || complete
                    ? dotColor.withValues(alpha: 0.16)
                    : const Color(0xFFF0EFEB),
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 1.2),
              ),
              child: Icon(
                complete ? Icons.check_rounded : Icons.circle,
                size: complete ? 16 : 8,
                color: dotColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: active || complete
                    ? const Color(0xFF403A2C)
                    : const Color(0xFF8C877A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.user,
    required this.deliveryEstimate,
    required this.addressLine,
    required this.onChange,
  });

  final AppUser? user;
  final String deliveryEstimate;
  final String addressLine;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return _BagCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E2BB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Color(0xFFC8A95D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name.trim().isNotEmpty == true
                          ? user!.name
                          : 'Deliver to your address',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF222222),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6A655A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                ),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: Color(0xFF1D8B4D),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deliveryEstimate,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF2D2B26),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsUnlockSection extends StatelessWidget {
  const _DealsUnlockSection({
    required this.amountLeft,
    required this.products,
    required this.currency,
    required this.animatingIds,
    required this.onAdd,
  });

  final double amountLeft;
  final List<Product> products;
  final NumberFormat currency;
  final Set<String> animatingIds;
  final Future<void> Function(Product product) onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    final title = amountLeft > 0
        ? 'Shop for ${currency.format(amountLeft)} more to unlock special price'
        : 'Special price unlocked for your bag';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deals for you',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF201F1B),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6A655A)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return _MiniDealCard(
                product: product,
                currency: currency,
                animating: animatingIds.contains(product.id),
                onAdd: () => onAdd(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniDealCard extends StatelessWidget {
  const _MiniDealCard({
    required this.product,
    required this.currency,
    required this.animating,
    required this.onAdd,
  });

  final Product product;
  final NumberFormat currency;
  final bool animating;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: animating ? 0.95 : 1,
      duration: const Duration(milliseconds: 220),
      child: AnimatedOpacity(
        opacity: animating ? 0.78 : 1,
        duration: const Duration(milliseconds: 220),
        child: SizedBox(
          width: 138,
          child: _BagCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: AbzioNetworkImage(
                      imageUrl: product.images.isNotEmpty
                          ? product.images.first
                          : '',
                      fallbackLabel: product.name,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFC8A95D),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.rating.toStringAsFixed(1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF201F1B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(product.effectivePrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF201F1B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: onAdd,
                          child: Text(animating ? 'Added' : 'Add'),
                        ),
                      ),
                    ],
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

class _CartLineItem extends StatelessWidget {
  const _CartLineItem({
    required this.item,
    required this.currency,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    required this.onMoveToWishlist,
    required this.onSelectSize,
  });

  final CartItem item;
  final NumberFormat currency;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;
  final VoidCallback onMoveToWishlist;
  final ValueChanged<String> onSelectSize;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final currentPrice = product.effectivePrice;
    final originalPrice =
        product.originalPrice ?? product.basePrice ?? currentPrice;
    final discountPercent = originalPrice > currentPrice
        ? (((originalPrice - currentPrice) / originalPrice) * 100).round()
        : 0;
    final sizeUnavailable =
        product.sizes.isNotEmpty && !product.sizes.contains(item.size);

    return _BagCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 88,
              height: 88,
              child: AbzioNetworkImage(
                imageUrl: product.images.isNotEmpty ? product.images.first : '',
                fallbackLabel: product.name,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF7D786F),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF1F1F1C),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      currency.format(currentPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1E1D1A),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (originalPrice > currentPrice)
                      Text(
                        currency.format(originalPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF918D85),
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    if (discountPercent > 0)
                      Text(
                        '$discountPercent% OFF',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1D8B4D),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PillSelector(
                        label: 'Size ${item.size}',
                        onTap: () => _showSizePicker(context, product),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QuantitySelector(
                      quantity: item.quantity,
                      onDecrease: onDecrease,
                      onIncrease: onIncrease,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const _BadgeChip(
                      label: '7 days return',
                      icon: Icons.restart_alt_rounded,
                    ),
                    if (sizeUnavailable)
                      const _BadgeChip(
                        label: 'Size not available',
                        icon: Icons.warning_amber_rounded,
                        danger: true,
                      ),
                    if (product.isLimitedStock)
                      _BadgeChip(
                        label: '${product.stock} left',
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _InlineAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      onTap: onRemove,
                    ),
                    _InlineAction(
                      icon: Icons.favorite_border_rounded,
                      label: 'Move to wishlist',
                      onTap: onMoveToWishlist,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSizePicker(BuildContext context, Product product) async {
    if (product.sizes.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.4),
      builder: (context) => _SizeSelectionSheet(
        product: product,
        currentSize: item.size,
      ),
    );
    if (selected != null && selected != item.size) {
      onSelectSize(selected);
    }
  }
}

class _SizeSelectionSheet extends StatefulWidget {
  const _SizeSelectionSheet({
    required this.product,
    required this.currentSize,
  });

  final Product product;
  final String currentSize;

  @override
  State<_SizeSelectionSheet> createState() => _SizeSelectionSheetState();
}

class _SizeSelectionSheetState extends State<_SizeSelectionSheet> {
  late String _selectedSize;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.currentSize;
  }
  
  int? _getStockForSize(String size) {
    for (final cv in widget.product.colorVariants) {
      for (final szStock in cv.sizeStocks) {
        if (szStock.sizeName == size) return szStock.stockQuantity;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D0C0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Size',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.centerRight,
                      child: const Icon(
                        Icons.close,
                        size: 24,
                        color: Color(0xFF8A8272),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDE6D8)),
            
            // Size options
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.product.sizes.map((size) {
                    final isSelected = size == _selectedSize;
                    final stock = _getStockForSize(size);
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSize = size;
                              });
                              // Return selected size after brief delay
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (context.mounted) {
                                  Navigator.pop(context, size);
                                }
                              });
                            },
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1C1A16) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: isSelected ? null : Border.all(color: const Color(0xFFEDE6D8), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.check, size: 14, color: Colors.white),
                                    ),
                                  Text(
                                    size,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (stock != null && stock > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '$stock left',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A8272),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartServiceabilityRow extends StatelessWidget {
  const _CartServiceabilityRow({
    required this.item,
    required this.address,
    required this.deliveryService,
  });

  final CartItem item;
  final UserAddress? address;
  final DeliveryService deliveryService;

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return const _BadgeChip(
        label: 'Add delivery address to calculate serviceability',
        icon: Icons.place_outlined,
      );
    }
    return FutureBuilder<ProductServiceability>(
      future: deliveryService.getServiceability(
        product: item.product,
        address: address!,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _BadgeChip(
            label: '',
            icon: Icons.hourglass_bottom_rounded,
          );
        }
        final serviceability = snapshot.data!;
        final cart = Provider.of<CartProvider>(context, listen: false);
        final label = serviceability.isDeliverable
            ? _cartServiceabilityLabel(cart, serviceability)
            : 'Not deliverable to selected address';
        return _BadgeChip(
          label: label,
          icon: serviceability.supportsTryAtHome
              ? Icons.home_outlined
              : serviceability.supportsCourierDelivery
                  ? Icons.local_shipping_outlined
                  : Icons.block_outlined,
          danger: !serviceability.isDeliverable,
        );
      },
    );
  }
}

class _PillSelector extends StatelessWidget {
  const _PillSelector({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F4EE),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE7E1D3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF25231F),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7E1D3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onDecrease,
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              width: 30,
              height: 34,
              child: Icon(Icons.remove_rounded, size: 16),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$quantity',
              key: ValueKey<int>(quantity),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF25231F),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          InkWell(
            onTap: onIncrease,
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              width: 30,
              height: 34,
              child: Icon(Icons.add_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.icon,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? const Color(0xFFFFF1EE)
        : const Color(0xFFF4F7F1);
    final foreground = danger
        ? const Color(0xFFC4462D)
        : const Color(0xFF287048);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF5B564B)),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B564B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCouponSummaryCard extends StatelessWidget {
  const _PremiumCouponSummaryCard({
    required this.appliedCoupon,
    required this.savingsAmount,
    required this.onChangeCoupon,
  });

  final String? appliedCoupon;
  final double savingsAmount;
  final VoidCallback onChangeCoupon;

  @override
  Widget build(BuildContext context) {
    final hasCoupon =
        appliedCoupon != null && appliedCoupon!.trim().isNotEmpty;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return _BagCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7EFD8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: Color(0xFFC8A95D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCoupon ? 'Applied Coupon' : 'Coupons',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF201F1B),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCoupon
                          ? 'Your bag already has a coupon applied.'
                          : 'Review savings before you checkout.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6A655A),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChangeCoupon,
                child: Text(hasCoupon ? 'Change Coupon' : 'Review'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: hasCoupon
                ? Container(
                    key: ValueKey<String>(appliedCoupon!),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFC8A95D).withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF1D8B4D),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$appliedCoupon Applied',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You saved ${money.format(savingsAmount)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey<String>('no-coupon'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFC8A95D),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No coupon applied yet. Review checkout offers for a better price.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection({
    required this.title,
    required this.products,
    required this.currency,
    required this.animatingIds,
    required this.onAdd,
  });

  final String title;
  final List<Product> products;
  final NumberFormat currency;
  final Set<String> animatingIds;
  final Future<void> Function(Product product) onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF201F1B),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.take(4).length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.66,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return _RecommendationCard(
              product: product,
              currency: currency,
              animating: animatingIds.contains(product.id),
              onAdd: () => onAdd(product),
            );
          },
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.product,
    required this.currency,
    required this.animating,
    required this.onAdd,
  });

  final Product product;
  final NumberFormat currency;
  final bool animating;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: _BagCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 0.75,
                child: AbzioNetworkImage(
                  imageUrl: product.images.isNotEmpty
                      ? product.images.first
                      : '',
                  fallbackLabel: product.name,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFB38B2C),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF201F1B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(product.effectivePrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF201F1B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: AnimatedScale(
                      scale: animating ? 0.96 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: ElevatedButton(
                        onPressed: onAdd,
                        child: Text(animating ? 'Added' : 'Add to bag'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceDetailsCard extends StatelessWidget {
  const _PriceDetailsCard({
    required this.currency,
    required this.totalMrp,
    required this.discount,
    required this.deliveryFee,
    required this.platformFee,
    required this.totalAmount,
  });

  final NumberFormat currency;
  final double totalMrp;
  final double discount;
  final double deliveryFee;
  final double platformFee;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return _BagCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF201F1B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _PriceLine(label: 'Total MRP', value: currency.format(totalMrp)),
          const SizedBox(height: 6),
          _PriceLine(
            label: 'Discount',
            value: '-${currency.format(discount)}',
            valueColor: const Color(0xFF1D8B4D),
          ),
          const SizedBox(height: 6),
          if (deliveryFee > 0) ...[
            _PriceLine(
              label: 'Delivery Fee',
              value: currency.format(deliveryFee),
              valueColor: const Color(0xFF201F1B),
            ),
            const SizedBox(height: 6),
          ],
          _PriceLine(
            label: 'Platform Fee',
            value: currency.format(platformFee),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  if (deliveryFee == 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D8B4D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1D8B4D).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Free Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D8B4D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    currency.format(totalAmount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
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
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: valueColor ?? const Color(0xFF6B6960),
            fontWeight: FontWeight.w600,
          );
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
          style: style?.copyWith(color: valueColor ?? style.color),
        ),
      ],
    );
  }
}

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Remind me later'),
      ),
    );
  }
}

class _BagFooter extends StatefulWidget {
  const _BagFooter({
    required this.amountLabel,
    required this.onViewDetails,
    required this.onPlaceOrder,
  });

  final String amountLabel;
  final VoidCallback onViewDetails;
  final VoidCallback onPlaceOrder;

  @override
  State<_BagFooter> createState() => _BagFooterState();
}

class _BagFooterState extends State<_BagFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intentController;
  late final Animation<double> _liftY;
  late final Animation<double> _scale;
  late final Animation<double> _iconBounceY;
  bool _intentRunning = false;

  @override
  void initState() {
    super.initState();
    _intentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _liftY =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: -6),
            weight: 58,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: -6, end: 0),
            weight: 42,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _intentController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 1.05),
            weight: 58,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.05, end: 1),
            weight: 42,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _intentController,
            curve: Curves.easeOutCubic,
          ),
        );
    _iconBounceY =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: -5),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: -5, end: 0),
            weight: 55,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _intentController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    if (_intentRunning) {
      return;
    }
    _intentRunning = true;
    HapticFeedback.lightImpact();
    await _intentController.forward(from: 0);
    if (mounted) {
      widget.onPlaceOrder();
    }
    _intentRunning = false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFEFDFC), Colors.white],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: const Color(0xFFF0ECE2))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackVertically = constraints.maxWidth < 320;
            final amountBlock = Column(
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
                    'Bag total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7B5C1A),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.amountLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF201F1B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                InkWell(
                  onTap: widget.onViewDetails,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF6A655A),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 16,
                          color: Color(0xFF6A655A),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            final actionButton = AnimatedBuilder(
              animation: _intentController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _liftY.value),
                  child: Transform.scale(scale: _scale.value, child: child),
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD9C27A), Color(0xFFC6A769)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC8A95D).withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _handlePlaceOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _intentController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _iconBounceY.value),
                            child: child,
                          );
                        },
                        child: const Icon(Icons.shopping_bag_rounded, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text(
                            'PROCEED TO CHECKOUT',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (stackVertically) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  amountBlock,
                  const SizedBox(height: 12),
                  actionButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: amountBlock),
                const SizedBox(width: 14),
                Expanded(child: actionButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyBagView extends StatelessWidget {
  const _EmptyBagView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _HeaderCircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
            ),
            const Spacer(),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4D6), Color(0xFFF0E1B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Color(0xFFC8A95D),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your bag is empty',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 28,
                color: const Color(0xFF22211D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add standout pieces from nearby stores and return here for a smoother checkout.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6A655A)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBack,
                child: const Text('Start Shopping'),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _BagCard extends StatelessWidget {
  const _BagCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E0D2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF25231F)),
        ),
      ),
    );
  }
}
