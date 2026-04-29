import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'location_provider.dart';

class ProductProvider with ChangeNotifier {
  ProductProvider({DatabaseService? databaseService})
    : _db = databaseService ?? DatabaseService();

  final DatabaseService _db;
  StreamSubscription<List<Product>>? _productsSubscription;
  bool _streamAttached = false;
  Timer? _streamDebounce;
  Timer? _locationNotifyDebounce;
  List<Product>? _pendingStreamProducts;

  LocationProvider? _locationProvider;
  AppUser? _currentUser;

  List<Store> _allStores = [];
  List<Product> _trendingProducts = [];
  List<Product> _searchResults = [];
  List<Product> _locationProducts = [];
  SearchFilter _searchFilter = const SearchFilter();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  bool _storesLoaded = false;
  String? _lastProductKey;

  List<Store> get featuredStores => _allStores;
  List<NearbyStore> get nearbyStores =>
      _locationProvider?.nearbyStores ?? const [];
  List<Product> get trendingProducts => _trendingProducts;
  List<Product> get searchResults => _searchResults;
  List<Product> get locationProducts => _locationProducts;
  SearchFilter get searchFilter => _searchFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLocationLoading => _locationProvider?.isLocationLoading ?? false;
  bool get hasMoreProducts => _hasMoreProducts;
  String get activeLocation => _locationProvider?.activeLocation ?? 'Chennai';
  double get radiusKm =>
      _locationProvider?.radiusKm ?? LocationProvider.defaultRadiusKm;
  Position? get userPosition => _locationProvider?.userPosition;
  String? get locationErrorMessage => _locationProvider?.locationErrorMessage;
  LocationStatus? get locationStatus => _locationProvider?.locationStatus;
  bool get locationPermissionBlocked =>
      _locationProvider?.locationPermissionBlocked ?? false;
  bool get locationServiceDisabled =>
      _locationProvider?.locationServiceDisabled ?? false;
  String get locationDisplayAddress => _locationProvider?.displayAddress ?? '';
  bool get usingNearestStoreFallback =>
      _locationProvider?.isUsingNearestFallback ?? false;

  void attachLocationProvider(LocationProvider provider) {
    if (identical(_locationProvider, provider)) {
      return;
    }
    _locationProvider?.removeListener(_handleLocationChanged);
    _locationProvider = provider;
    _locationProvider?.addListener(_handleLocationChanged);
  }

  Future<void> fetchHomeData({
    bool forceStoreReload = false,
    bool forceLocationRefresh = false,
    AppUser? user,
  }) async {
    _currentUser = user ?? _currentUser;
    final previousStores = _allStores;
    final previousTrending = _trendingProducts;
    final previousSearch = _searchResults;
    final previousLocationProducts = _locationProducts;
    _isLoading = true;
    _lastProductKey = null;
    _hasMoreProducts = true;
    _locationProducts = [];
    notifyListeners();

    try {
      if (!_storesLoaded || forceStoreReload) {
        try {
          _allStores = await _db.getStores();
          _storesLoaded = true;
        } catch (error) {
          debugPrint(
            'Store fetch failed, continuing with product fallback: $error',
          );
          if (_allStores.isEmpty) {
            _allStores = previousStores;
          }
        }
      }

      _locationProvider?.updateStores(_allStores, notify: false);
      if (_locationProvider != null) {
        await _locationProvider!.bootstrap(
          stores: _allStores,
          user: _currentUser,
          forceRefresh: forceLocationRefresh,
        );
      }

      await _loadNextPageInternal(resetSearch: true);
      if (_locationProducts.isEmpty) {
        await _loadGenericCatalogFallback(resetSearch: true);
      }
      if (_locationProducts.isEmpty && previousLocationProducts.isNotEmpty) {
        _locationProducts = previousLocationProducts;
        _trendingProducts = _locationProducts.take(10).toList();
        _searchResults = _applyFilter(_locationProducts, _searchFilter);
        _hasMoreProducts = true;
      }
      debugPrint(
        'Home data ready: stores=${_allStores.length}, nearby=${nearbyStores.length}, products=${_locationProducts.length}',
      );
      if (!_streamAttached) {
        _productsSubscription?.cancel();
        _productsSubscription = _db.watchAllProducts().listen(
          (products) {
            _pendingStreamProducts = products;
            _streamDebounce?.cancel();
            _streamDebounce = Timer(
              const Duration(milliseconds: 320),
              () async {
                  try {
                    final buffered = _pendingStreamProducts ?? const <Product>[];
                    final storeIds = _activeNearbyStoreIds();
                    final liveProducts = storeIds.isEmpty
                        ? buffered
                        : buffered
                            .where((item) => storeIds.contains(item.storeId))
                            .toList();
                    final ranked = await _safePersonalize(
                      liveProducts.isEmpty ? buffered : liveProducts,
                    );
                    _trendingProducts = ranked.take(10).toList();
                    _searchResults = _applyFilter(ranked, _searchFilter);
                    notifyListeners();
                } catch (error) {
                  debugPrint('Realtime personalization fallback: $error');
                }
              },
            );
          },
          onError: (error) {
            debugPrint('Realtime product stream error: $error');
            notifyListeners();
          },
        );
        _streamAttached = true;
      }
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('permission-denied')) {
        debugPrint(
          'Optional product data unavailable for ${_currentUser?.id ?? 'guest'}. Falling back to empty storefront sections.',
        );
      } else {
        debugPrint('Error fetching data: $error');
      }
      _allStores = _allStores.isNotEmpty ? _allStores : previousStores;
      _trendingProducts = previousTrending;
      _searchResults = previousSearch;
      _locationProducts = previousLocationProducts;
      _hasMoreProducts = true;
      if (_locationProducts.isEmpty) {
        try {
          await _loadGenericCatalogFallback(resetSearch: true);
        } catch (fallbackError) {
          debugPrint('Generic catalog fallback failed: $fallbackError');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setRadiusKm(double radiusKm) async {
    await _locationProvider?.setRadiusKm(radiusKm);
    await _reloadProductsForLocation();
  }

  Future<void> setManualLocation(String city) async {
    await _locationProvider?.setManualLocation(city, user: _currentUser);
    await _reloadProductsForLocation();
  }

  Future<void> requestLocationAccess() async {
    await _locationProvider?.requestLocationAccess(user: _currentUser);
    await _reloadProductsForLocation();
  }

  Future<void> applySavedUserLocation(AppUser? user) async {
    _currentUser = user;
    if (_locationProvider == null) {
      return;
    }
    await _locationProvider!.bootstrap(
      stores: _allStores,
      user: user,
      forceRefresh: false,
    );
    await _reloadProductsForLocation();
  }

  Future<void> loadMoreLocationProducts() async {
    if (_isLoading || _isLoadingMore || !_hasMoreProducts) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _loadNextPageInternal(resetSearch: false);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _reloadProductsForLocation() async {
    _lastProductKey = null;
    _locationProducts = [];
    _hasMoreProducts = true;
    await _loadNextPageInternal(resetSearch: true);
    notifyListeners();
  }

  Future<void> _loadNextPageInternal({required bool resetSearch}) async {
    final targetStoreIds = _activeNearbyStoreIds();
    final newlyMatched = <Product>[];
    var guard = 0;
    var hasMore = _hasMoreProducts;
    while (newlyMatched.length < 12 && hasMore && guard < 5) {
      guard += 1;
      try {
        final page = await _db.getProductsPage(
          limit: 25,
          startAfterKey: _lastProductKey,
        );
        _lastProductKey = page.lastKey;
        hasMore = page.hasMore;
        final filteredMatches = targetStoreIds.isEmpty
            ? page.items
            : page.items
                .where((product) => targetStoreIds.contains(product.storeId))
                .toList();
        final pageMatches = filteredMatches.isEmpty
            ? page.items
            : filteredMatches;
        newlyMatched.addAll(pageMatches);
        if (page.items.isEmpty) {
          hasMore = false;
        }
      } catch (error) {
        debugPrint('Products page load failed in loop: $error');
        break;
      }
    }
    if (newlyMatched.isEmpty) {
      try {
        final streamFallback = await _db.watchAllProducts().first.timeout(
              const Duration(seconds: 6),
            );
        if (streamFallback.isNotEmpty) {
          final filtered = targetStoreIds.isEmpty
              ? streamFallback
              : streamFallback
                  .where((product) => targetStoreIds.contains(product.storeId))
                  .toList();
          newlyMatched.addAll(filtered.isEmpty ? streamFallback : filtered);
        }
      } catch (error) {
        debugPrint('Stream fallback unavailable in page loader: $error');
      }
    }

    _hasMoreProducts = hasMore;
    final merged = _mergeUniqueProducts(_locationProducts, newlyMatched);
    _locationProducts = await _safePersonalize(merged);
    _trendingProducts = _locationProducts.take(10).toList();
    if (resetSearch) {
      _searchResults = _applyFilter(_locationProducts, _searchFilter);
    }
    debugPrint(
      'Products page merged: incoming=${newlyMatched.length}, total=${_locationProducts.length}, hasMore=$_hasMoreProducts',
    );
  }

  Future<void> _loadGenericCatalogFallback({required bool resetSearch}) async {
    try {
      final page = await _db.getProductsPage(limit: 25);
      final base = page.items;
      if (base.isNotEmpty) {
        _locationProducts = await _safePersonalize(base);
        _trendingProducts = _locationProducts.take(10).toList();
        if (resetSearch) {
          _searchResults = _applyFilter(_locationProducts, _searchFilter);
        }
        _hasMoreProducts = page.hasMore;
        _lastProductKey = page.lastKey;
        return;
      }
    } catch (error) {
      debugPrint('Catalog page fallback failed: $error');
    }

    try {
      final streamProducts = await _db.watchAllProducts().first.timeout(
            const Duration(seconds: 6),
          );
      if (streamProducts.isNotEmpty) {
        _locationProducts = await _safePersonalize(streamProducts);
        _trendingProducts = _locationProducts.take(10).toList();
        if (resetSearch) {
          _searchResults = _applyFilter(_locationProducts, _searchFilter);
        }
        _hasMoreProducts = false;
      }
    } catch (error) {
      debugPrint('Stream fallback failed: $error');
    }
  }

  Future<List<Product>> _safePersonalize(List<Product> products) async {
    if (products.isEmpty) {
      return const <Product>[];
    }
    try {
      return await _db.personalizeProductsForUser(products, user: _currentUser);
    } catch (error) {
      final text = error.toString().toLowerCase();
      final isAuthFallback =
          text.contains('unauthorized') ||
          text.contains('sign in again') ||
          text.contains('session expired') ||
          text.contains('too many authentication requests');
      if (!isAuthFallback) {
        debugPrint('Personalization unavailable, showing base products: $error');
      }
      return products;
    }
  }

  List<Product> _mergeUniqueProducts(
    List<Product> current,
    List<Product> incoming,
  ) {
    if (current.isEmpty) {
      return incoming.toList();
    }
    if (incoming.isEmpty) {
      return current.toList();
    }
    final seen = <String>{};
    final merged = <Product>[];
    for (final product in [...current, ...incoming]) {
      if (seen.add(product.id)) {
        merged.add(product);
      }
    }
    return merged;
  }

  Set<String> _activeNearbyStoreIds() {
    final nearby = _locationProvider?.nearbyStores ?? const <NearbyStore>[];
    if (nearby.isNotEmpty) {
      return nearby.map((item) => item.store.id).toSet();
    }
    return _allStores.map((store) => store.id).toSet();
  }

  Future<List<Product>> getStoreProducts(String storeId) async {
    return _db.getProductsByStore(storeId);
  }

  Future<void> searchCatalog([SearchFilter? filter]) async {
    _isLoading = true;
    if (filter != null) {
      _searchFilter = filter;
    }
    notifyListeners();
    _searchResults = _applyFilter(_locationProducts, _searchFilter);
    _isLoading = false;
    notifyListeners();
  }

  List<Product> _applyFilter(List<Product> products, SearchFilter filter) {
    final filtered = products
        .where(
          (product) =>
              product.effectivePrice >= filter.priceRange.start &&
              product.effectivePrice <= filter.priceRange.end,
        )
        .where(
          (product) =>
              filter.category == 'All' || product.category == filter.category,
        )
        .where(
          (product) =>
              filter.storeId == 'All' || product.storeId == filter.storeId,
        )
        .where(
          (product) =>
              filter.gender == 'All' ||
              _productGender(product).toLowerCase() ==
                  filter.gender.toLowerCase(),
        )
        .where(
          (product) =>
              filter.size == 'All' ||
              product.sizes
                  .map((size) => size.toUpperCase())
                  .contains(filter.size.toUpperCase()),
        )
        .where(
          (product) =>
              filter.color == 'All' ||
              _productColors(product)
                  .map((color) => color.toLowerCase())
                  .contains(filter.color.toLowerCase()),
        )
        .where(
          (product) =>
              filter.brand == 'All' ||
              product.brand.toLowerCase() == filter.brand.toLowerCase(),
        )
        .where((product) => !filter.sameDayAvailable || _sameDayAvailable(product))
        .where(
          (product) =>
              !filter.tryAtHomeAvailable || _tryAtHomeAvailable(product),
        )
        .where((product) => !filter.customizable || _customizable(product))
        .where(
          (product) =>
              filter.deliveryTime == 'All' ||
              _deliveryTime(product).toLowerCase() ==
                  filter.deliveryTime.toLowerCase(),
        )
        .where(
          (product) =>
              filter.fitConfidence == 'All' ||
              _fitConfidenceLabel(product) == filter.fitConfidence.toLowerCase(),
        )
        .where(
          (product) =>
              filter.returnRisk == 'All' ||
              _returnRisk(product) == filter.returnRisk.toLowerCase(),
        )
        .where((product) => product.rating >= filter.minRating)
        .where(
          (product) =>
              filter.occasion == 'All' ||
              _occasionFor(product) == filter.occasion,
        )
        .where((product) {
          final query = filter.query.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return '${product.name} ${product.description} ${product.category}'
              .toLowerCase()
              .contains(query);
        })
        .toList();
    filtered.sort((a, b) {
      switch (filter.sort) {
        case ProductSortOption.priceLowToHigh:
          return a.effectivePrice.compareTo(b.effectivePrice);
        case ProductSortOption.priceHighToLow:
          return b.effectivePrice.compareTo(a.effectivePrice);
        case ProductSortOption.newest:
          final aDate = DateTime.tryParse(a.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        case ProductSortOption.popularity:
          return _popularityScore(b).compareTo(_popularityScore(a));
        case ProductSortOption.sameDayPriority:
          final aSameDay = _sameDayAvailable(a);
          final bSameDay = _sameDayAvailable(b);
          if (aSameDay != bSameDay) {
            return aSameDay ? -1 : 1;
          }
          return _popularityScore(b).compareTo(_popularityScore(a));
        case ProductSortOption.relevance:
          return _relevanceScore(b).compareTo(_relevanceScore(a));
      }
    });
    return filtered;
  }

  String _productGender(Product product) {
    final raw =
        product.attributes['gender'] ??
        product.attributes['targetGender'] ??
        product.category;
    final normalized = raw.toLowerCase();
    if (normalized.contains('women') || normalized.contains('lady')) {
      return 'women';
    }
    if (normalized.contains('men') || normalized.contains('male')) {
      return 'men';
    }
    return 'unisex';
  }

  List<String> _productColors(Product product) {
    final raw =
        product.attributes['color'] ??
        product.attributes['colors'] ??
        '';
    if (raw.trim().isEmpty) {
      return const [];
    }
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _sameDayAvailable(Product product) {
    final raw =
        product.attributes['sameDayAvailable'] ??
        product.attributes['sameDayEligible'] ??
        '';
    return raw.toLowerCase() == 'true' || raw == '1';
  }

  bool _tryAtHomeAvailable(Product product) {
    final raw = product.attributes['tryAtHomeAvailable'] ?? '';
    return raw.toLowerCase() == 'true' || raw == '1';
  }

  bool _customizable(Product product) {
    if (product.isCustomTailoring) {
      return true;
    }
    final raw =
        product.attributes['customizable'] ??
        product.attributes['atelierEnabled'] ??
        '';
    return raw.toLowerCase() == 'true' || raw == '1';
  }

  String _deliveryTime(Product product) {
    final raw = (product.attributes['deliveryTime'] ?? '').toLowerCase().trim();
    if (raw == 'today' || raw == 'tomorrow' || raw == '2-3 days') {
      return raw;
    }
    return _sameDayAvailable(product) ? 'today' : '2-3 days';
  }

  String _fitConfidenceLabel(Product product) {
    final raw =
        (product.attributes['fitConfidenceLabel'] ?? '').toLowerCase().trim();
    if (raw == 'high' || raw == 'medium' || raw == 'low') {
      return raw;
    }
    final rating = product.rating;
    if (rating >= 4.2) return 'high';
    if (rating >= 3.6) return 'medium';
    return 'low';
  }

  String _returnRisk(Product product) {
    final raw = (product.attributes['returnRisk'] ?? '').toLowerCase().trim();
    if (raw == 'high' || raw == 'low') {
      return raw;
    }
    return product.rating >= 4 ? 'low' : 'high';
  }

  int _popularityScore(Product product) {
    return (product.demandScore * 100).round() +
        (product.purchaseCount * 4) +
        (product.viewCount ~/ 2);
  }

  int _relevanceScore(Product product) {
    var score = 0;
    if (_sameDayAvailable(product)) score += 35;
    if (_fitConfidenceLabel(product) == 'high') score += 20;
    score += (product.rating * 10).round();
    score += _popularityScore(product);
    return score;
  }

  String _occasionFor(Product product) {
    final text = '${product.name} ${product.description} ${product.category}'
        .toLowerCase();
    if (text.contains('wedding') ||
        text.contains('sherwani') ||
        text.contains('tuxedo')) {
      return 'Wedding';
    }
    if (text.contains('formal') ||
        text.contains('office') ||
        text.contains('blazer')) {
      return 'Formal';
    }
    if (text.contains('party') || text.contains('evening')) {
      return 'Party';
    }
    return 'Everyday';
  }

  void _handleLocationChanged() {
    if (_locationNotifyDebounce?.isActive ?? false) {
      return;
    }
    _locationNotifyDebounce = Timer(const Duration(milliseconds: 90), () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _streamDebounce?.cancel();
    _locationNotifyDebounce?.cancel();
    _locationProvider?.removeListener(_handleLocationChanged);
    super.dispose();
  }
}
