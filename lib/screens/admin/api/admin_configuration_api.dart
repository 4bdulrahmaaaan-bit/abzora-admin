import '../../../services/backend_api_client.dart';

class AdminConfigurationApi {
  static Future<Map<String, dynamic>> fetchConfig() async {
    final payload = await const BackendApiClient().get(
      '/admin/config',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> updateConfig(
    Map<String, dynamic> data,
  ) async {
    final payload = await const BackendApiClient().patch(
      '/admin/config',
      authenticated: true,
      body: data,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchConfigHistory({
    int page = 1,
    int limit = 25,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/config/history?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final history = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'history': history, 'meta': map['meta'] ?? {}};
  }
}
