import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  List<ConnectivityResult> _results = const [ConnectivityResult.none];
  bool _showStatusBanner = false;
  bool _wasOffline = false;

  List<ConnectivityResult> get results => _results;
  bool get isOffline => _results.every((item) => item == ConnectivityResult.none);
  bool get isOnline => !isOffline;
  bool get showStatusBanner => _showStatusBanner;
  bool get justCameOnline => isOnline && _wasOffline;
  String get statusMessage => isOffline ? 'You are offline' : 'Back online';

  Future<void> initialize() async {
    try {
      _results = await _connectivity.checkConnectivity();
      _wasOffline = isOffline;
      _subscription ??= _connectivity.onConnectivityChanged.listen(_handleConnectivityChanged);
      notifyListeners();
    } catch (error) {
      debugPrint('Network provider init failed: $error');
    }
  }

  Future<void> refresh() async {
    try {
      _handleConnectivityChanged(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('Network provider refresh failed: $error');
    }
  }

  void dismissBanner() {
    if (!_showStatusBanner) {
      return;
    }
    _showStatusBanner = false;
    notifyListeners();
  }

  void _handleConnectivityChanged(List<ConnectivityResult> next) {
    final wasOffline = isOffline;
    _results = next;
    if (wasOffline != isOffline) {
      _showStatusBanner = true;
      _wasOffline = wasOffline;
      notifyListeners();
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (_showStatusBanner) {
          dismissBanner();
        }
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
