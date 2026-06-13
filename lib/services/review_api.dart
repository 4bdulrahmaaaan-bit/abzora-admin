import 'backend_api_client.dart';

class ReviewApi {
  ReviewApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getReviews({
    int page = 1,
    int limit = 20,
  }) async {
    final payload = await _backendApiClient.get(
      '/vendor/reviews?page=$page&limit=$limit',
      authenticated: true,
    );
    return payload as Map<String, dynamic>;
  }

  Future<void> addReply(String reviewId, String message) async {
    await _backendApiClient.post(
      '/vendor/reviews/$reviewId/reply',
      authenticated: true,
      body: {'message': message},
    );
  }

  Future<void> editReply(String reviewId, String message) async {
    // Note: using POST with _method=PATCH as standard override for dart http issues if any, but patch is fine too
    await _backendApiClient.post(
      '/vendor/reviews/$reviewId/reply',
      authenticated: true,
      body: {'message': message, '_method': 'PATCH'},
    );
  }

  Future<void> deleteReply(String reviewId) async {
    await _backendApiClient.post(
      '/vendor/reviews/$reviewId/reply',
      authenticated: true,
      body: {'_method': 'DELETE'},
    );
  }
}
