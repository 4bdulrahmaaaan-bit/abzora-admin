import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/trial_session.dart';

class TrialCartProvider with ChangeNotifier {
  final List<TrialSessionItem> _items = [];

  List<TrialSessionItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;
  bool get isFull => _items.length >= 5;

  void addItem(Product product, String size) {
    if (isFull) {
      throw StateError('You can only select up to 5 items for a trial.');
    }
    if (!product.tryAtHomeAvailable) {
      throw StateError('This product is not eligible for Try Before You Buy.');
    }
    if (_items.isNotEmpty && _items.first.storeId != product.storeId) {
      throw StateError('Try Before You Buy orders can only contain products from one brand at a time.');
    }

    final existingIndex = _items.indexWhere(
        (item) => item.productId == product.id && item.recommendedSize == size);
    
    if (existingIndex >= 0) {
      throw StateError('This item is already in your trial cart.');
    }

    _items.add(
      TrialSessionItem.fromProduct(
        product,
        recommendedSize: size,
        source: 'cart',
      ),
    );
    notifyListeners();
  }

  void removeItem(String productId, String size) {
    _items.removeWhere(
        (item) => item.productId == productId && item.recommendedSize == size);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
