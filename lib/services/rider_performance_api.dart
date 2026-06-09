import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'auth_session_service.dart';

class RiderPerformanceApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to view performance.',
    );
  }

  static Future<Map<String, dynamic>> getPerformance() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/performance'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        return json['data'];
      }
    }
    throw StateError('Failed to fetch performance.');
  }

  static Future<List<dynamic>> getIncentives() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/performance/incentives'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return json['data'] ?? [];
      }
    }
    throw StateError('Failed to fetch incentives.');
  }
}
