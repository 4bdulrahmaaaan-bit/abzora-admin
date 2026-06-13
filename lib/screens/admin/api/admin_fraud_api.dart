import '../../../services/backend_api_client.dart';

/// API client for the Admin Fraud & Risk Engine.
class AdminFraudApi {
  AdminFraudApi({BackendApiClient? client})
    : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  Future<Map<String, dynamic>> getDashboard() async {
    final payload = await _client.get(
      '/admin/fraud/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> actionEntity({
    required String type,
    required String id,
    required String action,
    String reason = '',
  }) async {
    final payload = await _client.post(
      '/admin/fraud/$type/$id/action',
      authenticated: true,
      body: {'action': action, 'reason': reason},
    );
    return Map<String, dynamic>.from(payload as Map);
  }
}
