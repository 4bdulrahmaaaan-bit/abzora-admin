import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/backend_commerce_service.dart';
import '../services/database_service.dart';

class CartItem {
  final Product product;
  final String size;
  int quantity;

  CartItem({
    required this.product,
    required this.size,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() => {
        'product': product.toMap(),
        'productId': product.id,
        'size': size,
        'quantity': quantity,
      };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final productMap = Map<String, dynamic>.from((map['product'] as Map?) ?? const {});
    final productId = (map['productId'] ?? productMap['id'] ?? '').toString();
    if (productId.isNotEmpty) {
      productMap['id'] = productId;
    }
    return CartItem(
      product: Product.fromMap(productMap, productId),
      size: (map['size'] ?? '').toString(),
      quantity: ((map['quantity'] ?? 1) as num).toInt(),
    );
  }
}

enum CartAddResult {
  added,
  updated,
  storeConflict,
}

class CartProvider with ChangeNotifier {
  CartProvider({DatabaseService? databaseService}) : _db = databaseService ?? DatabaseService() {
    unawaited(_restoreCart());
  }

  final DatabaseService _db;
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  static const String _cartStorageKey = 'abzora_local_cart_v1';
  final List<CartItem> _items = [];
  String? _appliedCoupon;
  double _discountPercentage = 0.0;
  double _fixedDiscountAmount = 0.0;
  DateTime? _lastInteractionAt;
  String? _syncedUserId;
  bool _syncingRemoteCart = false;

  List<CartItem> get items => _items;
  String? get appliedCoupon => _appliedCoupon;
  double get discountPercentage => _discountPercentage;
  double get fixedDiscountAmount => _fixedDiscountAmount;
  DateTime? get lastInteractionAt => _lastInteractionAt;
  List<CartItem> get customTailoringItems => _items.where((item) => item.product.isCustomTailoring).toList();
  bool get hasCustomTailoring => customTailoringItems.isNotEmpty;
  bool get isAbandonedCandidate => _items.isNotEmpty && _lastInteractionAt != null;

  double get subtotal => _items.fold(0, (sum, item) => sum + (item.product.effectivePrice * item.quantity));
  double get customTailoringCharges =>
      _items.fold(0, (sum, item) => sum + (item.product.tailoringExtraCost * item.quantity));
  double get discountAmount => min(subtotal, (subtotal * _discountPercentage) + _fixedDiscountAmount);
  double get totalAmount => subtotal - discountAmount;

  String? get activeStoreId => _items.isEmpty ? null : _items.first.product.storeId;

  Future<void> _restoreCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cartStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final restoredItems = decoded
          .whereType<Map>()
          .map((entry) => CartItem.fromMap(Map<String, dynamic>.from(entry)))
          .where((item) => item.product.id.isNotEmpty)
          .toList();
      _items
        ..clear()
        ..addAll(restoredItems);
      notifyListeners();
    } catch (_) {
      // Ignore local cart restore failures and continue with an empty cart.
    }
  }

  Future<void> _persistCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_items.map((item) => item.toMap()).toList());
      await prefs.setString(_cartStorageKey, payload);
      if (_backendCommerce.isConfigured && _syncedUserId != null && !_syncingRemoteCart) {
        await _backendCommerce.saveCartItems(_items.map((item) => item.toMap()).toList());
      }
    } catch (_) {
      // Keep cart UX responsive even if local persistence fails.
    }
  }

  Future<void> syncUser(AppUser? user) async {
    final nextUserId = user?.id;
    if (nextUserId == null || nextUserId.isEmpty) {
      _syncedUserId = null;
      return;
    }
    if (_syncedUserId == nextUserId) {
      return;
    }
    _syncedUserId = nextUserId;
    if (!_backendCommerce.isConfigured) {
      return;
    }
    _syncingRemoteCart = true;
    try {
      final remoteItems = await _backendCommerce.getSavedCartItems();
      if (remoteItems.isEmpty) {
        if (_items.isNotEmpty) {
          await _backendCommerce.saveCartItems(_items.map((item) => item.toMap()).toList());
        }
        return;
      }
      final restoredItems = remoteItems
          .map(CartItem.fromMap)
          .where((item) => item.product.id.isNotEmpty)
          .toList();
      _items
        ..clear()
        ..addAll(restoredItems);
      await _persistCart();
      notifyListeners();
    } catch (_) {
      // Fall back to local cart if backend cart sync is unavailable.
    } finally {
      _syncingRemoteCart = false;
    }
  }

  List<OrderItem> _asOrderItems() {
    return _items
        .map(
          (item) => OrderItem(
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity,
            price: item.product.effectivePrice,
            size: item.size,
            imageUrl: item.product.images.isNotEmpty ? item.product.images.first : '',
            isCustomTailoring: item.product.isCustomTailoring,
          ),
        )
        .toList();
  }

  Future<void> _recordProductCartIntentSafely(Product product, {int quantity = 1}) async {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      await _db.recordProductCartIntent(product, quantity: quantity);
    } catch (_) {
      // Cart interactions should remain usable even when analytics/realtime
      // services are unavailable during tests or early bootstrap.
    }
  }

  Future<void> _track(String action) async {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return;
      }
      final user = await _db.getUser(userId);
      if (user == null) {
        return;
      }
      unawaited(
        _db.trackCartActivity(
          user: user,
          items: _asOrderItems(),
          action: action,
        ),
      );
    } catch (_) {
      // Ignore tracking failures so cart UX is not blocked by auth/bootstrap.
    }
  }

  CartAddResult addToCart(Product product, String size) {
    if (_items.isNotEmpty && _items.first.product.storeId != product.storeId) {
      return CartAddResult.storeConflict;
    }

    final existingIndex = _items.indexWhere((item) => item.product.id == product.id && item.size == size);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
      _lastInteractionAt = DateTime.now();
      unawaited(_recordProductCartIntentSafely(product));
      unawaited(_track('updated'));
      unawaited(_persistCart());
      notifyListeners();
      return CartAddResult.updated;
    } else {
      _items.add(CartItem(product: product, size: size));
      _lastInteractionAt = DateTime.now();
      unawaited(_recordProductCartIntentSafely(product));
      unawaited(_track('added'));
      unawaited(_persistCart());
      notifyListeners();
      return CartAddResult.added;
    }
  }

  void updateQuantity(String productId, String size, int delta) {
    final index = _items.indexWhere((item) => item.product.id == productId && item.size == size);
    if (index >= 0) {
      _items[index].quantity += delta;
      if (delta > 0) {
        unawaited(_recordProductCartIntentSafely(_items[index].product, quantity: delta));
      }
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      _lastInteractionAt = DateTime.now();
      unawaited(_track('quantity_changed'));
      unawaited(_persistCart());
      notifyListeners();
    }
  }

  bool applyCoupon(
    String code, {
    double? discountPercentage,
    double? fixedDiscountAmount,
  }) {
    if (discountPercentage != null || fixedDiscountAmount != null) {
      _appliedCoupon = code.toUpperCase();
      _discountPercentage = discountPercentage ?? 0.0;
      _fixedDiscountAmount = fixedDiscountAmount ?? 0.0;
      _lastInteractionAt = DateTime.now();
      unawaited(_track('coupon_applied'));
      unawaited(_persistCart());
      notifyListeners();
      return true;
    }
    if (code.toUpperCase() == 'ELITE20') {
      _appliedCoupon = code.toUpperCase();
      _discountPercentage = 0.20;
      _fixedDiscountAmount = 0.0;
      _lastInteractionAt = DateTime.now();
      unawaited(_track('coupon_applied'));
      unawaited(_persistCart());
      notifyListeners();
      return true;
    }
    if (code.toUpperCase() == 'ABZORA10') {
      _appliedCoupon = code.toUpperCase();
      _discountPercentage = 0.10;
      _fixedDiscountAmount = 0.0;
      _lastInteractionAt = DateTime.now();
      unawaited(_track('coupon_applied'));
      unawaited(_persistCart());
      notifyListeners();
      return true;
    }
    return false;
  }

  void removeCoupon() {
    _appliedCoupon = null;
    _discountPercentage = 0.0;
    _fixedDiscountAmount = 0.0;
    _lastInteractionAt = DateTime.now();
    unawaited(_track('coupon_removed'));
    unawaited(_persistCart());
    notifyListeners();
  }

  void removeFromCart(String productId, String size) {
    _items.removeWhere((item) => item.product.id == productId && item.size == size);
    _lastInteractionAt = DateTime.now();
    unawaited(_track('removed'));
    unawaited(_persistCart());
    notifyListeners();
  }

  void clear({bool trackActivity = true}) {
    _items.clear();
    _appliedCoupon = null;
    _discountPercentage = 0.0;
    _fixedDiscountAmount = 0.0;
    _lastInteractionAt = null;
    if (trackActivity) {
      unawaited(_track('cleared'));
    }
    unawaited(_persistCart());
    notifyListeners();
  }
}
