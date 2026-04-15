import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'location_provider.dart';

class ProductProvider with ChangeNotifier {
  ProductProvider({
    DatabaseService? databaseService,
  }) : _db = databaseService ?? DatabaseService();

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
  List<NearbyStore> get nearbyStores => _locationProvider?.nearbyStores ?? const [];
  List<Product> get trendingProducts => _trendingProducts;
  List<Product> get searchResults => _searchResults;
  List<Product> get locationProducts => _locationProducts;
  SearchFilter get searchFilter => _searchFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLocationLoading => _locationProvider?.isLocationLoading ?? false;
  bool get hasMoreProducts => _hasMoreProducts;
  String get activeLocation => _locationProvider?.activeLocation ?? 'Chennai';
  double get radiusKm => _locationProvider?.radiusKm ?? LocationProvider.defaultRadiusKm;
  Position? get userPosition => _locationProvider?.userPosition;
  String? get locationErrorMessage => _locationProvider?.locationErrorMessage;
  LocationStatus? get locationStatus => _locationProvider?.locationStatus;
  bool get locationPermissionBlocked => _locationProvider?.locationPermissionBlocked ?? false;
  bool get locationServiceDisabled => _locationProvider?.locationServiceDisabled ?? false;
  String get locationDisplayAddress => _locationProvider?.displayAddress ?? '';
  bool get usingNearestStoreFallback => _locationProvider?.isUsingNearestFallback ?? false;

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
    _isLoading = true;
    _lastProductKey = null;
    _hasMoreProducts = true;
    _locationProducts = [];
    notifyListeners();

    try {
      if (!_storesLoaded || forceStoreReload) {
        _allStores = await _db.getStores();
        _storesLoaded = true;
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
      if (!_streamAttached) {
        _productsSubscription?.cancel();
        _productsSubscription = _db.watchAllProducts().listen(
          (products) {
            _pendingStreamProducts = products;
            _streamDebounce?.cancel();
            _streamDebounce = Timer(const Duration(milliseconds: 320), () async {
              try {
                final buffered = _pendingStreamProducts ?? const <Product>[];
                final storeIds = _activeNearbyStoreIds();
                final liveProducts = buffered
                    .where((item) => storeIds.contains(item.storeId))
                    .toList();
                final ranked = await _db.personalizeProductsForUser(
                  liveProducts,
                  user: _currentUser,
                );
                _trendingProducts = ranked.take(10).toList();
                _searchResults = _applyFilter(ranked, _searchFilter);
                notifyListeners();
              } catch (error) {
                debugPrint('Realtime personalization fallback: $error');
              }
            });
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
        debugPrint('Optional product data unavailable for ${_currentUser?.id ?? 'guest'}. Falling back to empty storefront sections.');
      } else {
        debugPrint('Error fetching data: $error');
      }
      _allStores = [];
      _trendingProducts = [];
      _searchResults = [];
      _locationProducts = [];
      _hasMoreProducts = false;
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
    if (targetStoreIds.isEmpty) {
      _hasMoreProducts = false;
      _locationProducts = [];
      _trendingProducts = [];
      if (resetSearch) {
        _searchResults = [];
      }
      return;
    }

    final newlyMatched = <Product>[];
    var guard = 0;
    var hasMore = _hasMoreProducts;
    while (newlyMatched.length < 12 && hasMore && guard < 5) {
      guard += 1;
      final page = await _db.getProductsPage(limit: 25, startAfterKey: _lastProductKey);
      _lastProductKey = page.lastKey;
      hasMore = page.hasMore;
      final pageMatches = page.items.where((product) => targetStoreIds.contains(product.storeId)).toList();
      newlyMatched.addAll(pageMatches);
      if (page.items.isEmpty) {
        hasMore = false;
      }
    }

    _hasMoreProducts = hasMore;
    _locationProducts = await _db.personalizeProductsForUser(
      [..._locationProducts, ...newlyMatched],
      user: _currentUser,
    );
    _trendingProducts = _locationProducts.take(10).toList();
    if (resetSearch) {
      _searchResults = _applyFilter(_locationProducts, _searchFilter);
    }
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
              product.effectivePrice >= filter.priceRange.start && product.effectivePrice <= filter.priceRange.end,
        )
        .where((product) => filter.category == 'All' || product.category == filter.category)
        .where((product) => filter.storeId == 'All' || product.storeId == filter.storeId)
        .where((product) => filter.occasion == 'All' || _occasionFor(product) == filter.occasion)
        .where((product) {
          final query = filter.query.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return '${product.name} ${product.description} ${product.category}'.toLowerCase().contains(query);
        })
        .toList();
    filtered.sort((a, b) => b.rating.compareTo(a.rating));
    return filtered;
  }

  String _occasionFor(Product product) {
    final text = '${product.name} ${product.description} ${product.category}'.toLowerCase();
    if (text.contains('wedding') || text.contains('sherwani') || text.contains('tuxedo')) {
      return 'Wedding';
    }
    if (text.contains('formal') || text.contains('office') || text.contains('blazer')) {
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
