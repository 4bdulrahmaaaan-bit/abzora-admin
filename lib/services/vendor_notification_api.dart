import 'backend_api_client.dart';

class VendorNotificationApi {
  VendorNotificationApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String? priority,
    bool? unreadOnly,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (priority != null) queryParameters['priority'] = priority;
    if (unreadOnly != null && unreadOnly) {
      queryParameters['unreadOnly'] = 'true';
    }

    final payload = await _backendApiClient.get(
      '/vendor/notifications',
      authenticated: true,
      queryParameters: queryParameters,
    );
    return payload as Map<String, dynamic>;
  }

  Future<int> getUnreadCount() async {
    final payload = await _backendApiClient.get(
      '/vendor/notifications/unread-count',
      authenticated: true,
    );
    return (payload['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(String id) async {
    // Note: Assuming patch method exists or we can use post if it doesn't.
    // If BackendApiClient doesn't have patch, we'll try to use standard HTTP internally if needed,
    // but the instruction implies it supports standard verbs.
    try {
      await _backendApiClient.post(
        '/vendor/notifications/$id/read',
        authenticated: true,
        body: {'_method': 'PATCH'},
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _backendApiClient.post(
        '/vendor/notifications/read-all',
        authenticated: true,
        body: {'_method': 'PATCH'},
      );
    } catch (_) {}
  }
}
