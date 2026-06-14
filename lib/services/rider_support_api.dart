import 'dart:convert';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'auth_session_service.dart';

class RiderSupportApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to access support.',
    );
  }

  /// Create a new support ticket
  static Future<bool> createTicket({
    required String category,
    required String description,
    required String priority,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/rider/support/ticket'),
        headers: await _headers(),
        body: jsonEncode({
          'category': category,
          'description': description,
          'priority': priority,
        }),
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

  /// Fetch history of tickets
  static Future<List<Map<String, dynamic>>> getTickets() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/rider/support/tickets'),
        headers: await _headers(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json['success'] == true && json['data'] != null) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch Frequently Asked Questions
  static Future<List<Map<String, dynamic>>> getFaqs() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/rider/support/faqs'),
        headers: await _headers(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json['success'] == true && json['data'] != null) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
