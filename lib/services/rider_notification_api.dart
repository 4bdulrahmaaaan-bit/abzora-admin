import 'dart:convert';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'auth_session_service.dart';

class RiderNotificationApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to access notifications.',
    );
  }

  /// Fetches all notifications for the authenticated rider
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/rider/notifications'),
        headers: await _headers(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json['success'] == true && json['data'] != null) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return []; // Return empty list gracefully on API contract mismatch
    } catch (e) {
      // Return empty list on network error to prevent crashing the UI,
      // allowing the empty state to show.
      return [];
    }
  }

  /// Marks a specific notification as read
  static Future<bool> markAsRead(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.backendBaseUrl}/api/rider/notifications/$id/read'),
        headers: await _headers(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the count of unread notifications for the bell badge
  static Future<int> getUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/rider/notifications/unread-count'),
        headers: await _headers(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json['success'] == true && json['data'] != null) {
          return (json['data']['count'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    } catch (e) {
      return 0; // Fallback to 0 if request fails
    }
  }
}
