import '../../../services/backend_api_client.dart';

class AdminKycApi {
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/kyc/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchApplications({
    int page = 1,
    int limit = 25,
    String type = 'Vendor',
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'type': type,
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/kyc/applications?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final apps = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'applications': apps, 'meta': map['meta'] ?? {}};
  }

  static Future<Map<String, dynamic>> reviewApplication(
    String id,
    String type,
    String status,
    String notes,
  ) async {
    final payload = await const BackendApiClient().patch(
      '/admin/kyc/$id/review',
      authenticated: true,
      body: {'type': type, 'status': status, 'notes': notes},
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }
}
