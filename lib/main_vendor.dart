import 'app_shell.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'services/app_config.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: '',
      );
      options.environment = const String.fromEnvironment(
        'SENTRY_ENV',
        defaultValue: 'production',
      );
      options.tracesSampleRate = 0.2;
    },
    appRunner: () async {
      await bootstrapAndRun(AbzioAppMode.vendor);
      _performHealthCheck();
    },
  );
}

Future<void> _performHealthCheck() async {
  try {
    final baseUrl = AppConfig.backendBaseUrl;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      debugPrint('Vendor startup health check: device appears offline.');
      return;
    }

    final response = await http
        .get(Uri.parse('$baseUrl/api/health'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      debugPrint(
        'Vendor startup health check returned ${response.statusCode}. '
        'Suppressing user-facing connectivity banner.',
      );
      return;
    }
    debugPrint('Vendor startup health check passed.');
  } catch (e) {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      debugPrint('Vendor startup health check: offline exception detected.');
      return;
    }
    debugPrint('Vendor startup health check failed: $e');
  }
}
