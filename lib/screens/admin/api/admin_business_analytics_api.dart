import '../../../services/backend_api_client.dart';

class AdminBusinessAnalyticsApi {
  static Future<Map<String, dynamic>> fetchAnalyticsV2() async {
    final payload = await const BackendApiClient().get('/admin/business-analytics/v2', authenticated: true);
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }
}
