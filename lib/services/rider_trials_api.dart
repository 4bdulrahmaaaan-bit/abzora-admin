import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'auth_session_service.dart';
import '../models/trial_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_action_queue.dart';

class ServerTimeOffset {
  static final ServerTimeOffset _instance = ServerTimeOffset._internal();
  factory ServerTimeOffset() => _instance;
  ServerTimeOffset._internal();

  Duration offset = Duration.zero;

  void updateOffset(String? serverTimeIso) {
    if (serverTimeIso != null) {
      final serverTime = DateTime.tryParse(serverTimeIso);
      if (serverTime != null) {
        offset = serverTime.difference(DateTime.now());
      }
    }
  }

  DateTime get now => DateTime.now().add(offset);
}

class RiderTrialsApi {
  static Future<Map<String, String>> _headers() async {
    return AuthSessionService.instance.requiredAuthorizationHeaders(
      failureMessage: 'Please sign in to manage trials.',
    );
  }

  static Future<List<TrialSession>> getAssignedTrials() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/assigned'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        final List data = json['data'] ?? [];
        return data.map((e) => TrialSession.fromMap(e)).toList();
      }
    }
    throw StateError('Failed to fetch assigned trials.');
  }

  static Future<List<TrialSession>> getActiveTrials() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/active'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        ServerTimeOffset().updateOffset(json['serverTime']);
        final List data = json['data'] ?? [];
        return data.map((e) => TrialSession.fromMap(e)).toList();
      }
    }
    throw StateError('Failed to fetch active trials.');
  }

  static Future<List<TrialSession>> getCompletedTrials() async {
    final response = await http.get(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/completed'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        ServerTimeOffset().updateOffset(json['serverTime']);
        final List data = json['data'] ?? [];
        return data.map((e) => TrialSession.fromMap(e)).toList();
      }
    }
    throw StateError('Failed to fetch completed trials.');
  }

  static Future<TrialSession> arriveTrial(String id, TrialSession currentSession) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await OfflineActionQueue.enqueue(
        endpoint: '/api/rider/trials/$id/arrive',
        method: 'POST',
        payload: {},
      );
      return currentSession.copyWith(
        arrivedAt: ServerTimeOffset().now,
      );
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/$id/arrive'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        ServerTimeOffset().updateOffset(json['serverTime']);
        return TrialSession.fromMap(json['data']);
      }
    }
    throw StateError('Failed to mark arrival.');
  }

  static Future<TrialSession> startTrial(String id, TrialSession currentSession) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await OfflineActionQueue.enqueue(
        endpoint: '/api/rider/trials/$id/start',
        method: 'POST',
        payload: {},
      );
      return currentSession.copyWith(
        status: 'trial_started',
        startedAt: ServerTimeOffset().now,
      );
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/$id/start'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        ServerTimeOffset().updateOffset(json['serverTime']);
        return TrialSession.fromMap(json['data']);
      }
    }
    throw StateError('Failed to start trial.');
  }

  static Future<Map<String, dynamic>> calculateCheckout(String id, List<String> itemsKept, List<String> itemsReturned) async {
    final headers = await _headers();
    headers['Content-Type'] = 'application/json';

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/$id/checkout'),
      headers: headers,
      body: jsonEncode({
        'itemsKept': itemsKept,
        'itemsReturned': itemsReturned,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        return json['data'];
      }
    }
    throw StateError('Failed to calculate checkout.');
  }

  static Future<TrialSession> completeTrial({
    required String id,
    required TrialSession currentSession,
    required List<String> itemsKept,
    required List<String> itemsReturned,
    required String trialOutcome,
    required String notes,
    required String paymentMethod,
    required bool paymentCollected,
    required List<String> proofPhotos,
  }) async {
    final payload = {
      'itemsKept': itemsKept,
      'itemsReturned': itemsReturned,
      'trialOutcome': trialOutcome,
      'notes': notes,
      'paymentMethod': paymentMethod,
      'paymentCollected': paymentCollected,
      'proofPhotos': proofPhotos,
    };

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await OfflineActionQueue.enqueue(
        endpoint: '/api/rider/trials/$id/complete',
        method: 'POST',
        payload: payload,
      );
      return currentSession.copyWith(
        status: 'completed',
        completedAt: ServerTimeOffset().now,
      );
    }

    final headers = await _headers();
    headers['Content-Type'] = 'application/json';

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/$id/complete'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        ServerTimeOffset().updateOffset(json['serverTime']);
        return TrialSession.fromMap(json['data']);
      }
    }
    throw StateError('Failed to complete trial.');
  }

  static Future<TrialSession> noShowTrial(String id, String notes, List<String> proofPhotos) async {
    final headers = await _headers();
    headers['Content-Type'] = 'application/json';

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/rider/trials/$id/no-show'),
      headers: headers,
      body: jsonEncode({
        'notes': notes,
        'proofPhotos': proofPhotos,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        ServerTimeOffset().updateOffset(json['serverTime']);
        return TrialSession.fromMap(json['data']);
      }
    }
    throw StateError('Failed to mark no-show.');
  }
}
