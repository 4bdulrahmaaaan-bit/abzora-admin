import 'package:abzio/models/models.dart';
import 'package:abzio/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product buildProduct({
    required String id,
    required String storeId,
    String name = 'Blazer',
    double price = 1000,
  }) {
    return Product(
      id: id,
      storeId: storeId,
      name: name,
      description: 'Premium product',
      price: price,
      images: const ['https://example.com/image.jpg'],
      sizes: const ['M'],
      stock: 10,
      category: 'MEN',
    );
  }

  group('CartProvider', () {
    test('adds item when cart is empty', () {
      final cart = CartProvider();
      final result = cart.addToCart(buildProduct(id: 'p1', storeId: 's1'), 'M');

      expect(result, CartAddResult.added);
      expect(cart.items.length, 1);
      expect(cart.activeStoreId, 's1');
    });

    test('increments quantity for same product and store', () {
      final cart = CartProvider();
      final product = buildProduct(id: 'p1', storeId: 's1');

      cart.addToCart(product, 'M');
      final result = cart.addToCart(product, 'M');

      expect(result, CartAddResult.updated);
      expect(cart.items.single.quantity, 2);
    });

    test('rejects product from different store', () {
      final cart = CartProvider();
      cart.addToCart(buildProduct(id: 'p1', storeId: 's1'), 'M');

      final result = cart.addToCart(buildProduct(id: 'p2', storeId: 's2'), 'M');

      expect(result, CartAddResult.storeConflict);
      expect(cart.items.length, 1);
      expect(cart.activeStoreId, 's1');
    });
  });
}
