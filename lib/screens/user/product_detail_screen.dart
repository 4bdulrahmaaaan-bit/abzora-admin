import 'package:abzio/services/app_config.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../models/mediapipe_try_on_payload.dart';
import '../../models/ar_try_on_models.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/database_service.dart';
import '../../services/delivery_service.dart';

import '../../models/delivery_serviceability.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
import '../../utils/local_file_image.dart';
import '../../utils/soft_auth_gate.dart';
import '../../widgets/animated_wishlist_button.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/location_selection_sheet.dart';
import '../../widgets/state_views.dart';
import 'ai_stylist_screen.dart';
import 'abianzo_ar_screen.dart';
import 'size_recommendation_screen.dart';
import 'checkout_screen.dart';

import 'tbyb/tbyb_product_selection_screen.dart';
import 'store_detail_screen.dart';

enum _DeliveryAvailabilityState {
  idle,
  loading,
  ready,
  noAddress,
  error,
}

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static final Map<String, Color> _accentColorCache = <String, Color>{};

  final _db = DatabaseService();
  final _backendCommerce = BackendCommerceService();
  final _picker = ImagePicker();
  String? _selectedSize;
  List<ReviewModel> _reviews = [];
  List<Product> _completeTheLook = [];
  Product? _resolvedProduct;
  late PageController _imageController;
  late final AnimationController _cartFlightController;
  late final AnimationController _cartPulseController;
  late final Animation<double> _cartPulseScale;
  late final AuthProvider _authProvider;
  int _imageIndex = 0;
  int _selectedColorIndex = 0;
  final GlobalKey _cartIconKey = GlobalKey();
  Offset? _cartFlightStart;
  Offset? _cartFlightEnd;
  final Size _cartFlightSize = const Size(88, 112);
  final bool _showCartFlight = false;
  final DeliveryService _deliveryService = DeliveryService();
  final DatabaseService _addressBook = DatabaseService();
  UserAddress? _deliveryAddress;
  ProductServiceability? _serviceability;
  String _serviceabilityCacheKey = '';
  String _deliveryAddressKey = '';
  int _serviceabilityRequestSerial = 0;
  _DeliveryAvailabilityState _deliveryAvailabilityState =
      _DeliveryAvailabilityState.idle;
  String? _deliveryAvailabilityError;
  String _ctaDecisionType = 'BUY_NOW_PRIORITY';
  int _decisionFitConfidence = 88;
  String _experienceDecisionId = '';
  late final String _experienceSessionId;
  bool _ctaShownTracked = false;
  Timer? _countdownTimer;
  int _countdownMinutesLeft = 0;
  bool _isBottomBarVisible = true;
  double _lastPdpScrollOffset = 0;
  double _pdpScrollDeltaAccumulator = 0;
  static const double _pdpBottomBarToggleThreshold = 18;
  Timer? _liveProductRefreshTimer;
  bool _refreshingLiveProduct = false;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_handleAuthChanged);
    _experienceSessionId =
        'pdp-${DateTime.now().millisecondsSinceEpoch}-${widget.product.id}';
    _imageController = PageController();
    _cartFlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _cartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _cartPulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.16,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.16,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
    ]).animate(_cartPulseController);
    if (widget.product.images.isNotEmpty) {
      Future.microtask(() => _resolveAccentColor(widget.product.images));
    }
    Future.microtask(_loadData);
    Future.microtask(_bootstrapDeliveryContext);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_handleAuthChanged);
    _countdownTimer?.cancel();
    _liveProductRefreshTimer?.cancel();
    _imageController.dispose();
    _cartFlightController.dispose();
    _cartPulseController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadData() async {
    final currentUser = context.read<AuthProvider>().user;
    await _db.recordProductView(widget.product, user: currentUser);
    final results = await Future.wait([
      _db.getProductReviews(widget.product.id),
      _db.getCompleteTheLook(widget.product),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<ReviewModel>;
      _completeTheLook = results[1] as List<Product>;
      _resolvedProduct = widget.product;
    });
    _syncCountdownTimer();
    _startLiveProductRefresh();
    unawaited(
      _trackExperienceEvent(
        'product_view',
        metadata: {'screen': 'product_detail'},
      ),
    );
    unawaited(_loadCtaDecision());
  }

  void _startLiveProductRefresh() {
    _liveProductRefreshTimer?.cancel();
    _liveProductRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refreshLiveProduct()),
    );
    unawaited(_refreshLiveProduct());
  }

  Future<void> _refreshLiveProduct() async {
    if (_refreshingLiveProduct || !mounted) {
      return;
    }
    _refreshingLiveProduct = true;
    try {
      final freshProduct = await _db.getProductById(widget.product.id);
      if (!mounted || freshProduct == null) {
        return;
      }
      if (_product.price == freshProduct.price &&
          _product.originalPrice == freshProduct.originalPrice &&
          _product.dynamicPrice == freshProduct.dynamicPrice &&
          _product.stock == freshProduct.stock &&
          _product.images.length == freshProduct.images.length &&
          _product.colorVariants.length == freshProduct.colorVariants.length) {
        return;
      }
      setState(() {
        _resolvedProduct = freshProduct;
      });
      _syncCountdownTimer();
    } catch (error) {
      debugPrint('PDP live refresh failed: $error');
    } finally {
      _refreshingLiveProduct = false;
    }
  }

  bool _handlePdpScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.metrics.pixels <= 0) {
      _lastPdpScrollOffset = 0;
      _pdpScrollDeltaAccumulator = 0;
      if (!_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = true);
      }
      return false;
    }

    if (notification is ScrollStartNotification) {
      _lastPdpScrollOffset = notification.metrics.pixels;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      final delta = currentOffset - _lastPdpScrollOffset;
      _lastPdpScrollOffset = currentOffset;

      if (delta.abs() < 0.5) {
        return false;
      }

      _pdpScrollDeltaAccumulator += delta;
      if (_pdpScrollDeltaAccumulator >= _pdpBottomBarToggleThreshold) {
        _pdpScrollDeltaAccumulator = 0;
        if (_isBottomBarVisible) {
          setState(() => _isBottomBarVisible = false);
        }
      } else if (_pdpScrollDeltaAccumulator <= -_pdpBottomBarToggleThreshold) {
        _pdpScrollDeltaAccumulator = 0;
        if (!_isBottomBarVisible) {
          setState(() => _isBottomBarVisible = true);
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels <= 0 && !_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = true);
      }
    }

    return false;
  }

  String _ctaActionFromDecision(String decisionType) {
    final normalized = decisionType.toUpperCase();
    if (normalized == 'BUY_NOW_PRIORITY') {
      return 'BUY_NOW';
    }
    if (normalized == 'TRY_AT_HOME_PRIORITY') {
      return 'TRY_HOME';
    }
    return 'HYBRID';
  }

  Future<void> _trackExperienceEvent(
    String eventType, {
    String? cta,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    await _db.trackExperienceEvent(
      eventType: eventType,
      userId: userId,
      sessionId: _experienceSessionId,
      productId: _product.id,
      decisionId: _experienceDecisionId,
      cta: cta ?? _ctaActionFromDecision(_ctaDecisionType),
      metadata: metadata,
    );
  }

  Future<void> _loadCtaDecision() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final product = _product;
    final localDecision = _resolveLocalCtaDecision(
      user: user,
      product: product,
    );
    try {
      final payload = await _db.getCtaDecision(
        productId: product.id,
        userId: user?.id ?? '',
        fitConfidence: localDecision.fitConfidence,
        returnHistory: localDecision.returnHistory,
        userType: localDecision.userType,
        productType: localDecision.productType,
        locationSpeed: localDecision.locationSpeed,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ctaDecisionType = payload['type']?.toString().trim().isNotEmpty == true
            ? payload['type'].toString().trim()
            : localDecision.type;
        _decisionFitConfidence =
            (payload['fitConfidence'] as num?)?.toInt() ??
            localDecision.fitConfidence;
        _experienceDecisionId =
            payload['decisionId']?.toString() ?? _experienceDecisionId;
      });
      if (!_ctaShownTracked) {
        _ctaShownTracked = true;
        unawaited(_trackExperienceEvent('cta_shown'));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ctaDecisionType = localDecision.type;
        _decisionFitConfidence = localDecision.fitConfidence;
      });
      if (!_ctaShownTracked) {
        _ctaShownTracked = true;
        unawaited(_trackExperienceEvent('cta_shown'));
      }
    }
  }

  Product get _product => _resolvedProduct ?? widget.product;

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_bootstrapDeliveryContext(force: false));
  }

  Future<void> _bootstrapDeliveryContext({bool force = false}) async {
    if (!mounted) {
      return;
    }
    final user = _authProvider.user;
    if (user == null) {
      final profileAddress = _fallbackAddressFromUser(user);
      if (profileAddress == null) {
        setState(() {
          _deliveryAddress = null;
          _deliveryAddressKey = '';
          _serviceability = null;
          _serviceabilityCacheKey = '';
          _deliveryAvailabilityState = _DeliveryAvailabilityState.noAddress;
          _deliveryAvailabilityError = null;
        });
        return;
      }
      if (_deliveryAvailabilityState != _DeliveryAvailabilityState.noAddress ||
          _deliveryAddress != null ||
          _serviceability != null ||
          _deliveryAvailabilityError != null) {
        setState(() {
          _deliveryAddress = null;
          _deliveryAddressKey = '';
          _serviceability = null;
          _serviceabilityCacheKey = '';
          _deliveryAvailabilityState = _DeliveryAvailabilityState.noAddress;
          _deliveryAvailabilityError = null;
        });
      }
      return;
    }



    UserAddress? resolvedAddress;
    try {
      final savedAddresses = await _addressBook.getUserAddresses(user.id);
      resolvedAddress = _resolveDefaultDeliveryAddress(user, savedAddresses);
    } catch (error) {
      debugPrint('PDP saved address load failed: $error');
      resolvedAddress = _fallbackAddressFromUser(user);
    }

    if (!mounted) {
      return;
    }
    if (resolvedAddress == null) {
      setState(() {
        _deliveryAddress = null;
        _deliveryAddressKey = '';
        _serviceability = null;
        _serviceabilityCacheKey = '';
        _deliveryAvailabilityState = _DeliveryAvailabilityState.noAddress;
        _deliveryAvailabilityError = null;
      });
      return;
    }

    final signature = _deliveryAddressSignature(resolvedAddress);
    final changed = force || signature != _deliveryAddressKey;
    if (changed) {
      setState(() {
        _deliveryAddress = resolvedAddress;
        _deliveryAddressKey = signature;
        _deliveryAvailabilityState = _DeliveryAvailabilityState.loading;
        _deliveryAvailabilityError = null;
      });
      await _refreshServiceability(force: true);
    } else {
      await _refreshServiceability(force: false);
    }
  }

  UserAddress? _resolveDefaultDeliveryAddress(
    AppUser user,
    List<UserAddress> addresses,
  ) {
    if (addresses.isNotEmpty) {
      final preferred = addresses.firstWhere(
        (address) => address.type.trim().toLowerCase() == 'home',
        orElse: () => addresses.first,
      );
      if (preferred.pincode.trim().isNotEmpty ||
          preferred.latitude != null ||
          preferred.longitude != null) {
        return preferred;
      }
      for (final address in addresses) {
        if (address.pincode.trim().isNotEmpty ||
            address.latitude != null ||
            address.longitude != null) {
          return address;
        }
      }
      return _fallbackAddressFromUser(user);
    }
    return _fallbackAddressFromUser(user);
  }

  UserAddress? _fallbackAddressFromUser(AppUser? user) {
    if (user == null) {
      return null;
    }
    final addressLine = user.address?.trim() ?? '';
    final pincodeMatch = RegExp(r'\b\d{6}\b').firstMatch(addressLine);
    if (pincodeMatch == null && user.latitude == null && user.longitude == null) {
      return null;
    }
    return UserAddress(
      id: 'profile-address',
      userId: user.id,
      name: user.name.trim().isEmpty ? 'Abianzo Member' : user.name.trim(),
      phone: user.phone ?? '',
      addressLine: addressLine,
      city: user.city?.trim().isNotEmpty == true
          ? user.city!.trim()
          : (user.area?.trim().isNotEmpty == true ? user.area!.trim() : ''),
      state: '',
      pincode: pincodeMatch?.group(0) ?? '',
      houseDetails: '',
      landmark: user.area?.trim() ?? '',
      locality: user.area?.trim() ?? '',
      latitude: user.latitude,
      longitude: user.longitude,
      type: 'home',
      createdAt:
          user.locationUpdatedAt ?? user.createdAt ?? DateTime.now().toIso8601String(),
    );
  }

  String _deliveryAddressSignature(UserAddress address) {
    return [
      address.id,
      address.userId,
      address.addressLine.trim(),
      address.locality.trim(),
      address.city.trim(),
      address.pincode.trim(),
      address.latitude?.toStringAsFixed(5) ?? 'na',
      address.longitude?.toStringAsFixed(5) ?? 'na',
    ].join('|');
  }

  AppUser? _currentUser() => context.read<AuthProvider>().user;

  UserAddress? _serviceabilityAddressSnapshot() {
    final address = _deliveryAddress;
    if (address != null) {
      return address;
    }
    return _fallbackAddressFromUser(_currentUser());
  }

  String _serviceabilityCacheSignature(Product product, UserAddress address) {
    final selectedVariantId = _variants.isEmpty
        ? ''
        : _variants[_selectedColorIndex.clamp(0, _variants.length - 1)]
              .variantId;
    return [
      product.id,
      selectedVariantId,
      address.latitude?.toStringAsFixed(5) ?? 'na',
      address.longitude?.toStringAsFixed(5) ?? 'na',
      address.city.trim(),
      address.state.trim(),
      address.pincode.trim(),
    ].join('|');
  }

  bool get _supportsTryAtHomeMode =>
      _serviceability?.supportsTryAtHome == true;

  bool get _supportsCourierDeliveryMode =>
      _serviceability?.supportsCourierDelivery == true;

  bool get _isDeliverableLocation => _serviceability?.isDeliverable == true;

  bool get _isProductInStock => _activeVariantStock > 0;

  bool get _canTryAtHome =>
      _isProductInStock && _supportsTryAtHomeMode && _isDeliverableLocation;

  bool get _isSameDayDeliveryAvailable {
    final serviceability = _serviceability;
    if (serviceability == null || !serviceability.isDeliverable) {
      return false;
    }
    return serviceability.supportsTryAtHome ||
        serviceability.supportsInstantDelivery ||
        serviceability.deliveryMode == DeliveryMode.localDelivery;
  }

  String _serviceabilityOrderWithinLabel() {
    final serviceability = _serviceability;
    if (serviceability == null || !serviceability.isDeliverable) {
      return '';
    }
    final etaLabel = serviceability.etaLabel.trim();
    if (etaLabel.isNotEmpty) {
      return 'Order within $etaLabel';
    }
    final minutes = serviceability.etaMinutes;
    if (minutes <= 0) {
      return 'Order within 1 hr';
    }
    if (minutes < 60) {
      return 'Order within $minutes mins';
    }
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) {
      return 'Order within $hours hrs';
    }
    return 'Order within $hours hrs $remainder mins';
  }

  String _serviceabilityEtaLabel() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.noAddress) {
      return 'Set delivery location';
    }
    if (state == _DeliveryAvailabilityState.loading) {
      return '';
    }
    if (state == _DeliveryAvailabilityState.error) {
      return 'Tap Retry';
    }
    final serviceability = _serviceability;
    if (serviceability == null) {
      return 'Set delivery location';
    }
    if (!serviceability.isDeliverable) {
      return 'Unavailable';
    }
    if (_isSameDayDeliveryAvailable) {
      return 'Today';
    }
    final eta = serviceability.estimatedDeliveryDate.trim();
    if (eta.isNotEmpty) {
      try {
        final parsed = DateTime.parse(eta);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final deliveryDay = DateTime(parsed.year, parsed.month, parsed.day);
        final diff = deliveryDay.difference(today).inDays;
        if (diff == 0) {
          return 'Today';
        } else if (diff == 1) {
          return 'Tomorrow';
        } else if (diff > 1 && diff <= 14) {
          return 'In $diff days';
        } else {
          return DateFormat('MMM d').format(parsed);
        }
      } catch (_) {
        return eta;
      }
    }
    if (serviceability.etaLabel.trim().isNotEmpty) {
      return serviceability.etaLabel.trim();
    }
    return 'Soon';
  }



  String _serviceabilityHeadline() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.noAddress) {
      return 'Set delivery location';
    }
    if (state == _DeliveryAvailabilityState.loading) {
      return '';
    }
    if (state == _DeliveryAvailabilityState.error) {
      return 'Unable to check delivery';
    }
    final serviceability = _serviceability;
    if (serviceability == null) {
      return 'Set delivery location';
    }
    if (!serviceability.isDeliverable) {
      return 'Currently unavailable for your location';
    }
    if (_isSameDayDeliveryAvailable) {
      return 'Same-day delivery available';
    }
    return 'Delivery available';
  }

  String _serviceabilityDetails() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.noAddress) {
      return 'Choose a delivery location to check availability.';
    }
    if (state == _DeliveryAvailabilityState.loading) {
      return '';
    }
    if (state == _DeliveryAvailabilityState.error) {
      return 'Unable to check delivery. Tap Retry.';
    }
    final serviceability = _serviceability;
    if (serviceability == null) {
      return 'Choose a delivery location to check availability.';
    }
    if (!serviceability.isDeliverable) {
      return 'Currently unavailable for your location.';
    }
    if (_isSameDayDeliveryAvailable) {
      final orderWithin = _serviceabilityOrderWithinLabel();
      final etaLabel = _serviceabilityEtaLabel();
      return orderWithin.isNotEmpty
          ? '$orderWithin • ETA $etaLabel'
          : 'ETA $etaLabel';
    }
    final deliveryDate = _serviceabilityEtaLabel();
    if (deliveryDate.isEmpty) return 'Courier Delivery';
    
    if (deliveryDate == 'Today' || deliveryDate == 'Tomorrow' || deliveryDate.startsWith('In ')) {
      return 'Arrives $deliveryDate';
    }
    return 'Arrives by $deliveryDate';
  }

  Future<void> _refreshServiceability({bool force = false}) async {
    final address = _serviceabilityAddressSnapshot();
    if (address == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serviceability = null;
        _serviceabilityCacheKey = '';
        _deliveryAvailabilityState = _DeliveryAvailabilityState.noAddress;
        _deliveryAvailabilityError = null;
      });
      return;
    }
    final product = _product;
    final cacheKey = _serviceabilityCacheSignature(product, address);
    if (!force && _serviceabilityCacheKey == cacheKey && _serviceability != null) {
      if (mounted && _deliveryAvailabilityState != _DeliveryAvailabilityState.ready) {
        setState(() {
          _deliveryAvailabilityState = _DeliveryAvailabilityState.ready;
          _deliveryAvailabilityError = null;
        });
      }
      return;
    }
    final requestSerial = ++_serviceabilityRequestSerial;
    if (!mounted) {
      return;
    }
    setState(() {
      _deliveryAvailabilityState = _DeliveryAvailabilityState.loading;
      _deliveryAvailabilityError = null;
    });
    try {
      final serviceability = await _deliveryService.getServiceability(
        product: product,
        address: address,
      ).timeout(const Duration(seconds: 15));
      if (!mounted || requestSerial != _serviceabilityRequestSerial) {
        return;
      }
      setState(() {
        _serviceability = serviceability;
        _serviceabilityCacheKey = cacheKey;
        _deliveryAvailabilityState = _DeliveryAvailabilityState.ready;
        _deliveryAvailabilityError = null;
      });
    } on TimeoutException catch (error) {
      if (!mounted || requestSerial != _serviceabilityRequestSerial) {
        return;
      }
      final hadExistingServiceability = _serviceability != null;
      setState(() {
        _serviceabilityCacheKey = cacheKey;
        _deliveryAvailabilityState = hadExistingServiceability
            ? _DeliveryAvailabilityState.ready
            : _DeliveryAvailabilityState.error;
        _deliveryAvailabilityError = error.message ?? 'timeout';
      });
    } catch (error) {
      if (!mounted || requestSerial != _serviceabilityRequestSerial) {
        return;
      }
      final hadExistingServiceability = _serviceability != null;
      setState(() {
        _serviceabilityCacheKey = cacheKey;
        _deliveryAvailabilityState = hadExistingServiceability
            ? _DeliveryAvailabilityState.ready
            : _DeliveryAvailabilityState.error;
        _deliveryAvailabilityError = error.toString();
      });
    }
  }


  List<ProductColorVariant> get _variants {
    final variants = _product.colorVariants;
    if (variants.isNotEmpty) {
      return variants;
    }
    final fallback = ProductColorVariant(
      name: _product.brand.trim().isNotEmpty
          ? _product.brand.trim()
          : 'Default',
      colorName: _product.brand.trim().isNotEmpty
          ? _product.brand.trim()
          : 'Default',
      hex: '#C6A769',
      imageUrl: _product.images.isNotEmpty ? _product.images.first : '',
      sku: _product.id,
      stock: _product.stock,
      images: _product.images,
      sizes: _product.sizes,
    );
    return [fallback];
  }

  void _syncCountdownTimer() {
    _countdownTimer?.cancel();
    final minutes =
        (_selectedVariant.deliveryInfo['countdownMinutes'] as num?)?.toInt() ??
        (_product.deliveryInfo['countdownMinutes'] as num?)?.toInt() ??
        0;
    _countdownMinutesLeft = minutes;
    if (minutes <= 0) {
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownMinutesLeft <= 0) {
        timer.cancel();
        setState(() {});
        return;
      }
      setState(() => _countdownMinutesLeft -= 1);
    });
  }

  void _selectColorVariant(int index) {
    if (index < 0 || index >= _variants.length) {
      return;
    }
    if (_selectedColorIndex == index) {
      return;
    }
    setState(() {
      _selectedColorIndex = index;
      _selectedSize = null;
      _imageIndex = 0;
      _imageController.dispose();
      _imageController = PageController();
    });
    _syncCountdownTimer();
    unawaited(_refreshServiceability(force: true));
  }

  ProductColorVariant get _selectedVariant =>
      _variants[_selectedColorIndex.clamp(0, _variants.length - 1)];

  List<String> get _activeImages {
    final images = _selectedVariant.images
        .where((item) => item.trim().isNotEmpty)
        .toList();
    if (images.isNotEmpty) {
      return images;
    }
    if (_selectedVariant.imageUrl.trim().isNotEmpty) {
      return [_selectedVariant.imageUrl.trim()];
    }
    return _product.images.isNotEmpty
        ? _product.images
        : const ['https://via.placeholder.com/600x750'];
  }

  List<String> get _activeSizes {
    final sizes = _selectedVariant.sizes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (sizes.isNotEmpty) {
      return sizes;
    }
    return _product.sizes;
  }

  int get _activeVariantStock {
    if (_selectedVariant.stock > 0) {
      return _selectedVariant.stock;
    }
    if (_selectedVariant.sizeStocks.isNotEmpty) {
      return _selectedVariant.sizeStocks.fold<int>(
        0,
        (sum, entry) => sum + entry.stockQuantity,
      );
    }
    return _product.stock;
  }

  Map<String, int> get _activeSizeStocks {
    final sizeStocks = <String, int>{};
    for (final entry in _selectedVariant.sizeStocks) {
      final size = entry.sizeName.trim().toUpperCase();
      if (size.isNotEmpty) {
        sizeStocks[size] = entry.stockQuantity;
      }
    }
    if (sizeStocks.isNotEmpty) {
      return sizeStocks;
    }
    final fallback = _activeSizes;
    if (fallback.isEmpty) {
      return const {};
    }
    final perSize = (_activeVariantStock / fallback.length).floor();
    return {for (final size in fallback) size.toUpperCase(): perSize};
  }

  String get _selectedColorName {
    final name = _selectedVariant.colorName.trim().isNotEmpty
        ? _selectedVariant.colorName.trim()
        : _selectedVariant.name.trim();
    return name.isNotEmpty ? name : 'Default';
  }

  double get _activePrice {
    final discountPrice = _selectedVariant.discountPrice;
    final variantPrice = _selectedVariant.price;
    if (discountPrice != null &&
        variantPrice != null &&
        discountPrice < variantPrice) {
      return discountPrice;
    }
    if (variantPrice != null && variantPrice > 0) {
      return variantPrice;
    }
    return _product.effectivePrice;
  }

  double? get _activeOriginalPrice {
    final discountPrice = _selectedVariant.discountPrice;
    final variantPrice = _selectedVariant.price;
    if (discountPrice != null &&
        variantPrice != null &&
        discountPrice < variantPrice) {
      return variantPrice;
    }
    return _product.originalPrice;
  }

  String _stockStatusLabel(int stock) {
    if (stock <= 0) {
      return 'Out of Stock';
    }
    if (stock <= 3) {
      return 'Only $stock Left';
    }
    if (stock <= 8) {
      return 'Low Stock';
    }
    return 'In Stock';
  }

  bool get _hasMultipleColors => _variants.length > 1;

  int get _selectedVariantReviewCount {
    final reviews = _reviews.length;
    return reviews;
  }

  double get _selectedVariantRating {
    if (_reviews.isEmpty) {
      return _product.rating;
    }
    return _reviews.fold<double>(0, (sum, review) => sum + review.rating) /
        _reviews.length;
  }

  _DetailPricing get _pricing => _DetailPricing.fromProduct(_product);

  Color _heroAccentColor(Product product, List<String> images) {
    final seed =
        '${product.category}|${images.isEmpty ? product.id : images.first}';
    final hue = (seed.hashCode.abs() % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.48, 0.82).toColor();
  }

  String _heroTagFor(Product product, int index) =>
      'product-hero-${product.id}-$index';

  Future<void> _resolveAccentColor(List<String> images) async {
    final imageUrl = images.isEmpty ? null : images.first;
    if (imageUrl == null) {
      return;
    }
    if (_accentColorCache.containsKey(imageUrl)) {
      return;
    }

    try {
      final provider = CachedNetworkImageProvider(imageUrl);
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ImageInfo>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, synchronousCall) {
          stream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.complete(info);
          }
        },
        onError: (error, stackTrace) {
          stream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );
      stream.addListener(listener);

      final imageInfo = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      final byteData = await imageInfo.image.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        return;
      }

      final pixels = byteData.buffer.asUint8List();
      final width = imageInfo.image.width;
      final height = imageInfo.image.height;
      final stepX = math.max(1, width ~/ 24).toInt();
      final stepY = math.max(1, height ~/ 24).toInt();
      double red = 0;
      double green = 0;
      double blue = 0;
      int samples = 0;

      for (var y = 0; y < height; y += stepY) {
        for (var x = 0; x < width; x += stepX) {
          final index = (y * width + x) * 4;
          if (index + 3 >= pixels.length) {
            continue;
          }
          final alpha = pixels[index + 3];
          if (alpha < 24) {
            continue;
          }
          final pixelRed = pixels[index];
          final pixelGreen = pixels[index + 1];
          final pixelBlue = pixels[index + 2];
          final brightness = (pixelRed + pixelGreen + pixelBlue) / (3 * 255.0);
          if (brightness < 0.1 || brightness > 0.96) {
            continue;
          }
          red += pixelRed;
          green += pixelGreen;
          blue += pixelBlue;
          samples++;
        }
      }

      final fallback = _heroAccentColor(widget.product, images);
      final averaged = samples == 0
          ? fallback
          : Color.fromARGB(
              255,
              (red / samples).round().clamp(0, 255),
              (green / samples).round().clamp(0, 255),
              (blue / samples).round().clamp(0, 255),
            );
      final hsl = HSLColor.fromColor(averaged);
      final refined = hsl
          .withSaturation(hsl.saturation.clamp(0.35, 0.78))
          .withLightness(hsl.lightness.clamp(0.42, 0.62))
          .toColor();
      _accentColorCache[imageUrl] = refined;
    } catch (_) {
      // Fallback remains in use if extraction fails.
    }
  }

  Future<void> _openReviewSheet([ReviewModel? existing]) async {
    final auth = context.read<AuthProvider>();
    final commentController = TextEditingController(
      text: existing?.comment ?? '',
    );
    double rating = existing?.rating ?? 5;
    String? imagePath = existing?.imagePath;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Write Review' : 'Edit Review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Rating: ${rating.toStringAsFixed(1)}'),
              Slider(
                value: rating,
                min: 1,
                max: 5,
                divisions: 8,
                onChanged: (value) => setModalState(() => rating = value),
              ),
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Tell others what stood out',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file != null) {
                        setModalState(() => imagePath = file.path);
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('ADD IMAGE'),
                  ),
                  const SizedBox(width: 12),
                  if (imagePath != null)
                    Expanded(
                      child: Text(
                        localFileName(imagePath!),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final currentUser = auth.user;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Sign in to leave a review.'),
                        ),
                      );
                      return;
                    }
                    final review = ReviewModel(
                      id: existing?.id ?? '',
                      userId: currentUser.id,
                      userName: currentUser.name,
                      targetId: widget.product.id,
                      targetType: 'product',
                      rating: rating,
                      comment: commentController.text.trim(),
                      imagePath: imagePath,
                      createdAt: DateTime.now(),
                    );
                    try {
                      await _db.saveReview(review);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(AppErrorText.from(error)),
                          ),
                        );
                      }
                      return;
                    }
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('SAVE REVIEW'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    commentController.dispose();
    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _deleteReview(ReviewModel review) async {
    try {
      await _db.deleteReview(review.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(AppErrorText.from(error)),
          ),
        );
      }
      return;
    }
    await _loadData();
  }

  String _resolveDeliverySummary() {
    return _serviceabilityHeadline();
  }

  Future<void> _openDeliveryAddressSheet() async {
    final result = await LocationSelectionSheet.show(
      context,
      product: widget.product,
    );
    if (!mounted || result == null) return;

    if (result is UserAddress) {
      setState(() {
        _deliveryAddress = result;
        _deliveryAddressKey = _deliveryAddressSignature(result);
      });
    } else if (result is String) {
      // Pincode only
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
      setState(() {
        _deliveryAddress = dummyAddress;
        _deliveryAddressKey = _deliveryAddressSignature(dummyAddress);
      });
    }
    unawaited(_refreshServiceability(force: true));
  }

  String _sameDayCity(AuthProvider auth) {
    final city = (auth.user?.city ?? '').trim();
    if (city.isNotEmpty) {
      return city;
    }
    final area = (auth.user?.area ?? '').trim();
    if (area.isNotEmpty) {
      return area;
    }
    return 'your city';
  }

  _CtaDecisionSnapshot _resolveLocalCtaDecision({
    required AppUser? user,
    required Product product,
  }) {
    final productType = _isComplexFitProduct(product) ? 'complex' : 'simple';
    final locationSpeed =
        _sameDayCity(context.read<AuthProvider>()) == 'your city'
        ? 'normal'
        : 'same_day';
    final userType = user == null ? 'new' : 'repeat';
    final fitConfidence = _recommendedFitConfidence(
      product,
      userType: userType,
    );
    const returnHistory = 12.0;

    if (fitConfidence >= 85 && locationSpeed == 'same_day') {
      return _CtaDecisionSnapshot(
        type: 'BUY_NOW_PRIORITY',
        fitConfidence: fitConfidence,
        reason: 'High fit confidence with same-day fulfillment.',
        returnHistory: returnHistory,
        userType: userType,
        productType: productType,
        locationSpeed: locationSpeed,
      );
    }
    if (fitConfidence < 70 || returnHistory >= 35) {
      return _CtaDecisionSnapshot(
        type: 'TRY_AT_HOME_PRIORITY',
        fitConfidence: fitConfidence,
        reason: 'Confidence is lower; trial can reduce return risk.',
        returnHistory: returnHistory,
        userType: userType,
        productType: productType,
        locationSpeed: locationSpeed,
      );
    }
    if (userType == 'new') {
      return _CtaDecisionSnapshot(
        type: 'TRY_AT_HOME_PRIORITY',
        fitConfidence: fitConfidence,
        reason: 'New-user confidence flow prefers try-at-home first.',
        returnHistory: returnHistory,
        userType: userType,
        productType: productType,
        locationSpeed: locationSpeed,
      );
    }
    return _CtaDecisionSnapshot(
      type: 'HYBRID',
      fitConfidence: fitConfidence,
      reason: 'Balanced confidence profile; show both actions.',
      returnHistory: returnHistory,
      userType: userType,
      productType: productType,
      locationSpeed: locationSpeed,
    );
  }

  bool _isComplexFitProduct(Product product) {
    final category = product.category.trim().toLowerCase();
    const complex = {
      'dress',
      'dresses',
      'gown',
      'gowns',
      'blazer',
      'blazers',
      'suit',
      'suits',
    };
    return complex.contains(category);
  }

  int _recommendedFitConfidence(Product product, {required String userType}) {
    final base = userType == 'new' ? 74 : 88;
    final adjusted = _isComplexFitProduct(product) ? base - 12 : base;
    return adjusted.clamp(55, 98);
  }

  Future<void> _handleBuyNowTap(Product product) async {
    await _trackExperienceEvent(
      'cta_click',
      cta: 'BUY_NOW',
      metadata: {'decisionType': _ctaDecisionType},
    );
    if (!mounted) {
      return;
    }
    final selectedSize = (_selectedSize ?? '').trim();
    if (selectedSize.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select your size first to continue.')),
        );
      }
      return;
    }

    if (_supportsTryAtHomeMode) {
      final added = await _addToCartWithDeliveryValidation(product, selectedSize);
      if (!added) {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} added to your bag.')),
        );
        Navigator.pushNamed(context, '/cart');
      }
      return;
    }

    if (!_supportsCourierDeliveryMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Currently unavailable for your location.'),
          ),
        );
      }
      return;
    }

    await _handleCourierBuyNowTap(product, selectedSize);
  }

  Future<void> _handleCourierBuyNowTap(
    Product product,
    String selectedSize,
  ) async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Courier Buy Now',
    );
    if (!allowed || !mounted) {
      return;
    }

    final added = await _addToCartWithDeliveryValidation(product, selectedSize);
    if (!added) {
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
      );
    }
  }

  Future<bool> _showMixedDeliveryDialog() async {
    if (!mounted) {
      return false;
    }
    await showDialog<void>(
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
    return true;
  }

  Future<bool> _wouldMixCartDeliveryModes() async {
    final cart = context.read<CartProvider>();
    final address = _serviceabilityAddressSnapshot();
    if (cart.items.isEmpty || address == null || _serviceability == null) {
      return false;
    }
    final currentMode = _serviceability!.deliveryMode;
    final firstProduct = cart.items.first.product;
    final firstItemServiceability = await _deliveryService.getServiceability(
      product: firstProduct,
      address: address,
    );
    if (!firstItemServiceability.isDeliverable) {
      return false;
    }
    return firstItemServiceability.deliveryMode != currentMode;
  }

  Future<bool> _addToCartWithDeliveryValidation(
    Product product,
    String selectedSize,
  ) async {
    final cart = context.read<CartProvider>();
    if (await _wouldMixCartDeliveryModes()) {
      await _showMixedDeliveryDialog();
      return false;
    }
    final result = cart.addToCart(product, selectedSize);
    if (result == CartAddResult.storeConflict) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your bag already contains products from another store.',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _handleNotifyMeTap(Product product) async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Notify Me',
    );
    if (!allowed || !mounted) {
      return;
    }
    try {
      final currentUser = _currentUser();
      if (currentUser == null) {
        return;
      }
      await _db.notifyStockAvailability(
        user: currentUser,
        product: product,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock alert enabled for ${product.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not enable stock alerts. Please try again.'),
        ),
      );
    }
  }

  Future<void> _handleAddToCartTap(Product product) async {
    await _trackExperienceEvent(
      'cta_click',
      cta: 'ADD_TO_CART',
      metadata: {'decisionType': _ctaDecisionType},
    );
    if (!mounted) {
      return;
    }
    final selectedSize = (_selectedSize ?? '').trim();
    if (selectedSize.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select your size first to continue.')),
        );
      }
      return;
    }

    final added = await _addToCartWithDeliveryValidation(product, selectedSize);
    if (!added) {
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to your bag.')),
      );
    }
  }

  Future<void> _handleTryHomeTap(Product product) async {

    await _trackExperienceEvent(
      'cta_click',
      cta: 'TRY_HOME',
      metadata: {'decisionType': _ctaDecisionType},
    );
    await _openPerfectFitExperience(product);
  }

  String _bottomLeftCtaLabel() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.error) {
      return 'Retry';
    }
    if (_isProductInStock) {
      if (AppConfig.enableLocalRiderDelivery && _canTryAtHome) {
        return 'Try At Home';
      }
      return 'Add to Cart';
    }
    return 'Notify Me';
  }

  String _bottomRightCtaLabel() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.error) {
      return 'Change Delivery Address';
    }
    if (_isProductInStock) {
      if (AppConfig.enableLocalRiderDelivery && _canTryAtHome) {
        return 'Get It Today';
      }
      return 'Buy Now';
    }
    return 'Check Other Locations';
  }

  VoidCallback? _bottomLeftCtaAction(Product product) {
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.loading) {
      return null;
    }
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.error) {
      return () {
        HapticFeedback.lightImpact();
        unawaited(_refreshServiceability(force: true));
      };
    }
    if (_isProductInStock) {
      if (AppConfig.enableLocalRiderDelivery && _canTryAtHome) {
        return () {
          HapticFeedback.lightImpact();
          _handleTryHomeTap(product);
        };
      }
      return () {
        HapticFeedback.lightImpact();
        _handleAddToCartTap(product);
      };
    }
    return () {
      HapticFeedback.lightImpact();
      _handleNotifyMeTap(product);
    };
  }

  VoidCallback? _bottomRightCtaAction(Product product) {
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.loading) {
      return null;
    }
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.error) {
      return () {
        HapticFeedback.lightImpact();
        unawaited(_refreshServiceability(force: true));
      };
    }
    if (_isProductInStock) {
      return () {
        HapticFeedback.lightImpact();
        _handleBuyNowTap(product);
      };
    }
    return () {
      HapticFeedback.lightImpact();
      _openDeliveryAddressSheet();
    };
  }

  Future<void> _openPerfectFitExperience(Product product) async {
    unawaited(_trackExperienceEvent('trial_request', cta: 'TRY_HOME'));
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Add to Trial Cart',
      trigger: AuthPromptTrigger.tryOn,
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

    final size = (_selectedSize ?? 'M').trim();

    try {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TbybProductSelectionScreen(
            initialProduct: product,
            initialSize: size,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString()),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _openTrialFeedback(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TrialFitFeedbackSheet(
        product: product,
        onCustomTailoringTap: () {
          Navigator.of(sheetContext).pop();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiStylistScreen()),
          );
        },
      ),
    );
  }

  Future<void> _openLiveTryOn(Product product, Color accentColor) async {
    MediaPipeTryOnPayload? payload;
    var usingCompatibilityMode = false;
    final localProductModelUrl = _normalizeCloudinaryModelUrl(
      product.model3d?.toString().trim() ?? '',
    );
    if (_backendCommerce.isConfigured) {
      try {
        final metadata = await _backendCommerce.getTryOnProductMetadata(
          product.id,
        );
        if (!mounted) return;
        payload = _buildMediaPipePayload(metadata);
        usingCompatibilityMode = !_hasUsableGarmentAsset(metadata);
      } catch (_) {
        usingCompatibilityMode = true;
      }
    } else {
      usingCompatibilityMode = true;
    }

    payload ??= _buildCompatibilityMediaPipePayload(product);
    if (payload.model3dUrl.trim().isEmpty && localProductModelUrl.isNotEmpty) {
      payload = payload.copyWith(
        model3dUrl: localProductModelUrl,
        overlayAssetUrl: payload.overlayAssetUrl.trim().isNotEmpty
            ? payload.overlayAssetUrl
            : (product.arAsset['processedImage']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? product.arAsset['processedImage'].toString().trim()
                  : product.arAsset['transparentImage']?.toString().trim() ??
                        ''),
      );
    }
    if (!mounted) return;
    if (usingCompatibilityMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Opening Try Live in compatibility mode for this product.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbianzoArScreen(
          payload: payload!,
          onError: (message) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
        ),
      ),
    );
  }

  MediaPipeTryOnPayload _buildMediaPipePayload(
    ArTryOnProductMetadata metadata,
  ) {
    var resolvedModelUrl = _resolveModelUrl(metadata);
    var resolvedBundleUrl = _resolveBundleUrl(metadata);
    if (_looksLikeModelUrl(resolvedBundleUrl)) {
      if (resolvedModelUrl.isEmpty) {
        resolvedModelUrl = resolvedBundleUrl;
      }
      resolvedBundleUrl = '';
    }
    final resolvedRigProfile = _resolveRigProfile(metadata);
    final resolvedMaterialProfile = _resolveMaterialProfile(metadata);
    final garmentConfig = _mergeArEditorIntoGarmentConfig(
      metadata.garmentConfig,
      metadata.arAsset,
    );
    return MediaPipeTryOnPayload(
      productId: metadata.id,
      name: metadata.name,
      category: metadata.category,
      templateId: metadata.templateId,
      template: metadata.templateData,
      garmentConfig: garmentConfig,
      alignmentConfig: metadata.alignmentConfig,
      model3dUrl: resolvedModelUrl,
      assetBundleUrl: resolvedBundleUrl,
      rigProfile: resolvedRigProfile,
      materialProfile: resolvedMaterialProfile,
      overlayAssetUrl: metadata.overlayAssetUrl,
      measurements: const <String, double>{},
    );
  }

  bool _hasUsableGarmentAsset(ArTryOnProductMetadata metadata) {
    return _resolveBundleUrl(metadata).isNotEmpty ||
        _resolveModelUrl(metadata).isNotEmpty;
  }

  MediaPipeTryOnPayload _buildCompatibilityMediaPipePayload(Product product) {
    final model3d = _normalizeCloudinaryModelUrl(
      _firstNonBlankString(<Object?>[
        product.model3d,
        product.arAsset['model3d'],
        product.arAsset['model3dUrl'],
        product.arAsset['modelUrl'],
        product.attributeText('model3d'),
        product.attributeText('model3dUrl'),
      ]),
    );
    final overlayAssetUrl = product.arAsset.isNotEmpty
        ? (product.arAsset['processedImage']?.toString().trim().isNotEmpty ==
                  true
              ? product.arAsset['processedImage'].toString().trim()
              : product.arAsset['transparentImage']?.toString().trim() ?? '')
        : '';
    final garmentConfig = _mergeArEditorIntoGarmentConfig(
      const <String, dynamic>{},
      product.arAsset,
    );
    return MediaPipeTryOnPayload(
      productId: product.id,
      name: product.name,
      category: product.category.isEmpty ? 'shirt' : product.category,
      templateId: 'compat_template',
      template: const <String, dynamic>{},
      garmentConfig: garmentConfig,
      alignmentConfig: const <String, dynamic>{},
      model3dUrl: model3d,
      assetBundleUrl: '',
      rigProfile: '',
      materialProfile: '',
      overlayAssetUrl: overlayAssetUrl,
      measurements: const <String, double>{},
    );
  }

  Map<String, dynamic> _mergeArEditorIntoGarmentConfig(
    Map<String, dynamic> garmentConfig,
    Map<String, dynamic> arAsset,
  ) {
    final merged = Map<String, dynamic>.from(garmentConfig);
    final editor = arAsset['editor'];
    final anchors = arAsset['anchors'];
    if (editor is Map && !merged.containsKey('editor')) {
      merged['editor'] = Map<String, dynamic>.from(editor);
    }
    if (anchors is Map && !merged.containsKey('anchors')) {
      merged['anchors'] = Map<String, dynamic>.from(anchors);
    }
    return merged;
  }

  String _resolveModelUrl(ArTryOnProductMetadata metadata) {
    final resolved = _firstNonBlankString(<Object?>[
      metadata.model3dUrl,
      metadata.arAsset['model3d'],
      metadata.arAsset['model3dUrl'],
      metadata.arAsset['modelUrl'],
      metadata.arAsset['glbUrl'],
      metadata.arAsset['gltfUrl'],
      metadata.templateData['model3d'],
      metadata.templateData['model3dUrl'],
      metadata.garmentConfig['model3d'],
      metadata.garmentConfig['model3dUrl'],
      metadata.lodModels['lod0'],
      metadata.lodModels['high'],
      metadata.lodModels['medium'],
      metadata.lodModels['default'],
      _mapValue(metadata.templateData['modelUrls'], 'lod0'),
      _mapValue(metadata.templateData['modelUrls'], 'glb'),
      _mapValue(metadata.templateData['modelUrls'], 'gltf'),
      _mapValue(metadata.templateData['modelUrls'], 'default'),
      _mapValue(metadata.garmentConfig['modelUrls'], 'lod0'),
      _mapValue(metadata.garmentConfig['modelUrls'], 'glb'),
      _mapValue(metadata.garmentConfig['modelUrls'], 'gltf'),
      _mapValue(metadata.garmentConfig['modelUrls'], 'default'),
    ]);
    return _normalizeCloudinaryModelUrl(resolved);
  }

  String _resolveBundleUrl(ArTryOnProductMetadata metadata) {
    final bundle = _firstNonBlankString(<Object?>[
      metadata.assetBundleUrl,
      metadata.arAsset['assetBundleUrl'],
      metadata.arAsset['assetBundleUrl'],
      metadata.arAsset['bundleUrl'],
      _mapValue(metadata.templateData['runtimeProfile'], 'assetBundleUrl'),
      _mapValue(metadata.templateData['runtimeProfile'], 'bundleUrl'),
      _mapValue(metadata.templateData['runtimeProfile'], 'androidBundleUrl'),
      _mapValue(metadata.garmentConfig['runtimeProfile'], 'assetBundleUrl'),
      _mapValue(metadata.garmentConfig['runtimeProfile'], 'bundleUrl'),
      _mapValue(metadata.garmentConfig['runtimeProfile'], 'androidBundleUrl'),
    ]);
    return _looksLikeModelUrl(bundle) ? '' : bundle;
  }

  String _resolveRigProfile(ArTryOnProductMetadata metadata) {
    return _firstNonBlankString(<Object?>[
      metadata.rigProfile,
      metadata.arAsset['rigProfile'],
      metadata.templateData['rigProfile'],
      _mapValue(metadata.templateData['runtimeProfile'], 'rigProfile'),
      metadata.garmentConfig['rigProfile'],
    ]);
  }

  String _resolveMaterialProfile(ArTryOnProductMetadata metadata) {
    return _firstNonBlankString(<Object?>[
      metadata.materialProfile,
      metadata.arAsset['materialProfile'],
      metadata.templateData['materialProfile'],
      _mapValue(metadata.templateData['runtimeProfile'], 'materialProfile'),
      metadata.garmentConfig['materialProfile'],
      metadata.templateData['defaultMaterialProfile'],
    ]);
  }

  String _normalizeCloudinaryModelUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('load/') &&
        (lower.endsWith('.glb') || lower.endsWith('.gltf'))) {
      return _normalizeCloudinaryModelUrl(
        'https://res.cloudinary.com/dsgi8awyo/image/upload/$trimmed',
      );
    }
    if (lower.startsWith('res.cloudinary.com/')) {
      return _normalizeCloudinaryModelUrl('https://$trimmed');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.host.contains('res.cloudinary.com')) {
      return trimmed;
    }
    if (!(trimmed.toLowerCase().endsWith('.glb') ||
        trimmed.toLowerCase().endsWith('.gltf'))) {
      return trimmed;
    }
    if (trimmed.contains('/raw/upload/')) {
      return trimmed;
    }
    return trimmed.replaceFirst('/image/upload/', '/raw/upload/');
  }

  Object? _mapValue(Object? source, String key) {
    if (source is Map) {
      return source[key];
    }
    return null;
  }

  String _firstNonBlankString(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  bool _looksLikeModelUrl(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.endsWith('.glb') ||
        normalized.endsWith('.gltf') ||
        normalized.endsWith('.fbx') ||
        normalized.endsWith('.obj') ||
        normalized.endsWith('.usdz');
  }

  Widget _buildHeroSliver(
    BuildContext context,
    Product product,
    List<String> images,
    _DetailPricing pricing,
    String deliverySummary,
    String suggestedSize,
    bool isWishlisted,
    bool isWishlistPending,
    WishlistProvider wishlist,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final heroHeight = (mediaQuery.size.height * 0.5).clamp(360.0, 475.0);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: GestureDetector(
                    key: ValueKey(
                      '${_selectedVariant.variantId}-$_selectedColorIndex-${images.join("|")}',
                    ),
                    onTap: _openGallery,
                    onLongPress: _openGallery,
                    child: PageView.builder(
                      controller: _imageController,
                      itemCount: images.length,
                      onPageChanged: (value) {
                        setState(() => _imageIndex = value);
                      },
                      itemBuilder: (context, index) => Hero(
                        tag: _heroTagFor(product, index),
                        child: AbzioNetworkImage(
                          imageUrl: images[index],
                          fallbackLabel: product.name,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _imageIndex == dotIndex ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _imageIndex == dotIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedTopHeader(
    BuildContext context,
    Product product,
    bool isWishlisted,
    bool isWishlistPending,
    WishlistProvider wishlist,
  ) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          child: Row(
            children: [
              _HeroIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
                color: const Color(0xFF1A1A1A),
              ),
              const SizedBox(width: 6),
              Expanded(child: _buildHeaderSearchBar(context, true)),
              const SizedBox(width: 8),
              AnimatedWishlistButton(
                isSelected: isWishlisted,
                isLoading: isWishlistPending,
                usePremiumIntentAnimation: true,
                size: 38,
                iconSize: 18,
                backgroundColor: Colors.transparent,
                selectedColor: const Color(0xFFC8A44D),
                unselectedColor: const Color(0xFF1A1A1A),
                onTap: () async {
                  await _toggleWishlistWithAuth(wishlist, product);
                },
              ),
              const SizedBox(width: 2),
              AnimatedBuilder(
                animation: _cartPulseScale,
                builder: (context, child) =>
                    Transform.scale(scale: _cartPulseScale.value, child: child),
                child: _HeroIconButton(
                  key: _cartIconKey,
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => Navigator.pushNamed(context, '/cart'),
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSearchBar(BuildContext context, bool isCollapsed) {
    final bg = isCollapsed ? const Color(0xFFF7F2E8) : const Color(0xFFFCFBF8);
    final fg = isCollapsed ? const Color(0xFF4A4336) : const Color(0xFF3A3328);
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8DDCC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search in Abianzo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSummarySection(
    BuildContext context,
    Product product,
    _DetailPricing pricing,
    String? suggestedSize,
  ) {
    final brand = product.brand.trim().isNotEmpty
        ? product.brand.trim()
        : (product.store?.name ?? product.category.trim());
    final match = _decisionFitConfidence.clamp(55, 99);
    final stockStatus = _stockStatusLabel(_activeVariantStock);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAE1D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            brand.isNotEmpty ? brand : 'ABIANZO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6F675A),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              height: 1.12,
              color: const Color(0xFF121212),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _buildPriceBlock(context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestedSize == null
                      ? 'Recommended Size: ${_selectedSize ?? 'M'} ($match% Match)'
                      : 'Recommended Size: $suggestedSize ($match% Match)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF191919),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                stockStatus,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7A7368),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelectorSection(
    BuildContext context,
    Product product,
    String? suggestedSize,
  ) {
    final displaySizes = _activeSizes;
    final sizeStocks = _activeSizeStocks;
    if (displaySizes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F1EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Size',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestedSize == null
                        ? 'Recommended Size: ${_selectedSize ?? 'M'} (${_decisionFitConfidence.clamp(55, 99)}% Match)'
                        : 'Recommended Size: $suggestedSize (${_decisionFitConfidence.clamp(55, 99)}% Match)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6C6559),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  if (context.read<AuthProvider>().requiresProfileSetup) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please complete your profile first.'),
                      ),
                    );
                    Navigator.pushNamed(context, '/profile-completion');
                    return;
                  }
                  final recommendation =
                      await Navigator.push<SizeRecommendationOutcome>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SizeRecommendationScreen(product: product),
                        ),
                      );
                  if (!context.mounted || recommendation == null) {
                    return;
                  }
                  setState(() {
                    _selectedSize = recommendation.recommendedSize;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Recommended size ${recommendation.recommendedSize} selected.',
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC8A96A),
                ),
                child: const Text('Size guide'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: displaySizes.map((size) {
              final selected = _selectedSize == size;
              final stock =
                  sizeStocks[size.toUpperCase()] ?? _activeVariantStock;
              final soldOut = stock <= 0;
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 62),
                child: TapScale(
                  scale: 0.98,
                  onTap: soldOut
                      ? null
                      : () => setState(() => _selectedSize = size),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: soldOut
                          ? const Color(0xFFF5F5F5)
                          : selected
                          ? const Color(0xFF16120D)
                          : const Color(0xFFFCFBF8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: soldOut
                            ? const Color(0xFFE0E0E0)
                            : selected
                            ? const Color(0xFF16120D)
                            : const Color(0xFFE5DBCC),
                      ),
                    ),
                    child: Text(
                      size,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: soldOut
                            ? const Color(0xFF9F9F9F)
                            : selected
                            ? Colors.white
                            : const Color(0xFF171717),
                        fontWeight: FontWeight.w700,
                        decoration: soldOut ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(
    BuildContext context,
  ) {
    final serviceability = _serviceability;
    final deliveryLine = _serviceabilityDetails();
    final eta = _serviceabilityEtaLabel();
    final headline = _serviceabilityHeadline();
    final buttonLabel = switch (_deliveryAvailabilityState) {
      _DeliveryAvailabilityState.error => 'Retry',
      _DeliveryAvailabilityState.noAddress => 'Set Location',
      _DeliveryAvailabilityState.loading => 'Checking',
      _ => 'Change',
    };
    final arrival = serviceability?.isDeliverable == true &&
            _isSameDayDeliveryAvailable
        ? 'Today'
        : _deliveryAvailabilityState == _DeliveryAvailabilityState.noAddress
        ? 'Choose location'
        : _deliveryAvailabilityState == _DeliveryAvailabilityState.error
        ? 'Tap Retry'
        : eta;
    return InkWell(
      onTap: _openDeliveryAddressSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F1EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: Color(0xFFC8A96A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF121212),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _deliveryAvailabilityState ==
                          _DeliveryAvailabilityState.error
                      ? () => unawaited(_refreshServiceability(force: true))
                      : _openDeliveryAddressSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC8A96A),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(buttonLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    deliveryLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF665F53),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  eta,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF121212),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Estimated arrival: $arrival',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A7367),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInformationSection(BuildContext context, Product product) {
    final store = product.store;
    final boutique = Map<String, dynamic>.from(product.boutiqueInfo);
    final storeNameFallback = store?.name ?? '';
    final boutiqueName = boutique['name']?.toString() ?? '';
    final storeName = boutiqueName.trim().isNotEmpty == true
        ? boutiqueName.trim()
        : (storeNameFallback.trim().isNotEmpty
              ? storeNameFallback.trim()
              : product.brand.trim());
    final verified = boutique['verified'] == true || store?.isApproved == true;
    final logoFallback = store?.logoUrl ?? '';
    final boutiqueLogo = boutique['logoUrl']?.toString() ?? '';
    final logoUrl = boutiqueLogo.trim().isNotEmpty == true
        ? boutiqueLogo.trim()
        : logoFallback;
    final rating =
        (boutique['rating'] as num?)?.toDouble() ??
        store?.rating ??
        product.rating;
    final distanceLabel = _distanceOverlayLabel(product);

    return InkWell(
      onTap: () {
        if (store != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F1EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFF7F2E8),
              child: ClipOval(
                child: logoUrl.isNotEmpty
                    ? AbzioNetworkImage(
                        imageUrl: logoUrl,
                        fallbackLabel: storeName,
                      )
                    : const Icon(
                        Icons.storefront_outlined,
                        color: Color(0xFFC8A96A),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          storeName.isNotEmpty ? storeName : 'ABIANZO Boutique',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFFC8A96A),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    distanceLabel.isNotEmpty
                        ? '⭐ ${rating.toStringAsFixed(1)} • $distanceLabel'
                        : '⭐ ${rating.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7D756A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC8A96A)),
          ],
        ),
      ),
    );
  }

  String _distanceOverlayLabel(Product product) {
    final label = product.distanceLabel?.trim() ?? '';
    if (label.isNotEmpty) {
      return label;
    }
    final distanceKm = product.distanceKm;
    if (distanceKm == null) {
      return '';
    }
    if (distanceKm < 1) {
      return 'Nearby';
    }
    if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    return '${distanceKm.round()} km';
  }

  Widget _buildStyleServicesSection(
    BuildContext context,
    Product product,
    Color accentColor,
  ) {
    final tryOnEnabled = product.tryOnAvailable;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F1EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Services',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactServiceButton(
                  context,
                  icon: Icons.view_in_ar_rounded,
                  label: 'Try On',
                  enabled: tryOnEnabled,
                  onTap: tryOnEnabled
                      ? () => _openLiveTryOn(product, accentColor)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactServiceButton(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  label: 'Ask AI',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiStylistScreen(
                        product: product,
                        initialPrompt: 'How should I style this?',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactServiceButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return TapScale(
      scale: 0.985,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F1EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFF7F4EC)
                    : const Color(0xFFF2F1ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: enabled
                    ? const Color(0xFF141414)
                    : const Color(0xFF8F8A80),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: enabled
                      ? const Color(0xFF111111)
                      : const Color(0xFF8F8A80),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: enabled
                  ? const Color(0xFF8E8679)
                  : const Color(0xFFB7B2A9),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInfoCard(
    BuildContext context,
    Product product,
    _DetailPricing pricing,
    List<String> images,
    String description,
    String? suggestedSize,
    String deliverySummary,
    String estimatedDelivery,
    String sameDayCity,
    int urgencyHoursLeft,
    String ctaDecisionType,
    Color accentColor,
  ) {
    final shortDescription = description.trim().isNotEmpty
        ? description.trim()
        : 'Premium finish with a refined fit and a clean, elevated silhouette.';
    final _ = images;
    final displaySizes = _activeSizes;
    final sizeStocks = _activeSizeStocks;
    final stockStatus = _stockStatusLabel(_activeVariantStock);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((product.brand.trim().isNotEmpty ||
            product.category.trim().isNotEmpty))
          Text(
            product.brand.trim().isNotEmpty
                ? product.brand.trim()
                : product.category.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF777777),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        const SizedBox(height: 5),
        Text(
          product.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 24,
            height: 1.12,
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _buildRatingSocialProof(context),
        const SizedBox(height: 8),
        _buildBoutiqueSection(context),
        const SizedBox(height: 10),
        _buildPriceBlock(context),
        const SizedBox(height: 12),
        if (_hasMultipleColors) _buildColorSelector(context, product),
        if (_hasMultipleColors) const SizedBox(height: 12),
        _buildHighlights(context),
        if (_product.highlights.isNotEmpty) const SizedBox(height: 12),
        _buildDeliveryConfidenceCardV2(context),
        const SizedBox(height: 14),
        _buildWhyShopThisProductSection(context),
        const SizedBox(height: 14),
        _buildSpecificationsSection(context),
        if (_product.specifications.isNotEmpty) const SizedBox(height: 14),
        _buildSocialProofSection(context),
        if (_product.socialProof.isNotEmpty) const SizedBox(height: 14),
        Text(
          'Size + Fit',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displaySizes.map((size) {
            final selected = _selectedSize == size;
            final stock = sizeStocks[size.toUpperCase()] ?? _activeVariantStock;
            final soldOut = stock <= 0;
            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60),
              child: TapScale(
                scale: 0.98,
                onTap: soldOut
                    ? null
                    : () => setState(() => _selectedSize = size),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: soldOut
                        ? const Color(0xFFF7F7F7)
                        : selected
                        ? const Color(0xFF16120D)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: soldOut
                          ? const Color(0xFFE1E1E1)
                          : selected
                          ? const Color(0xFF16120D)
                          : const Color(0xFFE4DDD0),
                      width: selected ? 1.2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    size,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: soldOut
                          ? const Color(0xFF9B9B9B)
                          : selected
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      decoration: soldOut ? TextDecoration.lineThrough : null,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (suggestedSize != null) ...[
          const SizedBox(height: 8),
          Text(
            'Recommended for you: $suggestedSize (${_decisionFitConfidence.clamp(55, 99)}% match)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stockStatus,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A8479),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _buildWhyShopThisProductSection(context),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Style Services',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              _buildExperienceRow(
                icon: Icons.view_in_ar_rounded,
                title: 'Try Live (AR)',
                onTap: () => _openLiveTryOn(product, accentColor),
              ),
              const SizedBox(height: 9),
              _buildExperienceRow(
                icon: Icons.auto_awesome_rounded,
                title: 'Ask AI Stylist',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiStylistScreen(
                      product: product,
                      initialPrompt: 'How should I style this?',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              _buildExperienceRow(
                icon: Icons.checkroom_rounded,
                title: 'Create Outfit',
                onTap: () => _openLiveTryOn(product, accentColor),
              ),
              const SizedBox(height: 9),
              _buildExperienceRow(
                icon: Icons.auto_awesome_mosaic_rounded,
                title: 'Similar Styles',
                onTap: () => _openLiveTryOn(product, accentColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildProductStorySection(context, shortDescription),
      ],
    );
  }

  Widget _buildExperienceRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return TapScale(
      scale: 0.98,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E0D6)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF111111)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF888888),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(BuildContext context, Product product) {
    if (!_hasMultipleColors) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Color: $_selectedColorName',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _variants.length,
            separatorBuilder: (context, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final variant = _variants[index];
              final selected = index == _selectedColorIndex;
              final variantImage = variant.thumbnail.isNotEmpty
                  ? variant.thumbnail
                  : (variant.images.isNotEmpty
                        ? variant.images.first
                        : _activeImages.first);
              return TapScale(
                scale: 0.97,
                onTap: () => _selectColorVariant(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 82,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFC8A96A)
                          : const Color(0xFFE6DDCE),
                      width: selected ? 1.3 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFC8A96A,
                              ).withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: AbzioNetworkImage(
                            imageUrl: variantImage,
                            fallbackLabel: variant.colorName.isNotEmpty
                                ? variant.colorName
                                : variant.name,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        variant.colorName.isNotEmpty
                            ? variant.colorName
                            : variant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? const Color(0xFFC8A96A)
                              : const Color(0xFF111111),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBoutiqueSection(BuildContext context) {
    final store = _product.store;
    final info = Map<String, dynamic>.from(_product.boutiqueInfo);
    final name = info['name']?.toString().trim().isNotEmpty == true
        ? info['name'].toString().trim()
        : (store?.name ?? _product.brand);
    final logoUrl = info['logoUrl']?.toString().trim().isNotEmpty == true
        ? info['logoUrl'].toString().trim()
        : (store?.logoUrl ?? '');
    final verified = info['verified'] == true || store?.isApproved == true;
    final rating =
        (info['rating'] as num?)?.toDouble() ??
        store?.rating ??
        _product.rating;
    final distanceLabel = _distanceOverlayLabel(_product);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F1EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: logoUrl.isNotEmpty
                  ? AbzioNetworkImage(imageUrl: logoUrl, fallbackLabel: name)
                  : const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFFC8A96A),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF111111),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFFC8A96A),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  distanceLabel.isNotEmpty
                      ? '${rating.toStringAsFixed(1)} Rating • $distanceLabel'
                      : '${rating.toStringAsFixed(1)} Rating',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Luxury boutique in your area',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7D756A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFC8A96A)),
        ],
      ),
    );
  }

  Widget _buildRatingSocialProof(BuildContext context) {
    final reviewCount = _selectedVariantReviewCount > 0
        ? _selectedVariantReviewCount
        : (_product.reviewCount > 0 ? _product.reviewCount : _reviews.length);
    final rating = _selectedVariantRating;
    final purchases = _product.purchaseCount;
    final isBestseller = purchases >= 50 || reviewCount >= 30;
    if (reviewCount <= 0) {
      return Row(
        children: [
          Text(
            'New Arrival',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFC8A96A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Be First To Review',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '⭐ ${rating.toStringAsFixed(1)} ($reviewCount Reviews)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '• ${NumberFormat.compact(locale: 'en_IN').format(purchases)} purchases',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF666666),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isBestseller)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE6C57D)),
            ),
            child: Text(
              'Bestseller',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A6328),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHighlights(BuildContext context) {
    final highlights = _product.highlights
        .where((item) => item.trim().isNotEmpty)
        .toList();
    if (highlights.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: highlights
          .take(6)
          .map(
            (highlight) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F4EC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE8D8B7)),
              ),
              child: Text(
                highlight,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4A3A1D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPriceBlock(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final current = _activePrice;
    final original = _activeOriginalPrice;
    final discount = original != null && original > current
        ? (((original - current) / original) * 100).round()
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatter.format(current),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1D8B4D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1D8B4D).withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Free delivery over ₹999',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D8B4D),
                ),
              ),
            ),
          ],
        ),
        if (original != null && original > current) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                formatter.format(original),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9B9B9B),
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$discount% OFF',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A6328),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Inclusive of all taxes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF7C7568),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryConfidenceCardV2(
    BuildContext context,
  ) {
    final deliverySubtext = _serviceabilityDetails();
    final urgencyLabel = _serviceabilityEtaLabel();
    final buttonLabel = switch (_deliveryAvailabilityState) {
      _DeliveryAvailabilityState.error => 'Retry',
      _DeliveryAvailabilityState.noAddress => 'Set Location',
      _DeliveryAvailabilityState.loading => 'Checking',
      _ => 'Change',
    };
    return InkWell(
      onTap: _openDeliveryAddressSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F1EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: Color(0xFFC9A86A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _serviceabilityHeadline(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _deliveryAvailabilityState ==
                          _DeliveryAvailabilityState.error
                      ? () => unawaited(_refreshServiceability(force: true))
                      : _openDeliveryAddressSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC9A86A),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(buttonLabel),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              deliverySubtext,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6E675B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              urgencyLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _ValueChip(label: 'Backend serviceability'),
                _ValueChip(label: 'Selected address'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhyShopThisProductSection(BuildContext context) {
    final verified =
        _product.store?.isApproved == true ||
        _product.boutiqueInfo['verified'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why Shop This Product',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ValueChip(
              label: verified ? 'Verified Boutique' : 'Boutique Partner',
            ),
            const _ValueChip(label: 'Same-Day Delivery Available'),
            const _ValueChip(label: 'AI Size Recommendation'),
            const _ValueChip(label: 'Try At Home Available'),
            const _ValueChip(label: 'Delivered From Nearby Boutique'),
            const _ValueChip(label: 'Secure Payment'),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecificationsSection(BuildContext context) {
    final specs = Map<String, String>.from(_product.specifications);
    if (specs.isEmpty) {
      return const SizedBox.shrink();
    }
    final orderedKeys = [
      'Material',
      'Fabric',
      'Fit',
      'Pattern',
      'Sleeve Type',
      'Occasion',
      'Care Instructions',
      'Country of Origin',
      ...specs.keys.where(
        (key) => ![
          'Material',
          'Fabric',
          'Fit',
          'Pattern',
          'Sleeve Type',
          'Occasion',
          'Care Instructions',
          'Country of Origin',
        ].contains(key),
      ),
    ].where(specs.containsKey).toList();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'Product Specifications',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF111111),
          fontWeight: FontWeight.w700,
        ),
      ),
      children: orderedKeys
          .map(
            (key) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF888888),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      specs[key] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSocialProofSection(BuildContext context) {
    final social = Map<String, dynamic>.from(_product.socialProof);
    final viewers = (social['viewersToday'] as num?)?.toInt() ?? 0;
    final orders = (social['ordersThisWeek'] as num?)?.toInt() ?? 0;
    final wishlists = (social['wishlistCount'] as num?)?.toInt() ?? 0;
    if (viewers == 0 && orders == 0 && wishlists == 0) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F1EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Social Proof',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _proofRow('🔥', '$viewers people viewed this today'),
          _proofRow('🛍', '$orders orders delivered this week'),
          _proofRow('❤️', 'Added to $wishlists wishlists'),
        ],
      ),
    );
  }

  Widget _buildProductStorySection(
    BuildContext context,
    String shortDescription,
  ) {
    final specs = Map<String, String>.from(_product.specifications);
    final materials = [
      if (specs['Material']?.trim().isNotEmpty == true)
        specs['Material']!.trim(),
      if (specs['Fabric']?.trim().isNotEmpty == true) specs['Fabric']!.trim(),
    ].join(' / ');
    final careInstructions =
        specs['Care Instructions']?.trim().isNotEmpty == true
        ? specs['Care Instructions']!.trim()
        : 'Treat gently, store clean, and follow the garment label for best longevity.';
    final sizeGuide = _activeSizes.isNotEmpty
        ? 'Available sizes: ${_activeSizes.join(', ')}. Choose your usual fit or follow the recommendation shown above.'
        : 'Use the recommended size shown above for the closest fit.';

    Widget buildTile({required String title, required String body}) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        dense: true,
        visualDensity: VisualDensity.compact,
        minTileHeight: 52,
        collapsedIconColor: const Color(0xFF888888),
        iconColor: const Color(0xFFC9A86A),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666666),
                height: 1.42,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Information',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        buildTile(title: 'Product Story', body: shortDescription),
        const Divider(height: 1),
        buildTile(
          title: 'Materials',
          body: materials.isNotEmpty
              ? materials
              : 'Premium fabric selected for a refined boutique finish.',
        ),
        const Divider(height: 1),
        buildTile(title: 'Care Instructions', body: careInstructions),
        const Divider(height: 1),
        buildTile(title: 'Size Guide', body: sizeGuide),
      ],
    );
  }

  Widget _proofRow(String icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteTheLookSection(BuildContext context) {
    if (_completeTheLook.isEmpty) {
      return const SizedBox.shrink();
    }
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete the Look',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 440,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _completeTheLook.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = _completeTheLook[index];
              final discount =
                  item.originalPrice != null && item.originalPrice! > item.price
                  ? (((item.originalPrice! - item.price) /
                                item.originalPrice!) *
                            100)
                        .round()
                  : 0;
              final hasDiscount = discount > 0;
              return Container(
                width: 185,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFC6A769).withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: AspectRatio(
                        aspectRatio: 4 / 5,
                        child: AbzioNetworkImage(
                          imageUrl: item.images.isNotEmpty
                              ? item.images.first
                              : '',
                          fallbackLabel: item.name,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.brand.trim().isNotEmpty
                                  ? item.brand.trim()
                                  : _product.brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6F675A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 40,
                              child: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111111),
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 44,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        formatter.format(item.price),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (hasDiscount)
                                        Expanded(
                                          child: Text(
                                            formatter.format(
                                              item.originalPrice,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Color(0xFF9A9A9A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasDiscount ? '$discount% OFF' : ' ',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 42,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _openLiveTryOn(
                                        item,
                                        const Color(0xFFC9A86A),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFFC9A86A),
                                        ),
                                        foregroundColor: const Color(
                                          0xFF111111,
                                        ),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Try On',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () {
                                        final selected = item.sizes.isNotEmpty
                                            ? item.sizes.first
                                            : 'M';
                                        unawaited(
                                          _addToCartWithDeliveryValidation(
                                            item,
                                            selected,
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${item.name} added to bag',
                                            ),
                                          ),
                                        );
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFC8A96A,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF111111,
                                        ),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Add',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(
    BuildContext context,
    AuthProvider auth,
    ReviewModel? myReview,
  ) {
    final averageRating = _selectedVariantRating;
    final totalReviews = _reviews.length;
    if (totalReviews == 0) {
      return const SizedBox.shrink();
    }
    final breakdown = List.generate(5, (index) {
      final star = 5 - index;
      final count = _reviews
          .where((review) => review.rating.round() == star)
          .length;
      return MapEntry(star, count);
    });
    final customerPhotos = _reviews
        .where(
          (review) => review.imagePath != null && review.imagePath!.isNotEmpty,
        )
        .take(4)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews & Ratings',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            TextButton(
              onPressed: () => _openReviewSheet(myReview),
              child: Text(
                myReview == null ? 'WRITE REVIEW' : 'EDIT YOUR REVIEW',
              ),
            ),
          ],
        ),
        ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF3F1EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${averageRating.toStringAsFixed(1)} / 5.0',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                ...breakdown.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 34, child: Text('${entry.key}★')),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: totalReviews == 0
                                  ? 0
                                  : entry.value / totalReviews,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF1E6D0),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFC8A96A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 28, child: Text('${entry.value}')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (customerPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Customer Photos',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: customerPhotos.length,
                separatorBuilder: (context, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final review = customerPhotos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: review.imagePath!.startsWith('http')
                          ? AbzioNetworkImage(
                              imageUrl: review.imagePath!,
                              fallbackLabel: review.userName,
                              fit: BoxFit.cover,
                            )
                          : localFileImage(
                              review.imagePath!,
                              fit: BoxFit.cover,
                              width: 76,
                              height: 76,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          ..._reviews.map(
            (review) => Container(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1EEE7))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          review.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMM').format(review.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: index < review.rating.round()
                            ? Colors.amber
                            : context.abzioBorder,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (review.verifiedPurchase)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E3C5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Verified Purchase',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (review.verifiedPurchase) const SizedBox(width: 8),
                      if (review.helpfulVotes > 0)
                        Text(
                          '${review.helpfulVotes} helpful votes',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF666666),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(review.comment),
                  if (review.imagePath != null &&
                      review.imagePath!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: review.imagePath!.startsWith('http')
                          ? SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: AbzioNetworkImage(
                                imageUrl: review.imagePath!,
                                fallbackLabel: 'REVIEW',
                              ),
                            )
                          : localFileImage(
                              review.imagePath!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ],
                  if (auth.user != null && review.userId == auth.user!.id)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _deleteReview(review),
                        child: const Text('DELETE'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context, Product product) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFCFBF8),
        border: Border(top: BorderSide(color: Color(0xFFE6DFD1), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _bottomLeftCtaAction(product),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC9A86A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: const Color(0xFF111111),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _bottomLeftCtaLabel(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _bottomRightCtaAction(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A86A),
                      foregroundColor: const Color(0xFF111111),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _bottomRightCtaLabel(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartFlightOverlay(Product product, List<String> images) {
    if (!_showCartFlight ||
        _cartFlightStart == null ||
        _cartFlightEnd == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _cartFlightController,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: _cartFlightSize.width,
            height: _cartFlightSize.height,
            child: AbzioNetworkImage(
              imageUrl: images.first,
              fallbackLabel: product.name,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final progress = _cartFlightController.value;
        final curved = Curves.easeInOutCubic.transform(progress);
        final current = Offset.lerp(_cartFlightStart, _cartFlightEnd, curved)!;
        final scale = lerpDouble(1, 0.28, curved)!;
        final opacity = lerpDouble(1, 0.0, Curves.easeIn.transform(progress))!;
        return Positioned(
          left: current.dx,
          top: current.dy,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedScreen(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final contentBottomSpacing = (width < 360 ? 184.0 : 144.0) + bottomInset;
    final auth = context.read<AuthProvider>();
    final product = _product;
    final images = _activeImages;
    final isWishlisted = context.select<WishlistProvider, bool>(
      (wishlist) => wishlist.isWishlisted(widget.product.id),
    );
    final isWishlistPending = context.select<WishlistProvider, bool>(
      (wishlist) => wishlist.isPending(widget.product.id),
    );
    final pricing = _pricing;
    final description = product.description.trim();
    final accentColor = const Color(0xFFC8A96A);
    final suggestedSize =
        _selectedSize ??
        (_activeSizes.contains('M')
            ? 'M'
            : (_activeSizes.isNotEmpty
                  ? _activeSizes[_activeSizes.length ~/ 2]
                  : null));
    final fixedHeaderHeight = MediaQuery.of(context).padding.top + 46;

    ReviewModel? myReview;
    for (final review in _reviews) {
      if (auth.user != null && review.userId == auth.user!.id) {
        myReview = review;
        break;
      }
    }

    return AbzioThemeScope.light(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handlePdpScrollNotification,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: fixedHeaderHeight),
                  ),
                  _buildHeroSliver(
                    context,
                    product,
                    images,
                    pricing,
                    _resolveDeliverySummary(),
                    suggestedSize ?? 'M',
                    isWishlisted,
                    isWishlistPending,
                    context.read<WishlistProvider>(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -14),
                            child: _buildPremiumSummarySection(
                              context,
                              product,
                              pricing,
                              suggestedSize,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStoreInformationSection(context, product),
                          const SizedBox(height: 16),
                          _buildColorSelector(context, product),
                          if (_hasMultipleColors) const SizedBox(height: 16),
                          _buildSizeSelectorSection(
                            context,
                            product,
                            suggestedSize,
                          ),
                          const SizedBox(height: 16),
                          _buildDeliverySection(
                            context,
                          ),
                          const SizedBox(height: 12),
                          _buildStyleServicesSection(
                            context,
                            product,
                            accentColor,
                          ),
                          const SizedBox(height: 12),
                          _buildProductStorySection(context, description),
                          if (_completeTheLook.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildCompleteTheLookSection(context),
                          ],
                          if (_reviews.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildReviewsSection(context, auth, myReview),
                          ],
                          SizedBox(height: contentBottomSpacing),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFixedTopHeader(
                context,
                product,
                isWishlisted,
                isWishlistPending,
                context.read<WishlistProvider>(),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: _isBottomBarVisible
                    ? _buildBottomActionBar(context, product)
                    : const SizedBox.shrink(),
              ),
            ),
            _buildCartFlightOverlay(product, images),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildFixedScreen(context);
  }

  /*
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final lookCardWidth = width < 380 ? 140.0 : 160.0;
    final auth = context.watch<AuthProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final product = _product;
    final images = product.images.isEmpty
        ? const ['https://via.placeholder.com/600x750']
        : product.images;
    final isWishlisted = wishlist.isWishlisted(widget.product.id);
    final isWishlistPending = wishlist.isPending(widget.product.id);
    final pricing = _pricing;
    final description = product.description.trim();
    final accentColor = _effectiveAccentColor(product, images);
    final suggestedSize = _selectedSize ?
        (product.sizes.contains('M')
            ? 'M'
            : (product.sizes.isNotEmpty
                ? product.sizes[product.sizes.length ~/ 2]
                : null));
    final deliveryAddress =
        auth.user == null
            ? 'Add your address for delivery updates'
            : [
                auth.user!.address.trim(),
                auth.user!.city.trim(),
              ].where((part) => part.isNotEmpty).join(', ').trim();
    ReviewModel? myReview;
    for (final review in _reviews) {
      if (auth.user != null && review.userId == auth.user!.id) {
        myReview = review;
        break;
      }
    }

    return AbzioThemeScope.light(
      child: Scaffold(
      backgroundColor: const Color(0xFFFAF8F3),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 352,
                  child: Stack(
                    children: [
                      GestureDetector(
                        key: _heroImageKey,
                        onTap: _openGallery,
                        onLongPress: _openGallery,
                        child: PageView.builder(
                          controller: _imageController,
                          onPageChanged: (value) => setState(() => _imageIndex = value),
                          itemCount: images.length,
                          itemBuilder: (context, index) => AbzioNetworkImage(
                            imageUrl: images[index],
                            fallbackLabel: product.name,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.12),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.36),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: SafeArea(
                          top: true,
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                _HeroIconButton(
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  onTap: () => Navigator.pop(context),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Text(
                                    '${_imageIndex + 1}/${images.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AnimatedWishlistButton(
                                  isSelected: isWishlisted,
                                  isLoading: isWishlistPending,
                                  usePremiumIntentAnimation: true,
                                  size: 42,
                                  iconSize: 20,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.88),
                                  unselectedColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  onTap: () async {
                                    await _toggleWishlistWithAuth(
                                      wishlist,
                                      product,
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                AnimatedBuilder(
                                  animation: _cartPulseScale,
                                  builder: (context, child) => Transform.scale(
                                    scale: _cartPulseScale.value,
                                    child: child,
                                  ),
                                  child: _HeroIconButton(
                                    key: _cartIconKey,
                                    icon: Icons.shopping_bag_outlined,
                                    onTap: () =>
                                        Navigator.pushNamed(context, '/cart'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 18,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (dotIndex) => AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: _imageIndex == dotIndex ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _imageIndex == dotIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.48),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      Text(
                        product.category.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AbzioTheme.accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(fontSize: 28, height: 1.1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5D8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_reviews.length} reviews',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: context.abzioSecondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAD9A2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: AbzioTheme.accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Premium packaging, fast delivery, and easy returns',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: context.abzioSecondaryText,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Colours & finishes',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final selected = _imageIndex == index;
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                setState(() => _imageIndex = index);
                                await _imageController.animateToPage(
                                  index,
                                  duration:
                                      const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                width: 68,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? AbzioTheme.accentColor
                                        : context.abzioBorder,
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: AbzioTheme.accentColor
                                                .withValues(alpha: 0.18),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AbzioNetworkImage(
                                    imageUrl: images[index],
                                    fallbackLabel: product.name,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select size',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          TextButton(
                            onPressed: () async {
                              if (context.read<AuthProvider>().requiresProfileSetup) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile first.')));
                                Navigator.pushNamed(context, '/profile-completion');
                                return;
                              }
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              final recommendation =
                                  await Navigator.push<
                                      SizeRecommendationOutcome>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SizeRecommendationScreen(
                                    product: product,
                                  ),
                                ),
                              );
                              if (!mounted || recommendation == null) {
                                return;
                              }
                              setState(() {
                                _selectedSize =
                                    recommendation.recommendedSize;
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Recommended size ${recommendation.recommendedSize} selected for this product.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Size Chart >'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: product.sizes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final size = product.sizes[index];
                            final selected = _selectedSize == size;
                            final soldOut = product.stock <= 0;
                            final lowStock =
                                product.isLimitedStock && !soldOut;
                            return InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: soldOut
                                  ? null
                                  : () => setState(
                                        () => _selectedSize = size,
                                      ),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: soldOut
                                      ? const Color(0xFFF1F1F1)
                                      : selected
                                      ? AbzioTheme.accentColor
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  border: Border.all(
                                    color: soldOut
                                        ? const Color(0xFFD9D9D9)
                                        : selected
                                        ? AbzioTheme.accentColor
                                        : context.abzioBorder,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: AbzioTheme.accentColor
                                                .withValues(alpha: 0.25),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      size,
                                      style: TextStyle(
                                        color: soldOut
                                            ? context.abzioSecondaryText
                                            : selected
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                        fontWeight: FontWeight.w700,
                                        decoration: soldOut
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pricing.currentLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: soldOut
                                            ? context.abzioSecondaryText
                                            : selected
                                                ? Colors.white
                                                    .withValues(alpha: 0.84)
                                                : context.abzioSecondaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (lowStock)
                                      Text(
                                        '${product.stock} left',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: selected
                                              ? Colors.white
                                                  .withValues(alpha: 0.92)
                                              : const Color(0xFFB54708),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F2E3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE7D39A),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAD9A2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.straighten_rounded,
                                color: AbzioTheme.accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestedSize == null
                                        ? 'Find your recommended size'
                                        : 'We suggest size $suggestedSize',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  TextButton(
                                    onPressed: () async {
                                      if (context.read<AuthProvider>().requiresProfileSetup) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile first.')));
                                        Navigator.pushNamed(context, '/profile-completion');
                                        return;
                                      }
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final recommendation =
                                          await Navigator.push<
                                              SizeRecommendationOutcome>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SizeRecommendationScreen(
                                            product: product,
                                          ),
                                        ),
                                      );
                                      if (!mounted ||
                                          recommendation == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedSize = recommendation
                                            .recommendedSize;
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Recommended size ${recommendation.recommendedSize} selected for this product.',
                                          ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    child: const Text('Why this size?'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.abzioBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F2E3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 18,
                                    color: AbzioTheme.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _serviceabilityHeadline(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            _serviceabilityDetails(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: context
                                                      .abzioSecondaryText,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                  onPressed: _openDeliveryAddressSheet,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AbzioTheme.accentColor,
                                  ),
                                  child: const Text('Change Address >'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _TrustBadge(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Genuine Product',
                                ),
                                _TrustBadge(
                                  icon: Icons.fact_check_outlined,
                                  label: 'Secure Payment',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AiStylistScreen(
                              product: product,
                              initialPrompt: 'How should I style this?',
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE6D6A3),
                            ),
                            color: const Color(0xFFFFFBF2),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: Color(0xFFC8A86B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ask AI Stylist',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AbzioTheme.accentColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _descriptionExpanded =
                                  !_descriptionExpanded,
                            ),
                            child: Text(
                              _descriptionExpanded
                                  ? 'Read less'
                                  : 'Read more',
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: Text(
                          description,
                          maxLines: _descriptionExpanded ? null : 3,
                          overflow: _descriptionExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.42),
                        ),
                      ),
                      const SizedBox(height: 22),
                            ],
                          ),
                        ),
                      if (_completeTheLook.isNotEmpty) ...[
                        Text(
                          'Complete the Look',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 214,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _completeTheLook.length,
                            itemBuilder: (context, index) {
                              final item = _completeTheLook[index];
                              return SizedBox(
                                width: lookCardWidth,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFE8DCC2)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius.vertical(
                                                  top: Radius.circular(18),
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  child: AbzioNetworkImage(
                                                    imageUrl: item.images.first,
                                                    fallbackLabel: item.name,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 10,
                                              right: 10,
                                              bottom: 10,
                                              child: SizedBox(
                                                height: 40,
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    final selected = item.sizes.first;
                                                    final added = await _addToCartWithDeliveryValidation(item, selected);
                                                    if (!added || !context.mounted) {
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('${item.name} added to your bag.')),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.white,
                                                    foregroundColor: Colors.black,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  child: const Text('Add'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _currencyFormatter.format(item.price),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reviews & Ratings', style: Theme.of(context).textTheme.labelMedium),
                          TextButton(
                            onPressed: () => _openReviewSheet(myReview),
                            child: Text(myReview == null ? 'WRITE REVIEW' : 'EDIT YOUR REVIEW'),
                          ),
                        ],
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: AbzioLoadingView(
                            title: 'Loading reviews',
                            subtitle: 'Fetching ratings and styling feedback for this piece.',
                          ),
                        )
                      else if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: AbzioEmptyCard(
                            title: 'No reviews yet',
                            subtitle: 'Be the first customer to review this boutique product.',
                          ),
                        )
                      else
                        ..._reviews.map(
                          (review) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(DateFormat('dd MMM').format(review.createdAt)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (index) => Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: index < review.rating.round() ? Colors.amber : context.abzioBorder,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(review.comment),
                                  if (review.imagePath != null && review.imagePath!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: review.imagePath!.startsWith('http')
                                          ? SizedBox(
                                              height: 140,
                                              width: double.infinity,
                                              child: AbzioNetworkImage(
                                                imageUrl: review.imagePath!,
                                                fallbackLabel: 'REVIEW',
                                              ),
                                            )
                                          : localFileImage(review.imagePath!, height: 140, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                  ],
                                  if (auth.user != null && review.userId == auth.user!.id)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _deleteReview(review),
                                        child: const Text('DELETE'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  width < 360 ? 14 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: width < 360
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BottomPriceBlock(
                            pricing: pricing,
                            isLimitedStock: product.isLimitedStock,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _bottomLeftCtaAction(product),
                              child: Text(_bottomLeftCtaLabel()),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _bottomRightCtaAction(product),
                              child: Text(_bottomRightCtaLabel()),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _BottomPriceBlock(
                              pricing: pricing,
                              isLimitedStock: product.isLimitedStock,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _bottomLeftCtaAction(product),
                                      child: Text(_bottomLeftCtaLabel()),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: _bottomRightCtaAction(product),
                                      child: Text(_bottomRightCtaLabel()),
                                    ),
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
          if (_showCartFlight && _cartFlightStart != null && _cartFlightEnd != null)
            AnimatedBuilder(
              animation: _cartFlightController,
              child: Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: _cartFlightSize.width,
                    height: _cartFlightSize.height,
                    child: AbzioNetworkImage(
                      imageUrl: images.first,
                      fallbackLabel: product.name,
                    ),
                  ),
                ),
              ),
              builder: (context, child) {
                final progress = _cartFlightController.value;
                final curved = Curves.easeInOutCubic.transform(progress);
                final current = Offset.lerp(_cartFlightStart, _cartFlightEnd, curved)!;
                final scale = lerpDouble(1, 0.28, curved)!;
                final opacity = lerpDouble(1, 0.0, Curves.easeIn.transform(progress))!;
                return Positioned(
                  left: current.dx,
                  top: current.dy,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      ),
    );
  }

*/
  Future<void> _toggleWishlistWithAuth(
    WishlistProvider wishlist,
    Product product,
  ) async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Save to wishlist',
      trigger: AuthPromptTrigger.wishlist,
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
    try {
      final wasWishlisted = wishlist.isWishlisted(product.id);
      await wishlist.toggleWishlist(product);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            wasWishlisted
                ? 'Removed from your wishlist'
                : 'Added to your wishlist',
          ),
          duration: const Duration(milliseconds: 1300),
        ),
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

  Future<void> _openGallery() async {
    final images = _activeImages.isEmpty
        ? const ['https://via.placeholder.com/600x750']
        : _activeImages;
    final selectedIndex = await Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: _ProductImageViewerScreen(
            product: _product,
            images: images,
            initialIndex: _imageIndex,
          ),
        ),
      ),
    );
    if (!mounted || selectedIndex == null || selectedIndex == _imageIndex) {
      return;
    }
    setState(() => _imageIndex = selectedIndex);
    if (_imageController.hasClients) {
      _imageController.jumpToPage(selectedIndex);
    }
  }
}

class _ProductImageViewerScreen extends StatefulWidget {
  const _ProductImageViewerScreen({
    required this.product,
    required this.images,
    required this.initialIndex,
  });

  final Product product;
  final List<String> images;
  final int initialIndex;

  @override
  State<_ProductImageViewerScreen> createState() =>
      _ProductImageViewerScreenState();
}

class _ProductImageViewerScreenState extends State<_ProductImageViewerScreen> {
  static const double _thumbnailExtent = 82;
  late final PageController _pageController;
  late final ScrollController _thumbnailController;
  final Map<int, TransformationController> _zoomControllers = {};
  TapDownDetails? _doubleTapDetails;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailController = ScrollController();
    _attachZoomListener(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheAround(_currentIndex);
      _scrollToThumbnail(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _zoomControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _attachZoomListener(int index) {
    final controller = _controllerFor(index);
    controller.removeListener(_handleZoomChanged);
    controller.addListener(_handleZoomChanged);
  }

  void _detachZoomListener(int index) {
    final controller = _controllerFor(index);
    controller.removeListener(_handleZoomChanged);
  }

  void _handleZoomChanged() {
    final controller = _controllerFor(_currentIndex);
    final scale = controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.02;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _resetZoom(int index) {
    final controller = _controllerFor(index);
    controller.value = Matrix4.identity();
  }

  void _precacheAround(int index) {
    for (final offset in const [-1, 0, 1]) {
      final preloadIndex = index + offset;
      if (preloadIndex < 0 || preloadIndex >= widget.images.length) {
        continue;
      }
      final imageUrl = widget.images[preloadIndex];
      precacheImage(CachedNetworkImageProvider(imageUrl), context);
    }
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbnailController.hasClients) {
      return;
    }
    final viewport = _thumbnailController.position.viewportDimension;
    final targetOffset =
        (index * _thumbnailExtent) - ((viewport - _thumbnailExtent) / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _thumbnailController.position.maxScrollExtent,
    );
    if (animate) {
      _thumbnailController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _thumbnailController.jumpTo(clampedOffset);
    }
  }

  Future<void> _jumpToIndex(int index) async {
    if (index < 0 || index >= widget.images.length || index == _currentIndex) {
      return;
    }
    _resetZoom(_currentIndex);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleDoubleTap(int index) {
    final controller = _controllerFor(index);
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final isCurrentlyZoomed = controller.value.getMaxScaleOnAxis() > 1.02;
    if (isCurrentlyZoomed) {
      controller.value = Matrix4.identity();
      return;
    }
    final scale = 2.6;
    final x = -position.dx * (scale - 1);
    final y = -position.dy * (scale - 1);
    controller.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _shareCurrentImage() async {
    final imageUrl = widget.images[_currentIndex];
    final price = widget.product.price <= 0
        ? ''
        : ' for ${NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0).format(widget.product.price)}';
    final message =
        'Check out ${widget.product.name}$price on Abianzo.\n$imageUrl';
    await Share.share(message, subject: widget.product.name);
  }

  Future<void> _toggleWishlistWithAuth(
    WishlistProvider wishlist,
    Product product,
  ) async {
    final allowed = await SoftAuthGate.ensureAuthenticated(
      context,
      intentLabel: 'Save to wishlist',
      trigger: AuthPromptTrigger.wishlist,
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
    try {
      final wasWishlisted = wishlist.isWishlisted(product.id);
      await wishlist.toggleWishlist(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            wasWishlisted
                ? 'Removed from your wishlist'
                : 'Added to your wishlist',
          ),
          duration: const Duration(milliseconds: 1300),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWishlisted = context.select<WishlistProvider, bool>(
      (wishlist) => wishlist.isWishlisted(widget.product.id),
    );
    final isWishlistPending = context.select<WishlistProvider, bool>(
      (wishlist) => wishlist.isPending(widget.product.id),
    );
    final wishlist = context.read<WishlistProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  _detachZoomListener(_currentIndex);
                  _resetZoom(_currentIndex);
                  setState(() => _currentIndex = index);
                  _attachZoomListener(index);
                  _precacheAround(index);
                  _scrollToThumbnail(index);
                },
                itemBuilder: (context, index) {
                  final controller = _controllerFor(index);
                  return GestureDetector(
                    onDoubleTapDown: (details) => _doubleTapDetails = details,
                    onDoubleTap: () => _handleDoubleTap(index),
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 1.0,
                      maxScale: 3.6,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: Center(
                        child: Hero(
                          tag: 'product-hero-${widget.product.id}-$index',
                          child: CachedNetworkImage(
                            imageUrl: widget.images[index],
                            fit: BoxFit.contain,
                            fadeInDuration: const Duration(milliseconds: 220),
                            placeholder: (context, url) => Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFC9A74E),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                widget.product.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox(height: 124),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isZoomed ? 0.6 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _ViewerControlButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(_currentIndex),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: Container(
                          key: ValueKey<int>(_currentIndex),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.images.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ViewerControlButton(
                        icon: Icons.ios_share_rounded,
                        onTap: _shareCurrentImage,
                      ),
                      const SizedBox(width: 10),
                      AnimatedWishlistButton(
                        isSelected: isWishlisted,
                        isLoading: isWishlistPending,
                        usePremiumIntentAnimation: true,
                        size: 42,
                        iconSize: 20,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        unselectedColor: Colors.white,
                        selectedColor: const Color(0xFFC8A44D),
                        onTap: () async {
                          await _toggleWishlistWithAuth(
                            wishlist,
                            widget.product,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1) ...[
              Positioned(
                left: 12,
                top: 0,
                bottom: 122,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _currentIndex == 0 ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: _currentIndex == 0,
                      child: _ViewerControlButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => _jumpToIndex(_currentIndex - 1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 122,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _currentIndex == widget.images.length - 1
                        ? 0.0
                        : 1.0,
                    child: IgnorePointer(
                      ignoring: _currentIndex == widget.images.length - 1,
                      child: _ViewerControlButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        onTap: () => _jumpToIndex(_currentIndex + 1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isZoomed ? 0.6 : 1.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          controller: _thumbnailController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.images.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final isSelected = index == _currentIndex;
                            return GestureDetector(
                              onTap: () => _jumpToIndex(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 72,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFC9A74E)
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFC9A74E,
                                            ).withValues(alpha: 0.22),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[index],
                                    fit: BoxFit.cover,
                                    memCacheWidth: 240,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.white12),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: Colors.white10,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.white54,
                                            size: 18,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Swipe through all ${widget.images.length} product photos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const fill = Color.fromRGBO(255, 255, 255, 0.6);
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ViewerControlButton extends StatelessWidget {
  const _ViewerControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _TrialAtHomeButton extends StatelessWidget {
  const _TrialAtHomeButton({
    required this.onTap,
    required this.recommendedSize,
  });

  final VoidCallback onTap;
  final String recommendedSize;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF16120D),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try at Home',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try at home with AI size guidance and local boutique delivery.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _TrustMiniBadge(
                        label: 'AI size recommendation',
                        dark: true,
                      ),
                      const _TrustMiniBadge(
                        label: 'Nearby boutique delivery',
                        dark: true,
                      ),
                      _TrustMiniBadge(
                        label: 'AI-selected size: $recommendedSize',
                        dark: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, color: Color(0xFFC8A96A)),
          ],
        ),
      ),
    );
  }
}

class _TrustMiniBadge extends StatelessWidget {
  const _TrustMiniBadge({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFF3E8D2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: dark ? Colors.white : const Color(0xFF6F5226),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE1D2B2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF111111),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PerfectFitExperienceSheet extends StatefulWidget {
  const _PerfectFitExperienceSheet({
    required this.product,
    required this.suggestedItems,
    required this.recommendedSize,
    required this.addressLabel,
  });

  final Product product;
  final List<Product> suggestedItems;
  final String recommendedSize;
  final String addressLabel;

  @override
  State<_PerfectFitExperienceSheet> createState() =>
      _PerfectFitExperienceSheetState();
}

class _PerfectFitExperienceSheetState
    extends State<_PerfectFitExperienceSheet> {
  int _step = 0;
  late final List<Product> _selectedItems;
  late final List<Product> _styleSuggestions;
  String _slot = 'Tomorrow - 6 PM to 9 PM';
  String _experienceType = 'premium';

  @override
  void initState() {
    super.initState();
    _selectedItems = <Product>[widget.product];
    _styleSuggestions = widget.suggestedItems.take(4).toList();
  }

  void _toggleItem(Product product) {
    setState(() {
      if (_selectedItems.any((item) => item.id == product.id)) {
        if (product.id != widget.product.id) {
          _selectedItems.removeWhere((item) => item.id == product.id);
        }
      } else if (_selectedItems.length < 5) {
        _selectedItems.add(product);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFCFAF6), Color(0xFFF7F1E7)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D0C2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(5, (index) {
                  final active = index <= _step;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFC8A96A)
                            : const Color(0xFFE9E2D8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF18120C),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perfect Fit Experience at Home',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Personal stylist, trial room, and tailor brought directly to your door.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFC8A96A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildStep(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step -= 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: Color(0xFFE4DACA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_step == 4) {
                          Navigator.of(context).pop(true);
                          return;
                        }
                        setState(() => _step += 1);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC8A96A),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _step == 4 ? 'Book Experience' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        final items = [widget.product, ...widget.suggestedItems.take(4)];
        return _TrialStepShell(
          key: const ValueKey('select'),
          stepLabel: 'STEP 1',
          title: 'Choose items to try at home',
          subtitle: 'Select up to 5 pieces for your Perfect Fit Experience.',
          child: Column(
            children: items.map((product) {
              final selected = _selectedItems.any(
                (item) => item.id == product.id,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrialSelectableCard(
                  product: product,
                  selected: selected,
                  recommendedSize: widget.recommendedSize,
                  onTap: () => _toggleItem(product),
                ),
              );
            }).toList(),
          ),
        );
      case 1:
        return _TrialStepShell(
          key: const ValueKey('styled'),
          stepLabel: 'STEP 2',
          title: 'Complete your look',
          subtitle: 'AI-styled additions that work with your body and taste.',
          child: Column(
            children: _styleSuggestions.map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrialStyledCard(
                  product: product,
                  onTap: () => _toggleItem(product),
                ),
              );
            }).toList(),
          ),
        );
      case 2:
        final slots = [
          'Today - 7 PM to 10 PM',
          'Tomorrow - 6 PM to 9 PM',
          'Weekend - 11 AM to 2 PM',
        ];
        return _TrialStepShell(
          key: const ValueKey('slot'),
          stepLabel: 'STEP 3',
          title: 'Pick your trial time',
          subtitle: 'Delivered in 24 hours with premium packaging.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...slots.map(
                (slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SelectionRowCard(
                    title: slot,
                    subtitle: 'Delivered in 24 hours',
                    selected: _slot == slot,
                    onTap: () => setState(() => _slot = slot),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SelectionRowCard(
                title: 'Deliver to',
                subtitle: widget.addressLabel,
                selected: true,
                onTap: () {},
              ),
            ],
          ),
        );
      case 3:
        return _TrialStepShell(
          key: const ValueKey('experience'),
          stepLabel: 'STEP 4',
          title: 'Choose your experience',
          subtitle: 'Luxury comfort at home, with or without styling support.',
          child: Column(
            children: [
              _SelectionRowCard(
                title: 'Standard Trial',
                subtitle: 'Try at home at your convenience',
                selected: _experienceType == 'standard',
                onTap: () => setState(() => _experienceType = 'standard'),
              ),
              const SizedBox(height: 12),
              _SelectionRowCard(
                title: 'Premium Stylist',
                subtitle: 'Get a stylist to assist your look',
                selected: _experienceType == 'premium',
                highlighted: true,
                badge: 'Recommended',
                onTap: () => setState(() => _experienceType = 'premium'),
              ),
            ],
          ),
        );
      default:
        return _TrialStepShell(
          key: const ValueKey('confirm'),
          stepLabel: 'STEP 5',
          title: 'Your Perfect Fit Experience is booked',
          subtitle: 'You only pay for what you keep.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionRowCard(
                title: _slot,
                subtitle: '₹99 Trial Booking Fee. Adjusted on purchase.',
                selected: true,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ..._selectedItems.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MiniSelectionCard(product: product),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 2),
                      child: const Text('Modify'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

class _TrialFitFeedbackSheet extends StatefulWidget {
  const _TrialFitFeedbackSheet({
    required this.product,
    required this.onCustomTailoringTap,
  });

  final Product product;
  final VoidCallback onCustomTailoringTap;

  @override
  State<_TrialFitFeedbackSheet> createState() => _TrialFitFeedbackSheetState();
}

class _TrialFitFeedbackSheetState extends State<_TrialFitFeedbackSheet> {
  String _fitResponse = 'perfect';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D0C2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'How did it fit?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about ${widget.product.name} so we can sharpen every future recommendation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF666666),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _SelectionRowCard(
              title: 'Perfect',
              subtitle: 'Exactly how I wanted it to feel',
              selected: _fitResponse == 'perfect',
              onTap: () => setState(() => _fitResponse = 'perfect'),
            ),
            const SizedBox(height: 10),
            _SelectionRowCard(
              title: 'Too tight',
              subtitle: 'Needs a little more room',
              selected: _fitResponse == 'tight',
              onTap: () => setState(() => _fitResponse = 'tight'),
            ),
            const SizedBox(height: 10),
            _SelectionRowCard(
              title: 'Too loose',
              subtitle: 'Needs a cleaner, sharper fit',
              selected: _fitResponse == 'loose',
              onTap: () => setState(() => _fitResponse = 'loose'),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _fitResponse == 'perfect'
                  ? Container(
                      key: const ValueKey('perfect-note'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBD8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Perfect. We\'ll use this fit outcome to sharpen your future recommendations.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF7B5B27),
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('tailoring-note'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adjust with custom tailoring',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We can refine this piece so it fits like it was made only for you.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF666666),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make this perfect for you',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _AdjustmentChip(label: 'Tighten fit'),
                      _AdjustmentChip(label: 'Adjust length'),
                      _AdjustmentChip(label: 'Custom stitch'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: widget.onCustomTailoringTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC8A96A),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Make this perfect for you',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

class _TrialStepShell extends StatelessWidget {
  const _TrialStepShell({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFFC39A4E),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF666666),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TrialSelectableCard extends StatelessWidget {
  const _TrialSelectableCard({
    required this.product,
    required this.selected,
    required this.recommendedSize,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final String recommendedSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = product.images.isNotEmpty ? product.images.first : '';
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5EBD8) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFE7E0D7),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 88,
                child: AbzioNetworkImage(
                  imageUrl: image,
                  fallbackLabel: product.name,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _LightChip(label: 'Recommended for your body'),
                      _LightChip(label: '92% fit match'),
                      _LightChip(label: 'Size $recommendedSize'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFFC8A96A)
                  : const Color(0xFF9E968A),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialStyledCard extends StatelessWidget {
  const _TrialStyledCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LightChip(label: 'Styled for you'),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete the look with a more polished at-home edit.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5EBD8),
                foregroundColor: const Color(0xFF7B5B27),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionRowCard extends StatelessWidget {
  const _SelectionRowCard({
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.highlighted = false,
    this.badge,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool highlighted;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFF16120D)
              : (selected ? const Color(0xFFF7F1E7) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFE7E0D7),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: highlighted
                                    ? Colors.white
                                    : const Color(0xFF111111),
                              ),
                        ),
                      ),
                      if (badge != null)
                        _LightChip(label: badge!, dark: highlighted),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: highlighted
                          ? Colors.white.withValues(alpha: 0.78)
                          : const Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? const Color(0xFFC8A96A)
                    : const Color(0xFF9E968A),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniSelectionCard extends StatelessWidget {
  const _MiniSelectionCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '\u20B9',
              decimalDigits: 0,
            ).format(product.effectivePrice),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  const _LightChip({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF4E8D0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: dark ? Colors.white : const Color(0xFF7B5B27),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdjustmentChip extends StatelessWidget {
  const _AdjustmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF7B5B27),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailPricing {
  const _DetailPricing({
    required this.currentLabel,
    this.originalLabel,
    this.discountPercent = 0,
  });

  final String currentLabel;
  final String? originalLabel;
  final int discountPercent;

  static _DetailPricing fromProduct(Product product) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final currentPrice = product.effectivePrice;
    final originalPrice =
        (product.basePrice != null && product.basePrice! > currentPrice)
        ? product.basePrice
        : product.originalPrice;
    final discountPercent =
        originalPrice == null || originalPrice <= currentPrice
        ? 0
        : (((originalPrice - currentPrice) / originalPrice) * 100).round();

    return _DetailPricing(
      currentLabel: formatter.format(currentPrice),
      originalLabel: originalPrice == null
          ? null
          : formatter.format(originalPrice),
      discountPercent: discountPercent,
    );
  }
}

class _CtaDecisionSnapshot {
  const _CtaDecisionSnapshot({
    required this.type,
    required this.fitConfidence,
    required this.reason,
    required this.returnHistory,
    required this.userType,
    required this.productType,
    required this.locationSpeed,
  });

  final String type;
  final int fitConfidence;
  final String reason;
  final double returnHistory;
  final String userType;
  final String productType;
  final String locationSpeed;
}






