import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/wishlist_service.dart';

class WishlistProvider with ChangeNotifier {
  WishlistProvider({
    WishlistService? wishlistService,
  }) : _wishlistService = wishlistService ?? WishlistService();

  final WishlistService _wishlistService;
  StreamSubscription<List<WishlistItem>>? _subscription;

  String? _userId;
  final Map<String, WishlistItem> _cache = {};
  final Set<String> _pendingProductIds = {};
  final Map<String, Timer> _toggleDebounce = {};
  bool _isLoading = false;

  List<WishlistItem> get items {
    final values = _cache.values.toList();
    values.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return values;
  }

  bool get isLoading => _isLoading;

  bool isWishlisted(String productId) => _cache.containsKey(productId);

  bool isPending(String productId) => _pendingProductIds.contains(productId);

  void syncUser(AppUser? user) {
    final nextUserId = user?.id;
    if (_userId == nextUserId) {
      return;
    }
    _subscription?.cancel();
    _cache.clear();
    _pendingProductIds.clear();
    _userId = nextUserId;

    if (_userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    _subscription = _wishlistService.watchWishlist(_userId!).listen((items) {
      _cache
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.productId, item)));
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addToWishlist(Product product) async {
    final userId = _requireUserId();
    if (_cache.containsKey(product.id)) {
      return;
    }
    _pendingProductIds.add(product.id);
    _cache[product.id] = WishlistItem(
      productId: product.id,
      storeId: product.storeId,
      name: product.name,
      price: product.price,
      image: product.images.isEmpty ? '' : product.images.first,
      addedAt: DateTime.now(),
    );
    notifyListeners();
    try {
      await _wishlistService.addToWishlist(userId: userId, product: product);
    } catch (_) {
      _cache.remove(product.id);
      rethrow;
    } finally {
      _pendingProductIds.remove(product.id);
      notifyListeners();
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    final userId = _requireUserId();
    final existing = _cache[productId];
    _pendingProductIds.add(productId);
    _cache.remove(productId);
    notifyListeners();
    try {
      await _wishlistService.removeFromWishlist(userId: userId, productId: productId);
    } catch (_) {
      if (existing != null) {
        _cache[productId] = existing;
      }
      rethrow;
    } finally {
      _pendingProductIds.remove(productId);
      notifyListeners();
    }
  }

  Future<void> toggleWishlist(Product product) async {
    if (_toggleDebounce.containsKey(product.id)) {
      return;
    }
    _toggleDebounce[product.id] = Timer(
      const Duration(milliseconds: 280),
      () => _toggleDebounce.remove(product.id),
    );
    if (isWishlisted(product.id)) {
      await removeFromWishlist(product.id);
    } else {
      await addToWishlist(product);
    }
  }

  String _requireUserId() {
    if (_userId == null || _userId!.isEmpty) {
      throw StateError('Sign in to save products to your wishlist.');
    }
    return _userId!;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final timer in _toggleDebounce.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
