import 'backend_api_client.dart';

class PromotionAnalyticsApi {
  PromotionAnalyticsApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getPromotionAnalytics() async {
    final payload = await _backendApiClient.get(
      '/vendor/promotion-analytics',
      authenticated: true,
    );
    return payload as Map<String, dynamic>;
  }
}
