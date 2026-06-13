import '../../../services/backend_api_client.dart';

/// API client for the Admin Vendor Intelligence V2.
class AdminVendorsApi {
  AdminVendorsApi({BackendApiClient? client})
    : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  Future<Map<String, dynamic>> getDashboard() async {
    final payload = await _client.get(
      '/admin/vendors/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getVendor(String id) async {
    final payload = await _client.get(
      '/admin/vendors/$id',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getAnalytics(String id) async {
    final payload = await _client.get(
      '/admin/vendors/$id/analytics',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getPayouts(String id) async {
    final payload = await _client.get(
      '/admin/vendors/$id/payouts',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getComplaints(String id) async {
    final payload = await _client.get(
      '/admin/vendors/$id/complaints',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }
}
