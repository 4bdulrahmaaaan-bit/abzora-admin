import '../../../services/backend_api_client.dart';

class AdminFinanceApi {
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/finance/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchSettlements({
    int page = 1,
    int limit = 25,
    String? type,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/finance/settlements?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final settlements = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'settlements': settlements, 'meta': map['meta'] ?? {}};
  }

  static Future<Map<String, dynamic>> fetchRefunds({
    int page = 1,
    int limit = 25,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/finance/refunds?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final refunds = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'refunds': refunds, 'meta': map['meta'] ?? {}};
  }

  static Future<List<Map<String, dynamic>>> fetchReports(String period) async {
    final payload = await const BackendApiClient().get(
      '/admin/finance/reports?period=$period',
      authenticated: true,
    );
    return (payload['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
