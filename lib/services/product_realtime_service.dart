import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

import '../models/models.dart';
import 'firebase_database_service.dart';

class ProductRealtimeService {
  ProductRealtimeService({FirebaseDatabase? database}) : _database = database;

  final FirebaseDatabase? _database;

  DatabaseReference get _productsRef =>
      (_database ?? FirebaseDatabaseService.instance).ref('products');

  Query _basePageQuery({required int limit}) {
    return _productsRef.orderByKey().limitToFirst(limit);
  }

  List<Product> productsFromPayload(Object? payload) {
    if (payload is! Map) {
      return const [];
    }

    final products = <Product>[];
    payload.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(
        value.map((innerKey, innerValue) => MapEntry(innerKey.toString(), innerValue)),
      );
      map['storeId'] ??= map['store_id'];
      final images = map['images'];
      if (images is List) {
        map['images'] = images.map((item) => item.toString()).toList();
      } else if (images is Map) {
        final orderedEntries = images.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        map['images'] = orderedEntries.map((entry) => entry.value.toString()).toList();
      } else {
        map['images'] = const <String>[];
      }
      final sizes = map['sizes'];
      if (sizes is List) {
        map['sizes'] = sizes.map((item) => item.toString()).toList();
      } else if (sizes is Map) {
        final orderedEntries = sizes.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        map['sizes'] = orderedEntries.map((entry) => entry.value.toString()).toList();
      } else {
        map['sizes'] = const <String>[];
      }
      products.add(Product.fromMap(map, key.toString()));
    });
    return products;
  }

  Future<List<Product>> fetchAll() async {
    final snapshot = await _productsRef
        .get()
        .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Products request timed out.'));
    return productsFromPayload(snapshot.value);
  }

  Future<ProductPageResult> fetchPage({
    int limit = 20,
    String? startAfterKey,
  }) async {
    final effectiveLimit = startAfterKey == null ? limit : limit + 1;
    final query = startAfterKey == null
        ? _basePageQuery(limit: effectiveLimit)
        : _productsRef.orderByKey().startAt(startAfterKey).limitToFirst(effectiveLimit);

    final snapshot = await query
        .get()
        .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Products page request timed out.'));

    if (snapshot.value is! Map) {
      return const ProductPageResult(items: <Product>[], lastKey: null, hasMore: false);
    }

    final map = Map<Object?, Object?>.from(snapshot.value as Map);
    final keys = map.keys.map((key) => key.toString()).toList()..sort();
    final products = <Product>[];
    final pageKeys = <String>[];

    for (final key in keys) {
      if (startAfterKey != null && key == startAfterKey) {
        continue;
      }
      final raw = map[key];
      if (raw is! Map) {
        continue;
      }
      final entryMap = Map<String, dynamic>.from(
        raw.map((innerKey, innerValue) => MapEntry(innerKey.toString(), innerValue)),
      );
      entryMap['storeId'] ??= entryMap['store_id'];
      final images = entryMap['images'];
      if (images is List) {
        entryMap['images'] = images.map((item) => item.toString()).toList();
      } else if (images is Map) {
        final ordered = images.entries.toList()..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        entryMap['images'] = ordered.map((item) => item.value.toString()).toList();
      } else {
        entryMap['images'] = const <String>[];
      }
      final sizes = entryMap['sizes'];
      if (sizes is List) {
        entryMap['sizes'] = sizes.map((item) => item.toString()).toList();
      } else if (sizes is Map) {
        final ordered = sizes.entries.toList()..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        entryMap['sizes'] = ordered.map((item) => item.value.toString()).toList();
      } else {
        entryMap['sizes'] = const <String>[];
      }
      products.add(Product.fromMap(entryMap, key));
      pageKeys.add(key);
      if (products.length == limit) {
        break;
      }
    }

    final hasMore = map.length >= effectiveLimit;
    final lastKey = pageKeys.isEmpty ? null : pageKeys.last;
    return ProductPageResult(
      items: products,
      lastKey: lastKey,
      hasMore: hasMore,
    );
  }

  Stream<List<Product>> watchAll() {
    return _productsRef.onValue.map((event) => productsFromPayload(event.snapshot.value));
  }

  Future<void> save(Product product) async {
    await _productsRef.child(product.id).set({
      ...product.toMap(),
      'store_id': product.storeId,
    });
  }

  Future<void> update(Product product) async {
    await _productsRef.child(product.id).update({
      ...product.toMap(),
      'store_id': product.storeId,
    });
  }

  Future<void> delete(String productId) async {
    await _productsRef.child(productId).remove();
  }

  Future<void> updateStock(String productId, int stock) async {
    await _productsRef.child(productId).update({'stock': stock});
  }
}

class ProductPageResult {
  const ProductPageResult({
    required this.items,
    required this.lastKey,
    required this.hasMore,
  });

  final List<Product> items;
  final String? lastKey;
  final bool hasMore;
}
