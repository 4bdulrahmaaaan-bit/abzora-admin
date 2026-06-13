import '../../../models/models.dart';
import '../../../services/backend_api_client.dart';

class AdminNotificationsApi {
  static Future<AdminNotification> sendCampaign({
    required String title,
    required String body,
    required String audienceRole,
    required List<String> channels,
    required String campaignType,
  }) async {
    final payload = await const BackendApiClient().post(
      '/admin/notifications/send',
      authenticated: true,
      body: {
        'title': title,
        'body': body,
        'audienceRole': audienceRole,
        'channels': channels,
        'campaignType': campaignType,
      },
    );
    return AdminNotification.fromMap(Map<String, dynamic>.from(payload['data']));
  }

  static Future<AdminNotification> scheduleCampaign({
    required String title,
    required String body,
    required String audienceRole,
    required List<String> channels,
    required String scheduledAt,
  }) async {
    final payload = await const BackendApiClient().post(
      '/admin/notifications/schedule',
      authenticated: true,
      body: {
        'title': title,
        'body': body,
        'audienceRole': audienceRole,
        'channels': channels,
        'scheduledAt': scheduledAt,
      },
    );
    return AdminNotification.fromMap(Map<String, dynamic>.from(payload['data']));
  }

  static Future<Map<String, dynamic>> fetchHistory({
    int page = 1,
    int limit = 25,
  }) async {
    final payload = await const BackendApiClient().get(
      '/admin/notifications/history?page=$page&limit=$limit',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final history = (map['data'] as List? ?? [])
        .map((e) => AdminNotification.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return {
      'history': history,
      'meta': map['meta'] ?? {},
    };
  }

  static Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final payload = await const BackendApiClient().get(
      '/admin/notifications/templates',
      authenticated: true,
    );
    return (payload['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
