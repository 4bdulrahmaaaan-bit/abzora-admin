import 'backend_api_client.dart';

class ReturnsApi {
  ReturnsApi({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getReturns({int page = 1, int limit = 20}) async {
    final payload = await _backendApiClient.get('/vendor/returns?page=$page&limit=$limit', authenticated: true);
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRefunds({int page = 1, int limit = 20}) async {
    final payload = await _backendApiClient.get('/vendor/refunds?page=$page&limit=$limit', authenticated: true);
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExchanges({int page = 1, int limit = 20}) async {
    final payload = await _backendApiClient.get('/vendor/exchanges?page=$page&limit=$limit', authenticated: true);
    return payload as Map<String, dynamic>;
  }

  Future<void> updateReturnStatus(String id, String status) async {
    await _backendApiClient.post('/vendor/returns/$id/status', authenticated: true, body: {'status': status, '_method': 'PATCH'});
  }

  Future<void> updateRefundStatus(String id, String status) async {
    await _backendApiClient.post('/vendor/refunds/$id/status', authenticated: true, body: {'status': status, '_method': 'PATCH'});
  }

  Future<void> updateExchangeStatus(String id, String status) async {
    await _backendApiClient.post('/vendor/exchanges/$id/status', authenticated: true, body: {'status': status, '_method': 'PATCH'});
  }
}
