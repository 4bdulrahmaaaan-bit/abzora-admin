import '../../../services/backend_api_client.dart';

class AdminRiderIntelligenceApi {
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/rider-intelligence/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchRidersList({
    int page = 1,
    int limit = 25,
    String? classification,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (classification != null && classification.isNotEmpty) {
      queryParams['classification'] = classification;
    }

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/rider-intelligence/list?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final riders = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'riders': riders, 'meta': map['meta'] ?? {}};
  }
}
