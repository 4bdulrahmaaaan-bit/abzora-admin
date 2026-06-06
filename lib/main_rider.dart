import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'rider_app.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.environment = const String.fromEnvironment(
        'SENTRY_ENV',
        defaultValue: 'production',
      );
      options.tracesSampleRate = 0.2;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      runApp(const ProviderScope(child: AbianzoRiderApp()));
    },
  );
}

