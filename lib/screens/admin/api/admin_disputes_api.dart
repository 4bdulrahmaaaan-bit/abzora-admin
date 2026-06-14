import '../../../models/models.dart';
import '../../../services/backend_api_client.dart';

class AdminDisputesApi {
  static Future<Map<String, dynamic>> fetchDisputesDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/disputes/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchDisputes({
    int page = 1,
    int limit = 25,
    String? status,
    String? priority,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (priority != null && priority.isNotEmpty) {
      queryParams['priority'] = priority;
    }

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/disputes?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final disputes = (map['data'] as List? ?? [])
        .map((e) => AdminDispute.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return {'disputes': disputes, 'meta': map['meta'] ?? {}};
  }

  static Future<AdminDispute> fetchDisputeDetails(String disputeId) async {
    final payload = await const BackendApiClient().get(
      '/admin/disputes/$disputeId',
      authenticated: true,
    );
    return AdminDispute.fromMap(Map<String, dynamic>.from(payload['data']));
  }

  static Future<AdminDispute> updateDispute(
    String disputeId,
    Map<String, dynamic> updates,
  ) async {
    final payload = await const BackendApiClient().patch(
      '/admin/disputes/$disputeId',
      authenticated: true,
      body: updates,
    );
    return AdminDispute.fromMap(Map<String, dynamic>.from(payload['data']));
  }

  static Future<AdminDispute> escalateDispute(
    String disputeId, {
    String? note,
  }) async {
    final payload = await const BackendApiClient().post(
      '/admin/disputes/$disputeId/escalate',
      authenticated: true,
      body: {'note': note},
    );
    return AdminDispute.fromMap(Map<String, dynamic>.from(payload['data']));
  }

  static Future<AdminDispute> resolveDispute(
    String disputeId, {
    required String resolutionDetails,
  }) async {
    final payload = await const BackendApiClient().post(
      '/admin/disputes/$disputeId/resolve',
      authenticated: true,
      body: {'resolutionDetails': resolutionDetails},
    );
    return AdminDispute.fromMap(Map<String, dynamic>.from(payload['data']));
  }
}
