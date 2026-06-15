import 'app_shell.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      _showConnectivityWarning();
    }
  } catch (e) {
    _showConnectivityWarning();
  }
}

void _showConnectivityWarning() {
  Future.delayed(const Duration(seconds: 2), () {
    final context = AbzioApp.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limited connectivity detected. Changes will sync automatically when connection is restored.'),
          duration: Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}
