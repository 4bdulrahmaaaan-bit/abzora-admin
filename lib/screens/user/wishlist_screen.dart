// ignore_for_file: dead_code, unreachable_code, unused_element
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_error_text.dart';
import '../../utils/soft_auth_gate.dart';
import '../../widgets/global_skeletons.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/delivery_location_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'search_screen.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  static const String _filtersPrefsKey = 'abianzo_wishlist_filters_v2';
  static const String _recentPresetsPrefsKey =
      'abianzo_wishlist_recent_presets_v1';

  final DatabaseService _database = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  WishlistProvider? _wishlistProvider;
  Future<List<_WishlistEntry>>? _entriesFuture;
  Timer? _refreshTimer;
  WishlistFilterState _filters = WishlistFilterState.defaults();
  List<String> _recentPresets = const [];
  String _lastWishlistSignature = '';
  bool _prefsLoaded = false;
  bool _hasAttachedWishlistListener = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _wishlistProvider = context.read<WishlistProvider>();
      _wishlistProvider!.addListener(_syncWishlistEntries);
      _hasAttachedWishlistListener = true;
      _syncWishlistEntries(force: true);
      _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (!mounted) {
          return;
        }
        _syncWishlistEntries(force: true);
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_hasAttachedWishlistListener) {
      _wishlistProvider?.removeListener(_syncWishlistEntries);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_filtersPrefsKey);
      final recentRaw = prefs.getStringList(_recentPresetsPrefsKey);
      if (!mounted) {
        return;
      }
      setState(() {
        if (raw != null && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              _filters = WishlistFilterState.fromJson(decoded);
            } else if (decoded is Map) {
              _filters = WishlistFilterState.fromJson(
                Map<String, dynamic>.from(decoded),
              );
            }
          } catch (_) {
            _filters = WishlistFilterState.defaults();
          }
        }
        _recentPresets = recentRaw ?? const [];
        _prefsLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filtersPrefsKey, jsonEncode(_filters.toJson()));
    await prefs.setStringList(_recentPresetsPrefsKey, _recentPresets);
  }

  void _syncWishlistEntries({bool force = false}) {
    final provider = _wishlistProvider ?? context.read<WishlistProvider>();
    final items = provider.items;
    final signature = items
        .map(
          (item) =>
              '${item.productId}:${item.storeId}:${item.price}:${item.addedAt.millisecondsSinceEpoch}',
        )
        .join('|');
    if (!force &&
        signature == _lastWishlistSignature &&
        _entriesFuture != null) {
      return;
    }
    _lastWishlistSignature = signature;
    setState(() {
      _entriesFuture = _hydrateWishlistEntries(items);
    });
  }

  Future<List<_WishlistEntry>> _hydrateWishlistEntries(
    List<WishlistItem> items,
  ) async {
    if (items.isEmpty) {
      return const [];
    }
    final entries = await Future.wait(
      items.map((item) async {
        try {
          final product = await _database.getProductById(item.productId);
          return _WishlistEntry(item: item, product: product);
        } catch (e) {
          debugPrint('Failed to hydrate wishlist item ${item.productId}: $e');
          return _WishlistEntry(item: item, product: null);
        }
      }),
    );
    return entries;
  }

  void _setFilters(WishlistFilterState next, {String? recentPreset}) {
    setState(() {
      _filters = next;
      if (recentPreset != null && recentPreset.trim().isNotEmpty) {
        _recentPresets = <String>[
          recentPreset.trim(),
          ..._recentPresets.where((item) => item != recentPreset.trim()),
        ].take(4).toList();
      }
    });
    unawaited(_persistState());
  }

  List<_WishlistEntry> _filterEntries(
    List<_WishlistEntry> entries, [
    WishlistFilterState? filter,
  ]) {
    final locationProvider = context.read<LocationProvider>();
    final userPosition = locationProvider.userPosition;
    final activeFilter = filter ?? _filters;
    final filtered = entries.where((entry) {
      final product = entry.product;
      final price = _entryPrice(entry);
      final discountPercent = _discountPercent(entry);
      final brands = _normalisedBrands(product, entry);
      final categories = _categoryTokens(product, entry);
      final sizes = _sizeTokens(product, entry);
      final seller = _sellerBucket(product);

      if (price < activeFilter.minPrice || price > activeFilter.maxPrice) {
        return false;
      }
      if (activeFilter.brands.isNotEmpty &&
          !brands.any((brand) => activeFilter.brands.contains(brand))) {
        return false;
      }
      if (activeFilter.categories.isNotEmpty &&
          !categories.any(
            (category) => activeFilter.categories.contains(category),
          )) {
        return false;
      }
      if (activeFilter.sizes.isNotEmpty &&
          !sizes.any((size) => activeFilter.sizes.contains(size))) {
        return false;
      }
      if (activeFilter.sellerTypes.isNotEmpty &&
          !activeFilter.sellerTypes.contains(seller)) {
        return false;
      }
      if (activeFilter.arOnly && !(product?.tryOnAvailable ?? false)) {
        return false;
      }
      if (activeFilter.availableInArea && !_availableInArea(product)) {
        return false;
      }
      if (activeFilter.sameDayDelivery &&
          !(product?.sameDayAvailable ?? false)) {
        return false;
      }
      if (activeFilter.expressDelivery && !(_isExpressDelivery(product))) {
        return false;
      }
      if (activeFilter.storePickup && !(_storePickupAvailable(product))) {
        return false;
      }
      if (activeFilter.hideOutOfStock && (product?.stock ?? 0) <= 0) {
        return false;
      }
      if (activeFilter.stockFilters.isNotEmpty &&
          !_matchesStockFilters(product, activeFilter.stockFilters)) {
        return false;
      }
      if (activeFilter.discountThresholds.isNotEmpty &&
          !_matchesDiscountFilters(
            discountPercent,
            activeFilter.discountThresholds,
          )) {
        return false;
      }
      if (activeFilter.ratingThreshold > 0 &&
          (product?.rating ?? 0) < activeFilter.ratingThreshold) {
        return false;
      }
      if (activeFilter.gender != 'All' &&
          !_matchesAttributeText(product, activeFilter.gender, ['gender'])) {
        return false;
      }
      if (activeFilter.colors.isNotEmpty &&
          !activeFilter.colors.any(
            (value) => _matchesAttributeText(product, value, ['color']),
          )) {
        return false;
      }
      if (activeFilter.occasions.isNotEmpty &&
          !activeFilter.occasions.any(
            (value) => _matchesAttributeText(product, value, ['occasion']),
          )) {
        return false;
      }
      if (activeFilter.deliveryTimes.isNotEmpty &&
          !activeFilter.deliveryTimes.any(
            (value) => _matchesDeliveryTime(product, value),
          )) {
        return false;
      }
      if (activeFilter.fabrics.isNotEmpty &&
          !activeFilter.fabrics.any(
            (value) => _matchesAttributeText(product, value, ['fabric']),
          )) {
        return false;
      }
      if (activeFilter.fits.isNotEmpty &&
          !activeFilter.fits.any(
            (value) => _matchesAttributeText(product, value, ['fit']),
          )) {
        return false;
      }
      if (activeFilter.patterns.isNotEmpty &&
          !activeFilter.patterns.any(
            (value) => _matchesAttributeText(product, value, ['pattern']),
          )) {
        return false;
      }
      if (activeFilter.sleeveTypes.isNotEmpty &&
          !activeFilter.sleeveTypes.any(
            (value) => _matchesAttributeText(product, value, ['sleeve_type']),
          )) {
        return false;
      }
      if (activeFilter.neckTypes.isNotEmpty &&
          !activeFilter.neckTypes.any(
            (value) => _matchesAttributeText(product, value, ['neck_type']),
          )) {
        return false;
      }
      if (activeFilter.lengths.isNotEmpty &&
          !activeFilter.lengths.any(
            (value) => _matchesAttributeText(product, value, ['length']),
          )) {
        return false;
      }
      if (activeFilter.tryAtHomeAvailable &&
          !(product?.tryAtHomeAvailable ?? false)) {
        return false;
      }
      if (activeFilter.customizable &&
          !(product?.isCustomTailoring == true ||
              product?.attributeBool('customizable') == true)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((left, right) {
      final a = left.product;
      final b = right.product;
      switch (_filters.sort) {
        case WishlistSortOption.relevance:
          return _relevanceScore(
            right,
            userPosition,
          ).compareTo(_relevanceScore(left, userPosition));
        case WishlistSortOption.recentlyAdded:
          return right.item.addedAt.compareTo(left.item.addedAt);
        case WishlistSortOption.priceLowToHigh:
          return _entryPrice(left).compareTo(_entryPrice(right));
        case WishlistSortOption.priceHighToLow:
          return _entryPrice(right).compareTo(_entryPrice(left));
        case WishlistSortOption.highestDiscount:
          return _discountPercent(right).compareTo(_discountPercent(left));
        case WishlistSortOption.mostPopular:
          return _popularityScore(right).compareTo(_popularityScore(left));
        case WishlistSortOption.trendingNow:
          return _trendingScore(right).compareTo(_trendingScore(left));
        case WishlistSortOption.bestRated:
          return (b?.rating ?? 0).compareTo(a?.rating ?? 0);
        case WishlistSortOption.arTryOnFirst:
          final leftAr = a?.tryOnAvailable ?? false;
          final rightAr = b?.tryOnAvailable ?? false;
          if (leftAr != rightAr) {
            return rightAr ? 1 : -1;
          }
          return _popularityScore(right).compareTo(_popularityScore(left));
        case WishlistSortOption.nearestStoreFirst:
          return _distanceToUser(
            left,
            userPosition,
          ).compareTo(_distanceToUser(right, userPosition));
        case WishlistSortOption.fastestDelivery:
          return _deliveryPriority(right).compareTo(_deliveryPriority(left));
      }
    });

    return filtered;
  }

  bool _matchesAttributeText(
    Product? product,
    String value,
    List<String> keys,
  ) {
    if (product == null) {
      return false;
    }
    final candidate = value.toLowerCase().trim();
    if (candidate.isEmpty || candidate == 'all') {
      return true;
    }
    final tokens = <String>{
      product.name,
      product.brand,
      product.category,
      product.subcategory,
      product.fabric ?? '',
      product.outfitType ?? '',
      ...product.sizes,
      ...product.colorVariants.map((variant) => variant.colorName),
      ...product.highlights,
    }.map((item) => item.toLowerCase().trim()).where((item) => item.isNotEmpty);

    final allTokens = {...tokens};
    for (final key in keys) {
      final normalized = key.toLowerCase().replaceAll(' ', '_');
      allTokens.addAll(
        product.attributeList(normalized).map((item) => item.toLowerCase()),
      );
      final text = product.attributeText(normalized).toLowerCase().trim();
      if (text.isNotEmpty) {
        allTokens.add(text);
      }
    }
    return allTokens.any(
      (token) =>
          token == candidate ||
          token.contains(candidate) ||
          candidate.contains(token),
    );
  }

  bool _matchesDeliveryTime(Product? product, String value) {
    if (product == null) {
      return false;
    }
    final candidate = value.toLowerCase().trim();
    if (candidate.isEmpty || candidate == 'all') {
      return true;
    }
    if (candidate.contains('today') || candidate.contains('same')) {
      return product.sameDayAvailable;
    }
    if (candidate.contains('tomorrow')) {
      return false;
    }
    if (candidate.contains('2-3') || candidate.contains('2 to 3')) {
      return false;
    }
    if (candidate.contains('try at home')) {
      return product.tryAtHomeAvailable;
    }
    if (candidate.contains('express')) {
      return _isExpressDelivery(product);
    }
    return _matchesAttributeText(product, value, ['deliveryTime']);
  }

  double _entryPrice(_WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      return entry.item.price;
    }
    return product.effectivePrice;
  }

  double _discountPercent(_WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      return 0;
    }
    final base = product.originalPrice ?? product.basePrice ?? 0;
    final price = product.effectivePrice;
    if (base <= 0 || base <= price) {
      return 0;
    }
    return ((base - price) / base) * 100;
  }

  double _relevanceScore(_WishlistEntry entry, Position? userPosition) {
    final product = entry.product;
    if (product == null) {
      return 0;
    }

    var score = 0.0;
    score += _popularityScore(entry) * 0.35;
    score += product.rating * 12;
    score += _discountPercent(entry) * 0.6;
    if (product.tryOnAvailable) {
      score += 8;
    }
    if (product.sameDayAvailable) {
      score += 6;
    }
    if (_availableInArea(product)) {
      score += 4;
    }
    if (_isExpressDelivery(product)) {
      score += 3;
    }
    final distance = _distanceToUser(entry, userPosition);
    if (distance.isFinite) {
      score += math.max(0, 12 - distance.clamp(0, 12)) * 0.5;
    }
    score += math.max(0, 5 - (product.stock <= 0 ? 5 : 0));
    return score;
  }

  Set<String> _normalisedBrands(Product? product, _WishlistEntry entry) {
    final brand =
        (product?.brand.trim().isNotEmpty == true
                ? product!.brand.trim()
                : entry.item.name.split(' ').first)
            .trim();
    if (brand.isEmpty) {
      return const <String>{};
    }
    return <String>{brand.toLowerCase()};
  }

  Set<String> _categoryTokens(Product? product, _WishlistEntry entry) {
    final tokens = <String>{};
    final raw = [
      product?.category ?? '',
      product?.subcategory ?? '',
      product?.attributeText('gender') ?? '',
      product?.attributeText('targetGender') ?? '',
      product?.attributeText('occasion') ?? '',
      entry.item.name,
    ].join(' ').toLowerCase();
    for (final category in _categoryUniverse) {
      final normalized = category.toLowerCase();
      if (raw.contains(normalized) ||
          (normalized == 'men' && raw.contains('male')) ||
          (normalized == 'women' && raw.contains('female'))) {
        tokens.add(normalized);
      }
    }
    if (tokens.isEmpty && (product?.category.trim().isNotEmpty ?? false)) {
      tokens.add(product!.category.trim().toLowerCase());
    }
    return tokens;
  }

  Set<String> _sizeTokens(Product? product, _WishlistEntry entry) {
    final sizes = product?.sizes ?? const [];
    return sizes
        .map((size) => size.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  String _sellerBucket(Product? product) {
    final store = product?.store;
    if (store == null) {
      return 'Verified Sellers';
    }
    final vendorType = store.vendorType.toLowerCase();
    final visibility = store.vendorVisibility.toLowerCase();
    if (store.isFeatured ||
        visibility.contains('premium') ||
        visibility.contains('elite')) {
      return 'Premium Stores';
    }
    if (vendorType.contains('custom') ||
        vendorType.contains('boutique') ||
        vendorType.contains('atelier')) {
      return 'Local Boutiques';
    }
    if (vendorType.contains('mall')) {
      return 'Mall Brands';
    }
    return store.isApproved ? 'Verified Sellers' : 'Local Boutiques';
  }

  String _deliveryBucket(Product? product) {
    if (product == null) {
      return 'Fast';
    }
    if (product.sameDayAvailable) {
      return 'Same-Day Delivery';
    }
    return 'Standard Delivery';
  }

  bool _availableInArea(Product? product) {
    if (product == null) {
      return false;
    }
    return product.sameDayAvailable || product.tryAtHomeAvailable;
  }

  bool _isExpressDelivery(Product? product) {
    if (product == null) {
      return false;
    }
    return product.sameDayAvailable;
  }

  bool _storePickupAvailable(Product? product) {
    if (product == null) {
      return false;
    }
    final delivery = product.deliveryInfo;
    return delivery['storePickupAvailable'] == true ||
        delivery['pickupAvailable'] == true ||
        product.attributeBool('storePickupAvailable') ||
        product.attributeBool('pickupAvailable');
  }

  bool _matchesStockFilters(Product? product, Set<String> stockFilters) {
    final stock = product?.stock ?? 0;
    final normalized = stockFilters.map((item) => item.toLowerCase()).toSet();
    if (normalized.contains('in stock') && stock <= 0) {
      return false;
    }
    if (normalized.contains('low stock') && !(stock > 0 && stock <= 5)) {
      return false;
    }
    if (normalized.contains('out of stock') && stock > 0) {
      return false;
    }
    return true;
  }

  bool _matchesDiscountFilters(double discountPercent, Set<int> thresholds) {
    if (thresholds.isEmpty) {
      return true;
    }
    for (final threshold in thresholds) {
      if (discountPercent >= threshold) {
        return true;
      }
    }
    return false;
  }

  int _popularityScore(_WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      return 0;
    }
    return (product.demandScore * 100).round() +
        (product.purchaseCount * 6) +
        (product.viewCount ~/ 2);
  }

  int _trendingScore(_WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      return 0;
    }
    var score = _popularityScore(entry);
    if (product.tryOnAvailable) {
      score += 30;
    }
    if (product.sameDayAvailable) {
      score += 20;
    }
    if (_discountPercent(entry) >= 30) {
      score += 15;
    }
    return score;
  }

  double _distanceToUser(_WishlistEntry entry, Position? userPosition) {
    final product = entry.product;
    final store = product?.store;
    if (userPosition == null ||
        store?.latitude == null ||
        store?.longitude == null) {
      return double.infinity;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(store!.latitude! - userPosition.latitude);
    final dLon = _degToRad(store.longitude! - userPosition.longitude);
    final lat1 = _degToRad(userPosition.latitude);
    final lat2 = _degToRad(store.latitude!);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double value) => value * (math.pi / 180);

  int _deliveryPriority(_WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      return 0;
    }
    if (product.sameDayAvailable) {
      return 3;
    }
    if (_isExpressDelivery(product)) {
      return 2;
    }
    if (product.tryAtHomeAvailable) {
      return 1;
    }
    return 0;
  }

  List<String> _availableBrands(List<_WishlistEntry> entries) {
    final brands = <String>{};
    for (final entry in entries) {
      final product = entry.product;
      final brand = product?.brand.trim() ?? '';
      if (brand.isNotEmpty) {
        brands.add(brand);
      }
    }
    return brands.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _availableCategories(List<_WishlistEntry> entries) {
    final categories = <String>{..._categoryUniverse};
    for (final entry in entries) {
      final product = entry.product;
      final raw = [
        product?.category ?? '',
        product?.subcategory ?? '',
      ].join(' ').trim();
      if (raw.isNotEmpty) {
        categories.add(_displayCategory(raw));
      }
    }
    return categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _availableSizes(List<_WishlistEntry> entries) {
    final sizes = <String>{};
    for (final entry in entries) {
      for (final size in _sizeTokens(entry.product, entry)) {
        sizes.add(size);
      }
    }
    return sizes.toList()..sort();
  }

  String _displayCategory(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final category in _categoryUniverse) {
      if (normalized == category.toLowerCase()) {
        return category;
      }
    }
    if (normalized.contains('wedding')) return 'Wedding Wear';
    if (normalized.contains('dress')) return 'Dresses';
    if (normalized.contains('shirt')) return 'Shirts';
    if (normalized.contains('jean')) return 'Jeans';
    if (normalized.contains('jacket')) return 'Jackets';
    if (normalized.contains('shoe') || normalized.contains('footwear')) {
      return 'Footwear';
    }
    if (normalized.contains('access')) return 'Accessories';
    if (normalized.contains('men')) return 'Men';
    if (normalized.contains('women')) return 'Women';
    if (normalized.contains('kid')) return 'Kids';
    return raw.trim();
  }

  Future<void> _openFilterSheet(List<_WishlistEntry> entries) async {
    final result = await showModalBottomSheet<WishlistFilterState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WishlistFilterSheet(
        initialFilters: _filters,
        entries: entries,
        availableBrands: _availableBrands(entries),
        availableCategories: _availableCategories(entries),
        availableSizes: _availableSizes(entries),
        previewCount: (filter) => _filterEntries(entries, filter).length,
        onClearAll: () =>
            Navigator.of(context).pop(WishlistFilterState.defaults()),
      ),
    );
    if (result != null) {
      _setFilters(result, recentPreset: 'Filter Wishlist');
    }
  }

  Future<void> _openSortSheet() async {
    final result = await showModalBottomSheet<WishlistSortOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WishlistSortSheet(initialSort: _filters.sort),
    );
    if (result != null) {
      _setFilters(_filters.copyWith(sort: result));
    }
  }

  Future<void> _openCategorySheet(List<_WishlistEntry> entries) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WishlistCategorySheet(
        initialCategories: _filters.categories,
        availableCategories: _availableCategories(entries),
      ),
    );
    if (result != null) {
      _setFilters(_filters.copyWith(categories: result));
    }
  }

  Future<void> _openAvailabilitySheet() async {
    final result = await showModalBottomSheet<WishlistFilterState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _WishlistAvailabilitySheet(initialFilters: _filters),
    );
    if (result != null) {
      _setFilters(result);
    }
  }

  Future<void> _openCollectionsSheet() async {
    final collections = <String>[
      'My Luxury Picks',
      'My AR Favorites',
      'Wedding Collection',
      'Trending Near You',
      'Perfect For Wedding Season',
      'Similar To Saved Items',
      'AR Try-On Ready',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F5EF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCCDAF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Collections',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF14110D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose a curated lens for your saved wardrobe.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6A6257),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildPresetRail(
                    title: 'Curated Collections',
                    presets: collections,
                    aiStyle: true,
                    onTap: (preset) {
                      Navigator.of(sheetContext).pop();
                      _openPreset(preset);
                    },
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPreset(String preset) async {
    final next = _presetForName(preset).apply(_filters);
    _setFilters(next, recentPreset: preset);
  }

  _WishlistPreset _presetForName(String name) {
    switch (name) {
      case 'My AR Favorites':
        return _WishlistPreset.arFavorites;
      case 'Wedding Collection':
        return _WishlistPreset.weddingCollection;
      case 'Trending Near You':
        return _WishlistPreset.trendingNearYou;
      case 'Perfect For Wedding Season':
        return _WishlistPreset.weddingSeason;
      case 'Similar To Saved Items':
        return _WishlistPreset.similarToSavedItems;
      case 'AR Try-On Ready':
        return _WishlistPreset.arTryOnReady;
      case 'My Luxury Picks':
      default:
        return _WishlistPreset.luxuryPicks;
    }
  }

  Widget _buildPresetRail({
    required String title,
    required List<String> presets,
    required bool aiStyle,
    void Function(String preset)? onTap,
  }) {
    if (presets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF9B7D38),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets
                  .map(
                    (preset) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PresetChip(
                        label: preset,
                        aiStyle: aiStyle,
                        onTap: () => (onTap ?? _openPreset)(preset),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearch() async {
    final entries =
        await (_entriesFuture ?? Future.value(const <_WishlistEntry>[]));
    if (!mounted) {
      return;
    }
    final products = entries
        .map((entry) => entry.product)
        .whereType<Product>()
        .toList(growable: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          allProducts: products,
          selectedLocation: context.read<LocationProvider>().activeLocation,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildUtilityChip(
                  label: 'Filter',
                  icon: Icons.tune_rounded,
                  width: 100,
                  highlighted: _filters.activeGroupCount > 0,
                  onTap: _prefsLoaded
                      ? () async {
                          final entries =
                              await (_entriesFuture ??
                                  Future.value(const <_WishlistEntry>[]));
                          if (!mounted) {
                            return;
                          }
                          await _openFilterSheet(entries);
                        }
                      : null,
                ),
                const SizedBox(width: 12),
                _buildUtilityChip(
                  label: 'Sort',
                  icon: Icons.swap_vert_rounded,
                  width: 96,
                  onTap: _prefsLoaded ? _openSortSheet : null,
                ),
                const SizedBox(width: 12),
                _buildUtilityChip(
                  label: 'Category',
                  icon: Icons.category_outlined,
                  width: 112,
                  onTap: _prefsLoaded
                      ? () async {
                          final entries =
                              await (_entriesFuture ??
                                  Future.value(const <_WishlistEntry>[]));
                          if (!mounted) {
                            return;
                          }
                          await _openCategorySheet(entries);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDiscovery(List<_WishlistEntry> entries) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final curated = [...entries]
      ..sort(
        (a, b) => _curatedWishlistScore(b).compareTo(_curatedWishlistScore(a)),
      );
    final recent = [...entries]
      ..sort((a, b) => b.item.addedAt.compareTo(a.item.addedAt));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCarouselSection(
            title: 'You May Also Like',
            products: curated.take(8).toList(),
          ),
          const SizedBox(height: 28),
          _buildCarouselSection(
            title: 'Recently Viewed',
            products: recent.take(8).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityChip({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required double width,
    bool highlighted = false,
  }) {
    return SizedBox(
      width: width,
      child: _WishlistActionButton(
        label: label,
        icon: icon,
        onTap: onTap,
        highlighted: highlighted,
      ),
    );
  }

  Widget _buildCarouselSection({
    required String title,
    required List<_WishlistEntry> products,
  }) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF14110D),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 286,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final entry = products[index];
              return _WishlistCarouselCard(
                item: entry.item,
                product: entry.product,
              );
            },
          ),
        ),
      ],
    );
  }

  int _curatedWishlistScore(_WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      return 0;
    }

    var score = 0;
    score += (product.rating * 20).round();
    score += product.reviewCount.clamp(0, 250);
    score += product.purchaseCount * 6;
    if (product.tryOnAvailable) {
      score += 15;
    }
    if (product.sameDayAvailable) {
      score += 10;
    }
    if (product.isLimitedStock) {
      score += 12;
    }
    final original = product.originalPrice ?? product.basePrice ?? 0;
    if (original > product.effectivePrice) {
      score += 8;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5EF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: const Color(0xFF151515),
        ),
        centerTitle: true,
        titleSpacing: 0,
        title: Consumer<WishlistProvider>(
          builder: (context, wishlist, child) {
            final count = wishlist.items.length;
            final countText = count == 1 ? '1 item' : '$count items';
            return Text(
              'My Wishlist${count > 0 ? ' • $countText' : ''}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            );
          },
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              final count = cart.items.length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined),
                    color: const Color(0xFF151515),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF9A3D32),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE8DDCC))),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF17130F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'View Bag (${cart.items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      body: FutureBuilder<List<_WishlistEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <_WishlistEntry>[];
          final loading =
              snapshot.connectionState != ConnectionState.done &&
              entries.isEmpty;

          if (loading) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ShimmerProductGrid(itemCount: 6),
            );
          }

          if (entries.isEmpty) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _LuxuryWishlistEmptyState(),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _syncWishlistEntries(force: true);
              await (_entriesFuture ?? Future.value(const <_WishlistEntry>[]));
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                const SliverToBoxAdapter(
                  child: DeliveryLocationBar(
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 360,
                        ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _WishlistProductCard(
                        item: entry.item,
                        product: entry.product,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WishlistActionButton extends StatelessWidget {
  const _WishlistActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final active = highlighted;
    final activeColor = const Color(0xFF8D6A2E);
    final inactiveColor = const Color(0xFF5E564D);
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: active
                    ? activeColor.withValues(alpha: 0.26)
                    : const Color(0xFFE8DFD1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: active ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active ? activeColor : inactiveColor,
                    ),
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

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({required this.item, required this.product});

  final WishlistItem item;
  final Product? product;

  Product _displayProduct() {
    final hydrated = product;
    if (hydrated != null) {
      return hydrated;
    }
    return Product(
      id: item.productId,
      storeId: item.storeId,
      name: item.name,
      description: '',
      price: item.price,
      images: item.image.isEmpty ? const [] : [item.image],
      sizes: const ['M'],
      stock: 1,
      category: 'Fashion',
      rating: 0,
      reviewCount: 0,
      isCustomTailoring: false,
    );
  }

  double get _effectivePrice {
    final hydrated = product;
    return hydrated?.effectivePrice ?? item.price;
  }

  double? get _originalPrice {
    final original = product?.originalPrice;
    if (original != null && original > _effectivePrice) {
      return original;
    }
    return null;
  }

  int get _discountPercent {
    final original = _originalPrice;
    if (original == null || original <= 0) {
      return 0;
    }
    return (((original - _effectivePrice) / original) * 100).round();
  }

  String _formatPrice(double value) => 'Rs ${value.round()}';

  Future<void> _confirmRemove(
    BuildContext context,
    Product displayProduct,
  ) async {
    final shouldRemove = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFCF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remove from wishlist?',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF17130F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayProduct.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A6257),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Keep Item'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF17130F),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldRemove == true && context.mounted) {
      await _remove(context, displayProduct);
    }
  }

  Future<void> _remove(BuildContext context, Product displayProduct) async {
    try {
      await context.read<WishlistProvider>().removeFromWishlist(item.productId);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              context.read<WishlistProvider>().addToWishlist(displayProduct);
            },
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayProduct = _displayProduct();
    final imageUrl = displayProduct.images.isNotEmpty
        ? displayProduct.images.first
        : item.image;
    final String brand = displayProduct.brand.trim().isNotEmpty
        ? displayProduct.brand.trim()
        : (displayProduct.store?.name.trim().isNotEmpty == true
              ? displayProduct.store!.name.trim()
              : 'Unknown Brand');

    final selectedSize = displayProduct.sizes.isNotEmpty
        ? displayProduct.sizes.first
        : 'M';

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: displayProduct),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8DDCC)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: imageUrl.isEmpty
                            ? const _WishlistImageFallback()
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const _WishlistImageFallback(),
                              ),
                      ),
                    ),
                    if (displayProduct.rating > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFDF9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '★ ${displayProduct.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: 'Remove from wishlist',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          foregroundColor: const Color(0xFFC8A44D),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        onPressed: () =>
                            _confirmRemove(context, displayProduct),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          final inBag = cart.items.any(
                            (item) => item.product.id == displayProduct.id,
                          );
                          final disabled = displayProduct.stock <= 0;
                          return InkWell(
                            onTap: disabled
                                ? null
                                : () {
                                    if (inBag) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const CartScreen(),
                                        ),
                                      );
                                    } else {
                                      final result = cart.addToCart(
                                        displayProduct,
                                        selectedSize,
                                      );
                                      if (result ==
                                              CartAddResult.storeConflict &&
                                          context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Your bag already contains products from another store.',
                                            ),
                                          ),
                                        );
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Added to Bag'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: disabled
                                    ? const Color(0xFFD8D0C5)
                                    : const Color(0xFF17130F),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                inBag ? 'GO TO BAG' : 'ADD',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFB08D2B),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayProduct.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_discountPercent > 0) ...[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Text(
                              _formatPrice(_effectivePrice),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                            ),
                            Text(
                              _formatPrice(_originalPrice!),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                            Text(
                              '$_discountPercent% OFF',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          _formatPrice(_effectivePrice),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEDE6D8),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () => _confirmRemove(context, displayProduct),
                        borderRadius: BorderRadius.circular(16),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFF8A8272),
                            ),
                          ),
                        ),
                      ),
                      Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          final disabled = displayProduct.stock <= 0;
                          return InkWell(
                            onTap: disabled
                                ? null
                                : () {
                                    final inBag = cart.items.any(
                                      (item) =>
                                          item.product.id == displayProduct.id,
                                    );
                                    if (inBag) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const CartScreen(),
                                        ),
                                      );
                                    } else {
                                      final result = cart.addToCart(
                                        displayProduct,
                                        selectedSize,
                                      );
                                      if (result ==
                                              CartAddResult.storeConflict &&
                                          context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Your bag already contains products from another store.',
                                            ),
                                          ),
                                        );
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Added to Bag'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            borderRadius: BorderRadius.circular(16),
                            child: const SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 18,
                                  color: Color(0xFF8A8272),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(16),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Icon(
                              Icons.share_outlined,
                              size: 18,
                              color: Color(0xFF8A8272),
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
      ),
    );
  }
}

class _WishlistImageFallback extends StatelessWidget {
  const _WishlistImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4EBDD),
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          color: Color(0xFF8E6E2F),
          size: 42,
        ),
      ),
    );
  }
}

class _WishlistBadge extends StatelessWidget {
  const _WishlistBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8D6A2E)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17130F),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  const _WishlistTile({required this.item, required this.product});

  final WishlistItem item;
  final Product? product;

  bool _isAuthSessionError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('unauthorized') ||
        text.contains('session expired') ||
        text.contains('sign in again') ||
        text.contains('too many authentication requests');
  }

  double _discountPercent(Product? product) {
    if (product == null) {
      return 0;
    }
    final original = product.originalPrice ?? product.basePrice ?? 0;
    final price = product.effectivePrice;
    if (original <= 0 || original <= price) {
      return 0;
    }
    return ((original - price) / original) * 100;
  }

  Product _fallbackProduct() {
    return Product(
      id: item.productId,
      storeId: item.storeId,
      name: item.name,
      description: '',
      price: item.price,
      images: item.image.isEmpty ? const [] : [item.image],
      sizes: const ['M'],
      stock: 1,
      category: 'Fashion',
      rating: 0,
      reviewCount: 0,
      isCustomTailoring: false,
    );
  }

  String _firstNonBlankString(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  Future<void> _openTryLive(BuildContext context, Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  Future<void> _addToBag(BuildContext context, Product product) async {
    final selectedSize = product.sizes.isNotEmpty ? product.sizes.first : 'M';
    final result = context.read<CartProvider>().addToCart(
      product,
      selectedSize,
    );
    if (result == CartAddResult.storeConflict && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your bag already contains products from another store.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayProduct = product;
    final imageUrl = displayProduct?.images.isNotEmpty == true
        ? displayProduct!.images.first
        : item.image;
    final title = displayProduct?.name.isNotEmpty == true
        ? displayProduct!.name
        : item.name;
    final brand = displayProduct?.brand.trim().isNotEmpty == true
        ? displayProduct!.brand.trim()
        : '';
    final price = displayProduct?.effectivePrice ?? item.price;
    final original = displayProduct?.originalPrice ?? displayProduct?.basePrice;
    final discount = _discountPercent(displayProduct).round();
    final actionProduct = displayProduct ?? _fallbackProduct();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: actionProduct),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEAE3D5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AbzioNetworkImage(
                      imageUrl: imageUrl,
                      fallbackLabel: title,
                      maxWidth: 800,
                      quality: 'eco',
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WishlistActionIcon(
                            icon: Icons.photo_camera_outlined,
                            size: 40,
                            onTap: () => _openTryLive(context, actionProduct),
                          ),
                          const SizedBox(width: 8),
                          _WishlistActionIcon(
                            icon: Icons.close_rounded,
                            size: 44,
                            onTap: () async {
                              try {
                                await context
                                    .read<WishlistProvider>()
                                    .removeFromWishlist(item.productId);
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }
                                if (_isAuthSessionError(error)) {
                                  await context.read<AuthProvider>().logout();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await SoftAuthGate.ensureAuthenticated(
                                    context,
                                    intentLabel: 'Manage wishlist',
                                    trigger: AuthPromptTrigger.wishlist,
                                    promptStyle: AuthPromptStyle.softSheet,
                                  );
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppErrorText.from(error)),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _WishlistDistancePill(
                        label: _distanceOverlayLabel(displayProduct),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9A7A34),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF17130F),
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\u20B9${price.toInt()}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111111),
                            fontSize: 24,
                            height: 1.0,
                          ),
                    ),
                    if (original != null && original > price) ...[
                      const SizedBox(height: 4),
                      Text(
                        '\u20B9${original.toInt()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8C8377),
                          decoration: TextDecoration.lineThrough,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (discount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$discount% OFF',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9A7A34),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () => _addToBag(context, actionProduct),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Add to Bag'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistActionIcon extends StatelessWidget {
  const _WishlistActionIcon({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEAE3D5)),
          ),
          child: Icon(
            icon,
            size: size == 44 ? 20 : 18,
            color: const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}

String _distanceOverlayLabel(Product? product) {
  if (product == null) {
    return '';
  }
  final rating = product.rating > 0 ? product.rating : 4.7;
  final label = product.distanceLabel?.trim() ?? '';
  if (label.isNotEmpty) {
    return '★ ${rating.toStringAsFixed(1)} • $label';
  }
  final distanceKm = product.distanceKm;
  if (distanceKm == null) {
    return '★ ${rating.toStringAsFixed(1)}';
  }
  if (distanceKm < 1) {
    return '★ ${rating.toStringAsFixed(1)} • Nearby';
  }
  if (distanceKm < 10) {
    return '★ ${rating.toStringAsFixed(1)} • ${distanceKm.toStringAsFixed(1)} km';
  }
  return '★ ${rating.toStringAsFixed(1)} • ${distanceKm.round()} km';
}

class _WishlistDistancePill extends StatelessWidget {
  const _WishlistDistancePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFB89A57).withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 14,
                color: Color(0xFFC8A86B),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistCarouselCard extends StatelessWidget {
  const _WishlistCarouselCard({required this.item, required this.product});

  final WishlistItem item;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final displayProduct = product;
    final imageUrl = displayProduct?.images.isNotEmpty == true
        ? displayProduct!.images.first
        : item.image;
    final title = displayProduct?.name.isNotEmpty == true
        ? displayProduct!.name
        : item.name;
    final brand = displayProduct?.brand.trim().isNotEmpty == true
        ? displayProduct!.brand.trim()
        : '';
    final price = displayProduct?.effectivePrice ?? item.price;
    final distanceLabel = _distanceOverlayLabel(displayProduct);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product:
                  displayProduct ??
                  Product(
                    id: item.productId,
                    storeId: item.storeId,
                    name: item.name,
                    description: '',
                    price: item.price,
                    images: item.image.isEmpty ? const [] : [item.image],
                    sizes: const ['M'],
                    stock: 1,
                    category: 'Fashion',
                    rating: 0,
                    reviewCount: 0,
                    isCustomTailoring: false,
                  ),
            ),
          ),
        );
      },
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEAE3D5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AbzioNetworkImage(
                    imageUrl: imageUrl,
                    fallbackLabel: title,
                    maxWidth: 700,
                    quality: 'eco',
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _WishlistDistancePill(label: distanceLabel),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF9A7A34),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF17130F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\u20B9${price.toInt()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
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

class _WishlistFilterSheet extends StatefulWidget {
  const _WishlistFilterSheet({
    required this.initialFilters,
    required this.entries,
    required this.availableBrands,
    required this.availableCategories,
    required this.availableSizes,
    required this.previewCount,
    required this.onClearAll,
  });

  final WishlistFilterState initialFilters;
  final List<_WishlistEntry> entries;
  final List<String> availableBrands;
  final List<String> availableCategories;
  final List<String> availableSizes;
  final int Function(WishlistFilterState filter) previewCount;
  final VoidCallback onClearAll;

  @override
  State<_WishlistFilterSheet> createState() => _WishlistFilterSheetState();
}

class _WishlistFilterSheetState extends State<_WishlistFilterSheet> {
  late WishlistFilterState _draft;
  final TextEditingController _brandSearch = TextEditingController();
  String _selectedSection = 'Category';
  bool _advancedExpanded = false;
  static const List<double> _priceStops = [
    499,
    999,
    1999,
    2000,
    5000,
    10000,
    20000,
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  @override
  void dispose() {
    _brandSearch.dispose();
    super.dispose();
  }

  List<String> get _filteredBrands {
    final query = _brandSearch.text.trim().toLowerCase();
    final brands = widget.availableBrands;
    if (query.isEmpty) {
      return brands;
    }
    return brands
        .where((brand) => brand.toLowerCase().contains(query))
        .toList(growable: false);
  }

  int _sectionCount(String section) {
    switch (section) {
      case 'Category':
        return _draft.categories.length;
      case 'Gender':
        return _draft.gender == 'All' ? 0 : 1;
      case 'Brand':
        return _draft.brands.length;
      case 'Price':
        return (_draft.minPrice > 0 || _draft.maxPrice < 20000) ? 1 : 0;
      case 'Size':
        return _draft.sizes.length;
      case 'Color':
        return _draft.colors.length;
      case 'Occasion':
        return _draft.occasions.length;
      case 'Delivery Time':
        return _draft.deliveryTimes.length;
      case 'Fabric':
        return _draft.fabrics.length;
      case 'Fit':
        return _draft.fits.length;
      case 'Pattern':
        return _draft.patterns.length;
      case 'Sleeve Type':
        return _draft.sleeveTypes.length;
      case 'Neck Type':
        return _draft.neckTypes.length;
      case 'Length':
        return _draft.lengths.length;
      case 'Rating':
        return _draft.ratingThreshold > 0 ? 1 : 0;
      case 'Availability':
        return (_draft.stockFilters.isNotEmpty ||
                _draft.hideOutOfStock ||
                _draft.availableInArea ||
                _draft.sameDayDelivery ||
                _draft.expressDelivery ||
                _draft.storePickup)
            ? 1
            : 0;
      case 'AR Try-On':
        return _draft.arOnly ? 1 : 0;
      case 'Try At Home':
        return _draft.tryAtHomeAvailable ? 1 : 0;
      case 'Customizable':
        return _draft.customizable ? 1 : 0;
      case 'Advanced Filters':
        return _advancedSections.fold<int>(
          0,
          (sum, section) => sum + _sectionCount(section),
        );
      default:
        return 0;
    }
  }

  List<Widget> _activeChips() {
    final chips = <Widget>[];

    void addChip(String label, VoidCallback onDeleted) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: InputChip(
            label: Text(label),
            onDeleted: onDeleted,
            deleteIconColor: const Color(0xFF9A7A34),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE5D8C6)),
            labelStyle: const TextStyle(
              color: Color(0xFF111111),
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

    for (final category in _draft.categories) {
      addChip('Category: $category', () {
        setState(() {
          _draft = _draft.copyWith(
            categories: {..._draft.categories}..remove(category),
          );
        });
      });
    }
    for (final brand in _draft.brands) {
      addChip('Brand: $brand', () {
        setState(() {
          _draft = _draft.copyWith(brands: {..._draft.brands}..remove(brand));
        });
      });
    }
    for (final size in _draft.sizes) {
      addChip('Size: $size', () {
        setState(() {
          _draft = _draft.copyWith(sizes: {..._draft.sizes}..remove(size));
        });
      });
    }
    for (final value in _draft.colors) {
      addChip('Color: $value', () {
        setState(() {
          _draft = _draft.copyWith(colors: {..._draft.colors}..remove(value));
        });
      });
    }
    for (final value in _draft.occasions) {
      addChip('Occasion: $value', () {
        setState(() {
          _draft = _draft.copyWith(
            occasions: {..._draft.occasions}..remove(value),
          );
        });
      });
    }
    for (final value in _draft.deliveryTimes) {
      addChip('Delivery: $value', () {
        setState(() {
          _draft = _draft.copyWith(
            deliveryTimes: {..._draft.deliveryTimes}..remove(value),
          );
        });
      });
    }
    if (_draft.gender != 'All') {
      addChip('Gender: ${_draft.gender}', () {
        setState(() => _draft = _draft.copyWith(gender: 'All'));
      });
    }
    if (_draft.minPrice > 0 || _draft.maxPrice < 20000) {
      addChip('Price', () {
        setState(() => _draft = _draft.copyWith(minPrice: 0, maxPrice: 20000));
      });
    }
    if (_draft.ratingThreshold > 0) {
      addChip('Rating: ${_draft.ratingThreshold.toStringAsFixed(1)}+', () {
        setState(() => _draft = _draft.copyWith(ratingThreshold: 0));
      });
    }
    if (_draft.arOnly) {
      addChip('AR Try-On', () {
        setState(() => _draft = _draft.copyWith(arOnly: false));
      });
    }
    if (_draft.tryAtHomeAvailable) {
      addChip('Try At Home', () {
        setState(() => _draft = _draft.copyWith(tryAtHomeAvailable: false));
      });
    }
    if (_draft.customizable) {
      addChip('Customizable', () {
        setState(() => _draft = _draft.copyWith(customizable: false));
      });
    }

    return chips;
  }

  Widget _sectionRailItem(String section) {
    final count = _sectionCount(section);
    final selected = _selectedSection == section;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSection = section;
          if (section == 'Advanced Filters') {
            _advancedExpanded = !_advancedExpanded;
            if (_advancedExpanded) {
              if (!_advancedSections.contains(_selectedSection)) {
                _selectedSection = 'Fabric';
              }
            } else {
              _selectedSection = 'Advanced Filters';
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFE8DCC9) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                section,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8A86B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF8E6E2F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxuryFilterScaffold(BuildContext context) {
    final matchingCount = widget.previewCount(_draft);
    final activeChips = _activeChips();
    final rightPane = _buildSectionOptions(_selectedSection);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEAE3D5))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _draft = WishlistFilterState.defaults());
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFE2D8C6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Apply Filters ($matchingCount)'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Filter',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111111),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$matchingCount matching products',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _draft = WishlistFilterState.defaults());
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            if (activeChips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: activeChips),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final railWidth = constraints.maxWidth < 700 ? 160.0 : 200.0;
                  return Row(
                    children: [
                      SizedBox(
                        width: railWidth,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 10, 16),
                          children: [
                            for (final section in _primarySections) ...[
                              _sectionRailItem(section),
                              const SizedBox(height: 8),
                            ],
                            _sectionRailItem('Advanced Filters'),
                            if (_advancedExpanded) ...[
                              const SizedBox(height: 8),
                              for (final section in _advancedSections)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 10,
                                    bottom: 8,
                                  ),
                                  child: _sectionRailItem(section),
                                ),
                            ],
                          ],
                        ),
                      ),
                      Container(width: 1, color: const Color(0xFFE8DDCF)),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: SingleChildScrollView(
                            key: ValueKey(_selectedSection),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            child: rightPane,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionOptions(String section) {
    switch (section) {
      case 'Category':
        return _chipGrid(widget.availableCategories, _draft.categories, (next) {
          setState(() => _draft = _draft.copyWith(categories: next));
        });
      case 'Gender':
        return _chipGrid(
          _genders,
          _draft.gender == 'All' ? {} : {_draft.gender},
          (next) {
            setState(
              () => _draft = _draft.copyWith(
                gender: next.isEmpty ? 'All' : next.first,
              ),
            );
          },
          allowSingleSelection: true,
        );
      case 'Brand':
        return _brandPanel();
      case 'Price':
        return _pricePanel();
      case 'Size':
        return _chipGrid(widget.availableSizes, _draft.sizes, (next) {
          setState(() => _draft = _draft.copyWith(sizes: next));
        });
      case 'Color':
        return _colorPanel();
      case 'Occasion':
        return _chipGrid(_occasions, _draft.occasions, (next) {
          setState(() => _draft = _draft.copyWith(occasions: next));
        });
      case 'Delivery Time':
        return _chipGrid(_deliveryTimes, _draft.deliveryTimes, (next) {
          setState(() => _draft = _draft.copyWith(deliveryTimes: next));
        });
      case 'Fabric':
        return _chipGrid(_fabrics, _draft.fabrics, (next) {
          setState(() => _draft = _draft.copyWith(fabrics: next));
        });
      case 'Fit':
        return _chipGrid(_fits, _draft.fits, (next) {
          setState(() => _draft = _draft.copyWith(fits: next));
        });
      case 'Pattern':
        return _chipGrid(_patterns, _draft.patterns, (next) {
          setState(() => _draft = _draft.copyWith(patterns: next));
        });
      case 'Sleeve Type':
        return _chipGrid(_sleeves, _draft.sleeveTypes, (next) {
          setState(() => _draft = _draft.copyWith(sleeveTypes: next));
        });
      case 'Neck Type':
        return _chipGrid(_necks, _draft.neckTypes, (next) {
          setState(() => _draft = _draft.copyWith(neckTypes: next));
        });
      case 'Length':
        return _chipGrid(_lengths, _draft.lengths, (next) {
          setState(() => _draft = _draft.copyWith(lengths: next));
        });
      case 'Rating':
        return _ratingPanel();
      case 'Availability':
        return _availabilityPanel();
      case 'AR Try-On':
        return _togglePanel(
          title: 'AR Try-On',
          subtitle: 'Only show products ready for live virtual try-on.',
          value: _draft.arOnly,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(arOnly: value)),
        );
      case 'Try At Home':
        return _togglePanel(
          title: 'Try At Home',
          subtitle: 'Show styles that can be tried at home.',
          value: _draft.tryAtHomeAvailable,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(tryAtHomeAvailable: value),
          ),
        );
      case 'Customizable':
        return _togglePanel(
          title: 'Customizable',
          subtitle: 'Show made-to-order and tailorable pieces.',
          value: _draft.customizable,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(customizable: value)),
        );
      case 'Advanced Filters':
        return _advancedExpanded
            ? Text(
                'Choose a detail from the left panel to refine your edit.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF666666),
                  height: 1.45,
                ),
              )
            : _advancedTeaser();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _chipGrid(
    List<String> options,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged, {
    bool allowSingleSelection = false,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return _pill(
          option,
          selected: isSelected,
          onTap: () {
            final next = <String>{...selected};
            if (allowSingleSelection) {
              next
                ..clear()
                ..add(option);
            } else if (isSelected) {
              next.remove(option);
            } else {
              next.add(option);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }

  Widget _brandPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _brandSearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search brand',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE4DDD2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE4DDD2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFFC8A86B),
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _chipGrid(_filteredBrands, _draft.brands, (next) {
          setState(() => _draft = _draft.copyWith(brands: next));
        }),
      ],
    );
  }

  Widget _pricePanel() {
    final maxLabel = _draft.maxPrice >= 20000
        ? '₹20,000+'
        : '₹${_draft.maxPrice.toInt()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '₹${_draft.minPrice.toInt()} - $maxLabel',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(_draft.minPrice, _draft.maxPrice),
          min: 0,
          max: 20000,
          divisions: 40,
          activeColor: const Color(0xFFC8A86B),
          inactiveColor: const Color(0xFFE7E0D3),
          onChanged: (values) {
            setState(() {
              _draft = _draft.copyWith(
                minPrice: values.start,
                maxPrice: values.end,
              );
            });
          },
        ),
        const SizedBox(height: 12),
        _chipGrid(_pricePresets, _pricePresetSelection, (next) {
          final label = next.isEmpty ? '' : next.first;
          if (label == 'Luxury') {
            setState(() {
              _draft = _draft.copyWith(minPrice: 5000, maxPrice: 20000);
            });
            return;
          }
          if (label.startsWith('Under')) {
            final end =
                double.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            setState(() {
              _draft = _draft.copyWith(minPrice: 0, maxPrice: end);
            });
          }
        }, allowSingleSelection: true),
      ],
    );
  }

  Set<String> get _pricePresetSelection {
    if (_draft.minPrice >= 5000) {
      return {'Luxury'};
    }
    if (_draft.maxPrice < 20000) {
      return {'Under ₹${_draft.maxPrice.toInt()}'};
    }
    return {};
  }

  Widget _colorPanel() {
    final colorMap = <String, Color>{
      'Black': Colors.black,
      'White': Colors.white,
      'Ivory': const Color(0xFFF8F5EF),
      'Gold': const Color(0xFFC8A86B),
      'Red': const Color(0xFF8F1D2C),
      'Blue': const Color(0xFF243C66),
      'Green': const Color(0xFF355C45),
      'Brown': const Color(0xFF6B4F3A),
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colorMap.entries.map((entry) {
        final selected = _draft.colors.contains(entry.key);
        return InkWell(
          onTap: () {
            final next = {..._draft.colors};
            if (selected) {
              next.remove(entry.key);
            } else {
              next.add(entry.key);
            }
            setState(() => _draft = _draft.copyWith(colors: next));
          },
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.value,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF111111)
                        : const Color(0xFFD9CCB9),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: entry.key == 'White'
                    ? const Icon(Icons.circle_outlined, size: 16)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                entry.key,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF111111),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _ratingPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipGrid(
          const ['All', '4.0+', '4.5+'],
          {
            if (_draft.ratingThreshold > 0)
              '${_draft.ratingThreshold.toStringAsFixed(1)}+',
          },
          (next) {
            final value = next.isEmpty ? 'All' : next.first;
            setState(() {
              _draft = _draft.copyWith(
                ratingThreshold: value == 'All'
                    ? 0
                    : double.parse(value.replaceAll('+', '')),
              );
            });
          },
          allowSingleSelection: true,
        ),
        const SizedBox(height: 16),
        Text(
          'Minimum rating',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Slider(
          value: _draft.ratingThreshold.clamp(0, 5),
          min: 0,
          max: 5,
          divisions: 10,
          activeColor: const Color(0xFFC8A86B),
          onChanged: (value) {
            setState(() => _draft = _draft.copyWith(ratingThreshold: value));
          },
        ),
      ],
    );
  }

  Widget _availabilityPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _togglePanel(
          title: 'Hide Out Of Stock',
          subtitle: 'Remove items that cannot be purchased now.',
          value: _draft.hideOutOfStock,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(hideOutOfStock: value)),
        ),
        const SizedBox(height: 12),
        _togglePanel(
          title: 'Available In My Area',
          subtitle: 'Prioritize items that can be delivered locally.',
          value: _draft.availableInArea,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(availableInArea: value)),
        ),
        const SizedBox(height: 12),
        _togglePanel(
          title: 'Same-Day Delivery',
          subtitle: 'Show products that can arrive today.',
          value: _draft.sameDayDelivery,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(sameDayDelivery: value)),
        ),
        const SizedBox(height: 12),
        _togglePanel(
          title: 'Express Delivery',
          subtitle: 'Show faster delivery options.',
          value: _draft.expressDelivery,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(expressDelivery: value)),
        ),
        const SizedBox(height: 12),
        _togglePanel(
          title: 'Store Pickup',
          subtitle: 'Only show items with pickup support.',
          value: _draft.storePickup,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(storePickup: value)),
        ),
      ],
    );
  }

  Widget _togglePanel({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE3D5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFC8A86B),
          ),
        ],
      ),
    );
  }

  Widget _advancedTeaser() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE3D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Filters',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Fabric, fit, pattern, sleeve, neck, length, rating, availability, AR and custom options.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF666666),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => setState(() => _advancedExpanded = true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Open Advanced Filters'),
          ),
        ],
      ),
    );
  }

  static const List<String> _primarySections = [
    'Category',
    'Gender',
    'Brand',
    'Price',
    'Size',
    'Color',
    'Occasion',
    'Delivery Time',
  ];

  static const List<String> _advancedSections = [
    'Fabric',
    'Fit',
    'Pattern',
    'Sleeve Type',
    'Neck Type',
    'Length',
    'Rating',
    'Availability',
    'AR Try-On',
    'Try At Home',
    'Customizable',
  ];

  static const List<String> _genders = ['Men', 'Women', 'Unisex', 'Kids'];
  static const List<String> _occasions = [
    'Wedding',
    'Party',
    'Work',
    'Casual',
    'Festive',
  ];
  static const List<String> _deliveryTimes = [
    'Today',
    'Tomorrow',
    '2-3 Days',
    'Express',
    'Try at Home',
  ];
  static const List<String> _fabrics = [
    'Cotton',
    'Linen',
    'Silk',
    'Wool',
    'Leather',
    'Denim',
    'Chiffon',
    'Satin',
  ];
  static const List<String> _fits = [
    'Slim',
    'Regular',
    'Relaxed',
    'Oversized',
    'Tailored',
  ];
  static const List<String> _patterns = [
    'Solid',
    'Printed',
    'Striped',
    'Embroidered',
  ];
  static const List<String> _sleeves = [
    'Sleeveless',
    'Short Sleeve',
    'Full Sleeve',
  ];
  static const List<String> _necks = ['Round', 'V Neck', 'Collar', 'Boat'];
  static const List<String> _lengths = [
    'Cropped',
    'Regular',
    'Longline',
    'Floor',
  ];
  static const List<String> _pricePresets = [
    'Under ₹5,000',
    'Under ₹10,000',
    'Luxury',
  ];

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF171717),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6D6D6D),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _pill(String label, {bool selected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFC6A769).withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFFC6A769).withValues(alpha: 0.45)
                : const Color(0xFFE4DDD2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF7A5A21) : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildLuxuryFilterScaffold(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFE9E0D2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7D0C5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _sectionTitle(
                            'Filter Wishlist',
                            subtitle:
                                '${_draft.activeGroupCount} Filters Applied',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(
                              () => _draft = WishlistFilterState.defaults(),
                            );
                            widget.onClearAll();
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _sectionTitle('Price Range'),
                    const SizedBox(height: 10),
                    RangeSlider(
                      values: RangeValues(_draft.minPrice, _draft.maxPrice),
                      min: 0,
                      max: 20000,
                      divisions: 40,
                      labels: RangeLabels(
                        '₹${_draft.minPrice.toInt()}',
                        _draft.maxPrice >= 20000
                            ? '₹20,000+'
                            : '₹${_draft.maxPrice.toInt()}',
                      ),
                      activeColor: const Color(0xFFC6A769),
                      inactiveColor: const Color(0xFFE7E0D3),
                      onChanged: (values) {
                        setState(() {
                          _draft = _draft.copyWith(
                            minPrice: values.start,
                            maxPrice: values.end,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _priceStops
                              .map(
                                (value) => _pill(
                                  value >= 2000
                                      ? '₹2000+'
                                      : 'Under ₹${value.toInt()}',
                                  selected:
                                      _draft.minPrice == 0 &&
                                      (_draft.maxPrice >= value ||
                                          (_draft.maxPrice == 20000 &&
                                              value >= 20000)),
                                  onTap: () {
                                    setState(() {
                                      if (value >= 2000) {
                                        _draft = _draft.copyWith(
                                          minPrice: 2000,
                                          maxPrice: 20000,
                                        );
                                      } else {
                                        _draft = _draft.copyWith(
                                          minPrice: 0,
                                          maxPrice: value,
                                        );
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList()
                            ..add(
                              _pill(
                                'Luxury',
                                selected: _draft.minPrice >= 5000,
                                onTap: () {
                                  setState(() {
                                    _draft = _draft.copyWith(
                                      minPrice: 5000,
                                      maxPrice: 20000,
                                    );
                                  });
                                },
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Brand'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _brandSearch,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search Brand',
                        prefixIcon: const Icon(Icons.search_rounded),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4DDD2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4DDD2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFC6A769),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filteredBrands
                          .map(
                            (brand) => _pill(
                              brand,
                              selected: _draft.brands.contains(brand),
                              onTap: () {
                                setState(() {
                                  _draft = _draft.copyWith(
                                    brands: {..._draft.brands}..toggle(brand),
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Category'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableCategories
                          .map(
                            (category) => _pill(
                              category,
                              selected: _draft.categories.contains(category),
                              onTap: () {
                                setState(() {
                                  _draft = _draft.copyWith(
                                    categories: {..._draft.categories}
                                      ..toggle(category),
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('AR Try-On'),
                    const SizedBox(height: 8),
                    _ToggleCard(
                      title: 'Show only AR Available',
                      subtitle: 'Show products with a 3D try-on ready state.',
                      selected: _draft.arOnly,
                      onChanged: (value) {
                        setState(() => _draft = _draft.copyWith(arOnly: value));
                      },
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Delivery'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                          'Available In My Area',
                          selected: _draft.availableInArea,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(
                              availableInArea: !_draft.availableInArea,
                            ),
                          ),
                        ),
                        _pill(
                          'Same-Day Delivery',
                          selected: _draft.sameDayDelivery,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(
                              sameDayDelivery: !_draft.sameDayDelivery,
                            ),
                          ),
                        ),
                        _pill(
                          'Express Delivery',
                          selected: _draft.expressDelivery,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(
                              expressDelivery: !_draft.expressDelivery,
                            ),
                          ),
                        ),
                        _pill(
                          'Store Pickup Available',
                          selected: _draft.storePickup,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(
                              storePickup: !_draft.storePickup,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Discount'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [10, 20, 30, 50, 70]
                          .map(
                            (threshold) => _pill(
                              '$threshold%+ Off',
                              selected: _draft.discountThresholds.contains(
                                threshold,
                              ),
                              onTap: () {
                                setState(() {
                                  final next = {..._draft.discountThresholds};
                                  if (next.contains(threshold)) {
                                    next.remove(threshold);
                                  } else {
                                    next.add(threshold);
                                  }
                                  _draft = _draft.copyWith(
                                    discountThresholds: next,
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Stock'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                                'In Stock',
                                'Low Stock',
                                'Out Of Stock',
                                'Hide Out Of Stock',
                              ]
                              .map(
                                (label) => _pill(
                                  label,
                                  selected: _draft.stockFilters.contains(label),
                                  onTap: () {
                                    setState(() {
                                      final next = {..._draft.stockFilters};
                                      if (next.contains(label)) {
                                        next.remove(label);
                                      } else {
                                        next.add(label);
                                      }
                                      _draft = _draft.copyWith(
                                        stockFilters: next,
                                      );
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Seller'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                                'Verified Sellers',
                                'Premium Stores',
                                'Local Boutiques',
                                'Mall Brands',
                              ]
                              .map(
                                (label) => _pill(
                                  label,
                                  selected: _draft.sellerTypes.contains(label),
                                  onTap: () {
                                    setState(() {
                                      final next = {..._draft.sellerTypes};
                                      if (next.contains(label)) {
                                        next.remove(label);
                                      } else {
                                        next.add(label);
                                      }
                                      _draft = _draft.copyWith(
                                        sellerTypes: next,
                                      );
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Size'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableSizes
                          .map(
                            (size) => _pill(
                              size,
                              selected: _draft.sizes.contains(size),
                              onTap: () {
                                setState(() {
                                  _draft = _draft.copyWith(
                                    sizes: {..._draft.sizes}..toggle(size),
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Saved Filters'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                                'My Luxury Picks',
                                'My AR Favorites',
                                'Wedding Collection',
                              ]
                              .map(
                                (preset) => _pill(
                                  preset,
                                  selected: false,
                                  onTap: () {
                                    Navigator.of(context).pop(
                                      _presetForNameStatic(
                                        preset,
                                      ).apply(_draft),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Recommended For You'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                                'Trending Near You',
                                'Perfect For Wedding Season',
                                'Similar To Saved Items',
                                'AR Try-On Ready',
                              ]
                              .map(
                                (preset) => _pill(
                                  preset,
                                  selected: false,
                                  onTap: () {
                                    Navigator.of(context).pop(
                                      _presetForNameStatic(
                                        preset,
                                      ).apply(_draft),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 24),
                    SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE2D8C6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(_draft),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC6A769),
                                foregroundColor: const Color(0xFF111111),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static _WishlistPreset _presetForNameStatic(String name) {
    switch (name) {
      case 'My AR Favorites':
        return _WishlistPreset.arFavorites;
      case 'Wedding Collection':
        return _WishlistPreset.weddingCollection;
      case 'Trending Near You':
        return _WishlistPreset.trendingNearYou;
      case 'Perfect For Wedding Season':
        return _WishlistPreset.weddingSeason;
      case 'Similar To Saved Items':
        return _WishlistPreset.similarToSavedItems;
      case 'AR Try-On Ready':
        return _WishlistPreset.arTryOnReady;
      case 'My Luxury Picks':
      default:
        return _WishlistPreset.luxuryPicks;
    }
  }
}

class _WishlistSortSheet extends StatelessWidget {
  const _WishlistSortSheet({required this.initialSort});

  final WishlistSortOption initialSort;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.78,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFE9E0D2)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7D0C5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sort Wishlist',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 12),
              ...WishlistSortOption.values.map(
                (option) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    option == initialSort
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: option == initialSort
                        ? const Color(0xFFC6A769)
                        : const Color(0xFF8B8B8B),
                  ),
                  title: Text(option.label),
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WishlistCategorySheet extends StatelessWidget {
  const _WishlistCategorySheet({
    required this.initialCategories,
    required this.availableCategories,
  });

  final Set<String> initialCategories;
  final List<String> availableCategories;

  @override
  Widget build(BuildContext context) {
    final selected = {...initialCategories};
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.44,
      maxChildSize: 0.82,
      expand: false,
      builder: (context, scrollController) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: const Color(0xFFE9E0D2)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7D0C5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Filter Categories',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF151515),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories
                        .map(
                          (category) => FilterChip(
                            label: Text(category),
                            selected: selected.contains(category),
                            onSelected: (_) {
                              setModalState(() {
                                if (selected.contains(category)) {
                                  selected.remove(category);
                                } else {
                                  selected.add(category);
                                }
                              });
                            },
                            selectedColor: const Color(
                              0xFFC6A769,
                            ).withValues(alpha: 0.14),
                            labelStyle: TextStyle(
                              color: selected.contains(category)
                                  ? const Color(0xFF7A5A21)
                                  : const Color(0xFF555555),
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: selected.contains(category)
                                  ? const Color(
                                      0xFFC6A769,
                                    ).withValues(alpha: 0.35)
                                  : const Color(0xFFE4DDD2),
                            ),
                            backgroundColor: Colors.white,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(selected),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6A769),
                              foregroundColor: const Color(0xFF111111),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WishlistAvailabilitySheet extends StatelessWidget {
  const _WishlistAvailabilitySheet({required this.initialFilters});

  final WishlistFilterState initialFilters;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.42,
      maxChildSize: 0.78,
      expand: false,
      builder: (context, scrollController) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            var draft = initialFilters;
            void update(WishlistFilterState next) {
              setModalState(() => draft = next);
            }

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: const Color(0xFFE9E0D2)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7D0C5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Availability',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF151515),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ToggleCard(
                    title: 'AR Available',
                    subtitle: 'Only show items ready for virtual try-on.',
                    selected: draft.arOnly,
                    onChanged: (value) => update(draft.copyWith(arOnly: value)),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    title: 'Available In My Area',
                    subtitle: 'Prioritize items that can reach your location.',
                    selected: draft.availableInArea,
                    onChanged: (value) =>
                        update(draft.copyWith(availableInArea: value)),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    title: 'Same-Day Delivery',
                    subtitle: 'Focus on pieces that can arrive today.',
                    selected: draft.sameDayDelivery,
                    onChanged: (value) =>
                        update(draft.copyWith(sameDayDelivery: value)),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    title: 'Express Delivery',
                    subtitle: 'Prioritize faster shipping options.',
                    selected: draft.expressDelivery,
                    onChanged: (value) =>
                        update(draft.copyWith(expressDelivery: value)),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    title: 'Store Pickup Available',
                    subtitle: 'Only show products with pickup support.',
                    selected: draft.storePickup,
                    onChanged: (value) =>
                        update(draft.copyWith(storePickup: value)),
                  ),
                  const SizedBox(height: 20),
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(draft),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6A769),
                              foregroundColor: const Color(0xFF111111),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFC6A769).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFC6A769).withValues(alpha: 0.4)
                : const Color(0xFFE4DDD2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B6B6B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: selected,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFFC6A769),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.onTap,
    required this.aiStyle,
  });

  final String label;
  final VoidCallback onTap;
  final bool aiStyle;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: aiStyle ? const Color(0xFFF6F0E4) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: aiStyle
                ? const Color(0xFFC6A769).withValues(alpha: 0.28)
                : const Color(0xFFE3DCCF),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5F4A1E),
          ),
        ),
      ),
    );
  }
}

class _WishlistEmptyFilteredState extends StatelessWidget {
  const _WishlistEmptyFilteredState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AbzioEmptyCard(
              title: 'No items match your filters.',
              subtitle: 'Clear a few filters to bring your wishlist back.',
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Browse Wishlist'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxuryWishlistEmptyState extends StatelessWidget {
  const _LuxuryWishlistEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8DDCC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E0904),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF7E7), Color(0xFFF2DFC0)],
              ),
              border: Border.all(color: const Color(0xFFE1C98F)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: const [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 54,
                  color: Color(0xFF8E6E2F),
                ),
                Positioned(
                  right: 28,
                  top: 30,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFFC8A44D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your wishlist is empty',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF17130F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Save your favorite styles and find them here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF695F53),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF17130F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Continue Shopping'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistBagButton extends StatefulWidget {
  const _WishlistBagButton({required this.product, required this.selectedSize});

  final Product product;
  final String selectedSize;

  @override
  State<_WishlistBagButton> createState() => _WishlistBagButtonState();
}

class _WishlistBagButtonState extends State<_WishlistBagButton> {
  bool _justAdded = false;

  void _handleTap(BuildContext context, bool inBag) {
    if (inBag) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final size = widget.selectedSize.isNotEmpty ? widget.selectedSize : 'M';
    final result = cart.addToCart(widget.product, size);

    if (result == CartAddResult.storeConflict && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your bag already contains products from another store.',
          ),
        ),
      );
    } else if ((result == CartAddResult.added ||
            result == CartAddResult.updated) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to Bag')));
      setState(() => _justAdded = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _justAdded = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inBag = cart.items.any(
      (item) => item.product.id == widget.product.id,
    );
    final disabled = widget.product.stock <= 0;

    String label = 'Add to Bag';
    if (_justAdded) {
      label = '✓ Added';
    } else if (inBag) {
      label = 'View Bag';
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: disabled ? null : () => _handleTap(context, inBag),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF17130F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD8D0C5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            label,
            key: ValueKey(label),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _WishlistEntry {
  const _WishlistEntry({required this.item, required this.product});

  final WishlistItem item;
  final Product? product;
}

enum WishlistSortOption {
  relevance('Most Relevant'),
  recentlyAdded('Recently Added'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  highestDiscount('Highest Discount'),
  mostPopular('Most Popular'),
  trendingNow('Trending Now'),
  bestRated('Best Rated'),
  arTryOnFirst('AR Try-On First'),
  nearestStoreFirst('Nearest Store First'),
  fastestDelivery('Fastest Delivery');

  const WishlistSortOption(this.label);

  final String label;
}

class WishlistFilterState {
  const WishlistFilterState({
    this.minPrice = 0,
    this.maxPrice = 20000,
    this.brands = const <String>{},
    this.categories = const <String>{},
    this.sizes = const <String>{},
    this.gender = 'All',
    this.colors = const <String>{},
    this.occasions = const <String>{},
    this.deliveryTimes = const <String>{},
    this.fabrics = const <String>{},
    this.fits = const <String>{},
    this.patterns = const <String>{},
    this.sleeveTypes = const <String>{},
    this.neckTypes = const <String>{},
    this.lengths = const <String>{},
    this.sellerTypes = const <String>{},
    this.discountThresholds = const <int>{},
    this.stockFilters = const <String>{},
    this.arOnly = false,
    this.availableInArea = false,
    this.sameDayDelivery = false,
    this.expressDelivery = false,
    this.storePickup = false,
    this.hideOutOfStock = false,
    this.ratingThreshold = 0,
    this.tryAtHomeAvailable = false,
    this.customizable = false,
    this.sort = WishlistSortOption.relevance,
  });

  final double minPrice;
  final double maxPrice;
  final Set<String> brands;
  final Set<String> categories;
  final Set<String> sizes;
  final String gender;
  final Set<String> colors;
  final Set<String> occasions;
  final Set<String> deliveryTimes;
  final Set<String> fabrics;
  final Set<String> fits;
  final Set<String> patterns;
  final Set<String> sleeveTypes;
  final Set<String> neckTypes;
  final Set<String> lengths;
  final Set<String> sellerTypes;
  final Set<int> discountThresholds;
  final Set<String> stockFilters;
  final bool arOnly;
  final bool availableInArea;
  final bool sameDayDelivery;
  final bool expressDelivery;
  final bool storePickup;
  final bool hideOutOfStock;
  final double ratingThreshold;
  final bool tryAtHomeAvailable;
  final bool customizable;
  final WishlistSortOption sort;

  factory WishlistFilterState.defaults() => const WishlistFilterState();

  WishlistFilterState copyWith({
    double? minPrice,
    double? maxPrice,
    Set<String>? brands,
    Set<String>? categories,
    Set<String>? sizes,
    String? gender,
    Set<String>? colors,
    Set<String>? occasions,
    Set<String>? deliveryTimes,
    Set<String>? fabrics,
    Set<String>? fits,
    Set<String>? patterns,
    Set<String>? sleeveTypes,
    Set<String>? neckTypes,
    Set<String>? lengths,
    Set<String>? sellerTypes,
    Set<int>? discountThresholds,
    Set<String>? stockFilters,
    bool? arOnly,
    bool? availableInArea,
    bool? sameDayDelivery,
    bool? expressDelivery,
    bool? storePickup,
    bool? hideOutOfStock,
    double? ratingThreshold,
    bool? tryAtHomeAvailable,
    bool? customizable,
    WishlistSortOption? sort,
  }) {
    return WishlistFilterState(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      brands: brands ?? this.brands,
      categories: categories ?? this.categories,
      sizes: sizes ?? this.sizes,
      gender: gender ?? this.gender,
      colors: colors ?? this.colors,
      occasions: occasions ?? this.occasions,
      deliveryTimes: deliveryTimes ?? this.deliveryTimes,
      fabrics: fabrics ?? this.fabrics,
      fits: fits ?? this.fits,
      patterns: patterns ?? this.patterns,
      sleeveTypes: sleeveTypes ?? this.sleeveTypes,
      neckTypes: neckTypes ?? this.neckTypes,
      lengths: lengths ?? this.lengths,
      sellerTypes: sellerTypes ?? this.sellerTypes,
      discountThresholds: discountThresholds ?? this.discountThresholds,
      stockFilters: stockFilters ?? this.stockFilters,
      arOnly: arOnly ?? this.arOnly,
      availableInArea: availableInArea ?? this.availableInArea,
      sameDayDelivery: sameDayDelivery ?? this.sameDayDelivery,
      expressDelivery: expressDelivery ?? this.expressDelivery,
      storePickup: storePickup ?? this.storePickup,
      hideOutOfStock: hideOutOfStock ?? this.hideOutOfStock,
      ratingThreshold: ratingThreshold ?? this.ratingThreshold,
      tryAtHomeAvailable: tryAtHomeAvailable ?? this.tryAtHomeAvailable,
      customizable: customizable ?? this.customizable,
      sort: sort ?? this.sort,
    );
  }

  int get activeGroupCount {
    var count = 0;
    if (minPrice > 0 || maxPrice < 20000) count += 1;
    if (brands.isNotEmpty) count += 1;
    if (categories.isNotEmpty) count += 1;
    if (sizes.isNotEmpty) count += 1;
    if (gender != 'All') count += 1;
    if (colors.isNotEmpty) count += 1;
    if (occasions.isNotEmpty) count += 1;
    if (deliveryTimes.isNotEmpty) count += 1;
    if (fabrics.isNotEmpty) count += 1;
    if (fits.isNotEmpty) count += 1;
    if (patterns.isNotEmpty) count += 1;
    if (sleeveTypes.isNotEmpty) count += 1;
    if (neckTypes.isNotEmpty) count += 1;
    if (lengths.isNotEmpty) count += 1;
    if (sellerTypes.isNotEmpty) count += 1;
    if (discountThresholds.isNotEmpty) count += 1;
    if (stockFilters.isNotEmpty) count += 1;
    if (arOnly) count += 1;
    if (availableInArea) count += 1;
    if (sameDayDelivery) count += 1;
    if (expressDelivery) count += 1;
    if (storePickup) count += 1;
    if (hideOutOfStock) count += 1;
    if (ratingThreshold > 0) count += 1;
    if (tryAtHomeAvailable) count += 1;
    if (customizable) count += 1;
    return count;
  }

  Map<String, dynamic> toJson() => {
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'brands': brands.toList(),
    'categories': categories.toList(),
    'sizes': sizes.toList(),
    'gender': gender,
    'colors': colors.toList(),
    'occasions': occasions.toList(),
    'deliveryTimes': deliveryTimes.toList(),
    'fabrics': fabrics.toList(),
    'fits': fits.toList(),
    'patterns': patterns.toList(),
    'sleeveTypes': sleeveTypes.toList(),
    'neckTypes': neckTypes.toList(),
    'lengths': lengths.toList(),
    'sellerTypes': sellerTypes.toList(),
    'discountThresholds': discountThresholds.toList(),
    'stockFilters': stockFilters.toList(),
    'arOnly': arOnly,
    'availableInArea': availableInArea,
    'sameDayDelivery': sameDayDelivery,
    'expressDelivery': expressDelivery,
    'storePickup': storePickup,
    'hideOutOfStock': hideOutOfStock,
    'ratingThreshold': ratingThreshold,
    'tryAtHomeAvailable': tryAtHomeAvailable,
    'customizable': customizable,
    'sort': sort.name,
  };

  factory WishlistFilterState.fromJson(Map<String, dynamic> json) {
    WishlistSortOption sort = WishlistSortOption.relevance;
    final sortName = json['sort']?.toString() ?? '';
    for (final option in WishlistSortOption.values) {
      if (option.name == sortName) {
        sort = option;
        break;
      }
    }
    return WishlistFilterState(
      minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['maxPrice'] as num?)?.toDouble() ?? 20000,
      brands: Set<String>.from(json['brands'] ?? const []),
      categories: Set<String>.from(json['categories'] ?? const []),
      sizes: Set<String>.from(json['sizes'] ?? const []),
      gender: json['gender']?.toString() ?? 'All',
      colors: Set<String>.from(json['colors'] ?? const []),
      occasions: Set<String>.from(json['occasions'] ?? const []),
      deliveryTimes: Set<String>.from(json['deliveryTimes'] ?? const []),
      fabrics: Set<String>.from(json['fabrics'] ?? const []),
      fits: Set<String>.from(json['fits'] ?? const []),
      patterns: Set<String>.from(json['patterns'] ?? const []),
      sleeveTypes: Set<String>.from(json['sleeveTypes'] ?? const []),
      neckTypes: Set<String>.from(json['neckTypes'] ?? const []),
      lengths: Set<String>.from(json['lengths'] ?? const []),
      sellerTypes: Set<String>.from(json['sellerTypes'] ?? const []),
      discountThresholds: Set<int>.from(
        (json['discountThresholds'] as List? ?? const []).map(
          (item) => int.tryParse(item.toString()) ?? 0,
        ),
      ),
      stockFilters: Set<String>.from(json['stockFilters'] ?? const []),
      arOnly: json['arOnly'] == true,
      availableInArea: json['availableInArea'] == true,
      sameDayDelivery: json['sameDayDelivery'] == true,
      expressDelivery: json['expressDelivery'] == true,
      storePickup: json['storePickup'] == true,
      hideOutOfStock: json['hideOutOfStock'] == true,
      ratingThreshold: (json['ratingThreshold'] as num?)?.toDouble() ?? 0,
      tryAtHomeAvailable: json['tryAtHomeAvailable'] == true,
      customizable: json['customizable'] == true,
      sort: sort,
    );
  }
}

class _WishlistPreset {
  const _WishlistPreset._(this.label, this._apply);

  final String label;
  final WishlistFilterState Function(WishlistFilterState current) _apply;

  WishlistFilterState apply(WishlistFilterState current) => _apply(current);

  static const luxuryPicks = _WishlistPreset._(
    'My Luxury Picks',
    _luxuryPicksApply,
  );
  static const arFavorites = _WishlistPreset._(
    'My AR Favorites',
    _arFavoritesApply,
  );
  static const weddingCollection = _WishlistPreset._(
    'Wedding Collection',
    _weddingCollectionApply,
  );
  static const trendingNearYou = _WishlistPreset._(
    'Trending Near You',
    _trendingNearYouApply,
  );
  static const weddingSeason = _WishlistPreset._(
    'Perfect For Wedding Season',
    _weddingSeasonApply,
  );
  static const similarToSavedItems = _WishlistPreset._(
    'Similar To Saved Items',
    _similarToSavedItemsApply,
  );
  static const arTryOnReady = _WishlistPreset._(
    'AR Try-On Ready',
    _arTryOnReadyApply,
  );
}

WishlistFilterState _luxuryPicksApply(WishlistFilterState current) {
  return current.copyWith(
    minPrice: math.max(current.minPrice, 2000),
    maxPrice: 20000,
    ratingThreshold: math.max(current.ratingThreshold, 4.0),
    sort: WishlistSortOption.bestRated,
  );
}

WishlistFilterState _arFavoritesApply(WishlistFilterState current) {
  return current.copyWith(arOnly: true, sort: WishlistSortOption.arTryOnFirst);
}

WishlistFilterState _weddingCollectionApply(WishlistFilterState current) {
  return current.copyWith(
    categories: {...current.categories, 'Wedding Wear', 'Dresses', 'Shirts'},
    sort: WishlistSortOption.trendingNow,
  );
}

WishlistFilterState _trendingNearYouApply(WishlistFilterState current) {
  return current.copyWith(
    availableInArea: true,
    sameDayDelivery: true,
    sort: WishlistSortOption.nearestStoreFirst,
  );
}

WishlistFilterState _weddingSeasonApply(WishlistFilterState current) {
  return current.copyWith(
    categories: {...current.categories, 'Wedding Wear', 'Dresses', 'Jackets'},
    discountThresholds: {...current.discountThresholds, 20, 30},
  );
}

WishlistFilterState _similarToSavedItemsApply(WishlistFilterState current) {
  return current.copyWith(
    sort: WishlistSortOption.relevance,
    ratingThreshold: math.max(current.ratingThreshold, 3.8),
  );
}

WishlistFilterState _arTryOnReadyApply(WishlistFilterState current) {
  return current.copyWith(
    arOnly: true,
    sameDayDelivery: false,
    sort: WishlistSortOption.arTryOnFirst,
  );
}

const List<String> _categoryUniverse = [
  'Men',
  'Women',
  'Kids',
  'Footwear',
  'Accessories',
  'Shirts',
  'Dresses',
  'Jeans',
  'Jackets',
  'Wedding Wear',
];

extension<_T> on Set<_T> {
  Set<_T> toggle(_T value) {
    final next = {...this};
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }
}
