import '../../../services/backend_api_client.dart';

/// API client for the Admin Order Management V2.
class AdminOrdersApi {
  AdminOrdersApi({BackendApiClient? client})
    : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  Future<Map<String, dynamic>> getDashboard() async {
    final payload = await _client.get(
      '/admin/orders/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getQueue({
    int page = 1,
    int limit = 25,
    String? status,
    String? vendor,
    String? rider,
    String? search,
    String? health,
  }) async {
    final payload = await _client.get(
      '/admin/orders/queue',
      authenticated: true,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
        if (rider != null && rider.isNotEmpty) 'rider': rider,
        if (search != null && search.isNotEmpty) 'search': search,
        if (health != null && health.isNotEmpty) 'health': health,
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    final payload = await _client.get('/admin/orders/$id', authenticated: true);
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getTimeline(String id) async {
    final payload = await _client.get(
      '/admin/orders/$id/timeline',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getHistory(String id) async {
    final payload = await _client.get(
      '/admin/orders/$id/history',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }
}
