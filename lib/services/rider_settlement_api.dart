import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'auth_session_service.dart';

class RiderSettlementApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to view payouts.',
    );
  }

  static Future<Map<String, dynamic>?> getUpcomingPayout() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/payouts'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['success'] == true) {
        return json['data'];
      }
    }
    return null;
  }

  static Future<List<dynamic>> getPayoutHistory() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/payouts/history'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['success'] == true) {
        return json['data'] ?? [];
      }
    }
    throw StateError('Failed to fetch payout history.');
  }
}
