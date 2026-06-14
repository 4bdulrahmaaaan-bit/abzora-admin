import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'auth_session_service.dart';

class RiderEarningsApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to view earnings.',
    );
  }

  static Future<List<dynamic>> getEarnings() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/earnings'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['success'] == true) {
        return json['data'] ?? [];
      }
    }
    throw StateError('Failed to fetch earnings.');
  }

  static Future<Map<String, dynamic>> getEarningsSummary() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/earnings/summary'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['success'] == true && json['data'] != null) {
        return json['data'];
      }
    }
    throw StateError('Failed to fetch earnings summary.');
  }
}
