import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_action_queue.dart';
import 'app_config.dart';
import 'auth_session_service.dart';

class NetworkSyncService {
  static final NetworkSyncService _instance = NetworkSyncService._internal();
  static NetworkSyncService get instance => _instance;

  bool _isSyncing = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  NetworkSyncService._internal() {
    _init();
  }

  void _init() {
    OfflineActionQueue.init();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        syncNow();
      }
    });
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingActions = await OfflineActionQueue.getPendingActions();
      for (final action in pendingActions) {
        final success = await _processAction(action);
        if (success) {
          await OfflineActionQueue.markSynced(action['idempotencyKey']);
        } else {
          await OfflineActionQueue.incrementRetry(action['idempotencyKey']);
        }
        // Small delay between requests to prevent overwhelming the server
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processAction(Map<String, dynamic> action) async {
    try {
      final headers = await AuthSessionService.instance.requiredAuthorizationHeaders();
      headers['Content-Type'] = 'application/json';
      headers['x-idempotency-key'] = action['idempotencyKey']; // Critical requirement

      final uri = Uri.parse('${AppConfig.backendBaseUrl}${action['endpoint']}');
      final bodyStr = action['payload'];

      http.Response response;
      if (action['method'] == 'POST') {
        response = await http.post(uri, headers: headers, body: bodyStr);
      } else if (action['method'] == 'PATCH') {
        response = await http.patch(uri, headers: headers, body: bodyStr);
      } else {
        // Fallback to post for unknown methods
        response = await http.post(uri, headers: headers, body: bodyStr);
      }

      // Delete queue item only after 2xx response
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false; // Network failure, will retry next time
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
  }
}
