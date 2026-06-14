// ignore_for_file: uri_does_not_exist, undefined_class, undefined_identifier, undefined_method, non_type_as_type_argument, invalid_constant, dead_code, unused_local_variable
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'auth_session_service.dart';

class RiderAnalyticsApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to view analytics.',
    );
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/analytics'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['success'] == true && json['data'] != null) {
        return json['data'];
      }
    }
    throw StateError('Failed to fetch analytics.');
  }
}
