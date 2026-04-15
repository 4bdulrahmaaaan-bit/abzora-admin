import '../models/models.dart';
import 'backend_api_client.dart';

class WishlistService {
  WishlistService({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;
  static const Duration _cacheTtl = Duration(seconds: 45);
  List<WishlistItem> _cache = const <WishlistItem>[];
  DateTime? _lastFetch;

  Stream<List<WishlistItem>> watchWishlist(String userId) {
    return (() async* {
      yield await _fetchBackendWishlist();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 30));
        yield await _fetchBackendWishlist();
      }
    })().asBroadcastStream();
  }

  Future<void> addToWishlist({
    required String userId,
    required Product product,
  }) async {
    await _backendApiClient.post(
      '/wishlist',
      authenticated: true,
      body: {
        'productId': product.id,
      },
    );
  }

  Future<void> removeFromWishlist({
    required String userId,
    required String productId,
  }) async {
    await _backendApiClient.delete('/wishlist/$productId', authenticated: true);
  }

  Future<List<WishlistItem>> _fetchBackendWishlist({bool force = false}) async {
    if (!force && _cache.isNotEmpty && _lastFetch != null) {
      final age = DateTime.now().difference(_lastFetch!);
      if (age < _cacheTtl) {
        return _cache;
      }
    }

    final payload = await _backendApiClient.get(
      '/wishlist',
      authenticated: true,
      queryParameters: const {
        'fields': 'productId,storeId,name,price,image,addedAt',
      },
    );
    final items = payload is List ? payload : const [];
    final result = items
        .whereType<Map>()
        .map(
          (item) => WishlistItem(
            productId: item['productId']?.toString() ?? '',
            storeId: item['storeId']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            price: (item['price'] as num?)?.toDouble() ?? 0,
            image: item['image']?.toString() ?? '',
            addedAt: DateTime.tryParse(item['addedAt']?.toString() ?? '') ?? DateTime.now(),
          ),
        )
        .toList();
    result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    _cache = result;
    _lastFetch = DateTime.now();
    return result;
  }
}
