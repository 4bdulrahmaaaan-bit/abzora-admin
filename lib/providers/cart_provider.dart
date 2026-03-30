import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
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
}

enum CartAddResult {
  added,
  updated,
  storeConflict,
}

class CartProvider with ChangeNotifier {
  CartProvider({DatabaseService? databaseService}) : _db = databaseService ?? DatabaseService();

  final DatabaseService _db;
  final List<CartItem> _items = [];
  String? _appliedCoupon;
  double _discountPercentage = 0.0;
  double _fixedDiscountAmount = 0.0;
  DateTime? _lastInteractionAt;

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

  Future<void> _track(String action) async {
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
  }

  CartAddResult addToCart(Product product, String size) {
    if (_items.isNotEmpty && _items.first.product.storeId != product.storeId) {
      return CartAddResult.storeConflict;
    }

    final existingIndex = _items.indexWhere((item) => item.product.id == product.id && item.size == size);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
      _lastInteractionAt = DateTime.now();
      unawaited(_db.recordProductCartIntent(product));
      unawaited(_track('updated'));
      notifyListeners();
      return CartAddResult.updated;
    } else {
      _items.add(CartItem(product: product, size: size));
      _lastInteractionAt = DateTime.now();
      unawaited(_db.recordProductCartIntent(product));
      unawaited(_track('added'));
      notifyListeners();
      return CartAddResult.added;
    }
  }

  void updateQuantity(String productId, String size, int delta) {
    final index = _items.indexWhere((item) => item.product.id == productId && item.size == size);
    if (index >= 0) {
      _items[index].quantity += delta;
      if (delta > 0) {
        unawaited(_db.recordProductCartIntent(_items[index].product, quantity: delta));
      }
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      _lastInteractionAt = DateTime.now();
      unawaited(_track('quantity_changed'));
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
      notifyListeners();
      return true;
    }
    if (code.toUpperCase() == 'ELITE20') {
      _appliedCoupon = code.toUpperCase();
      _discountPercentage = 0.20;
      _fixedDiscountAmount = 0.0;
      _lastInteractionAt = DateTime.now();
      unawaited(_track('coupon_applied'));
      notifyListeners();
      return true;
    }
    if (code.toUpperCase() == 'ABZORA10') {
      _appliedCoupon = code.toUpperCase();
      _discountPercentage = 0.10;
      _fixedDiscountAmount = 0.0;
      _lastInteractionAt = DateTime.now();
      unawaited(_track('coupon_applied'));
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
    notifyListeners();
  }

  void removeFromCart(String productId, String size) {
    _items.removeWhere((item) => item.product.id == productId && item.size == size);
    _lastInteractionAt = DateTime.now();
    unawaited(_track('removed'));
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _appliedCoupon = null;
    _discountPercentage = 0.0;
    _fixedDiscountAmount = 0.0;
    _lastInteractionAt = null;
    unawaited(_track('cleared'));
    notifyListeners();
  }
}
