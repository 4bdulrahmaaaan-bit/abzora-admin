import '../../../models/models.dart';
import '../../../services/backend_api_client.dart';

class AdminActivityLogApi {
  static Future<Map<String, dynamic>> fetchActivityLogs({
    int page = 1,
    int limit = 25,
    String? actorId,
    String? targetType,
    String? action,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (actorId != null && actorId.isNotEmpty) queryParams['actorId'] = actorId;
    if (targetType != null && targetType.isNotEmpty)
      queryParams['targetType'] = targetType;
    if (action != null && action.isNotEmpty) queryParams['action'] = action;
    if (startDate != null && startDate.isNotEmpty)
      queryParams['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/activity-logs?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final logs = (map['data'] as List? ?? [])
        .map(
          (e) => ActivityLogEntry.fromMap(
            Map<String, dynamic>.from(e as Map),
            e['id']?.toString() ?? '',
          ),
        )
        .toList();

    return {'logs': logs, 'meta': map['meta'] ?? {}};
  }
}
