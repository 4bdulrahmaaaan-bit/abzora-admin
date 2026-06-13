import 'backend_api_client.dart';

class BusinessHealthApi {
  BusinessHealthApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getHealth() async {
    final payload = await _backendApiClient.get(
      '/vendor/business-health',
      authenticated: true,
    );
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recalculateHealth() async {
    final payload = await _backendApiClient.post(
      '/vendor/business-health/recalculate',
      authenticated: true,
      body: {},
    );
    return payload as Map<String, dynamic>;
  }
}
