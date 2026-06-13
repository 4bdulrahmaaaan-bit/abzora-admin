import '../../../services/backend_api_client.dart';

class AdminInventoryApi {
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/inventory/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchProducts({
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
      '/admin/inventory/products?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final products = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'products': products, 'meta': map['meta'] ?? {}};
  }

  static Future<Map<String, dynamic>> adjustInventory(
    String id,
    Map<String, dynamic> data,
  ) async {
    final payload = await const BackendApiClient().patch(
      '/admin/inventory/$id/adjust',
      authenticated: true,
      body: data,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }
}
