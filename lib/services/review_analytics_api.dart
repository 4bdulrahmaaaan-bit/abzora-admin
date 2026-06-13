import 'backend_api_client.dart';

class ReviewAnalyticsApi {
  ReviewAnalyticsApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getAnalytics() async {
    final payload = await _backendApiClient.get(
      '/vendor/reviews/analytics',
      authenticated: true,
    );
    return payload as Map<String, dynamic>;
  }
}
