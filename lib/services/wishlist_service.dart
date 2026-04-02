import '../models/models.dart';
import 'backend_api_client.dart';

class WishlistService {
  WishlistService({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Stream<List<WishlistItem>> watchWishlist(String userId) {
    return (() async* {
      yield await _fetchBackendWishlist();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 20));
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

  Future<List<WishlistItem>> _fetchBackendWishlist() async {
    final payload = await _backendApiClient.get('/wishlist', authenticated: true);
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
    return result;
  }
}
