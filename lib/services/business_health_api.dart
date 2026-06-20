import 'backend_api_client.dart';

class BusinessHealthApi {
  BusinessHealthApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final payload = await _backendApiClient.get(
        '/vendor/business-health',
        authenticated: true,
      );
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      return const <String, dynamic>{};
    } catch (error) {
      return <String, dynamic>{
        'ok': false,
        'message': error.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> recalculateHealth() async {
    try {
      final payload = await _backendApiClient.post(
        '/vendor/business-health/recalculate',
        authenticated: true,
        body: {},
      );
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      return const <String, dynamic>{};
    } catch (error) {
      return <String, dynamic>{
        'ok': false,
        'message': error.toString(),
      };
    }
  }
}
