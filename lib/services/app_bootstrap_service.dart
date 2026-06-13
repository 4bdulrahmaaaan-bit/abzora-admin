import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_config.dart';

class AppBootstrapResult {
  final bool firebaseReady;
  final bool notificationsReady;

  const AppBootstrapResult({
    required this.firebaseReady,
    required this.notificationsReady,
  });
}

class AppBootstrapService {
  Future<AppBootstrapResult> initialize() async {
    var firebaseReady = false;
    var notificationsReady = false;

    try {
      debugPrint('[BOOT] 1 Firebase initialize start');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('[BOOT ERROR] Firebase.initializeApp timeout'),
      );
      debugPrint('[BOOT] 1 Firebase initialize done');
      firebaseReady = true;
    } catch (error, st) {
      debugPrint('[BOOT ERROR] Firebase fallback: $error');
      debugPrint('$st');
      firebaseReady = Firebase.apps.isNotEmpty;
    }

    if (firebaseReady) {
      debugPrint(
        'Abianzo Firebase project: ${Firebase.app().options.projectId}',
      );
      if (AppConfig.hasBackendBaseUrl) {
        try {
          debugPrint('Firebase Realtime Database disabled in backend mode.');
        } catch (error) {
          debugPrint('Firebase RTDB bootstrap fallback: $error');
        }
      }
      try {
        if (!AppConfig.hasBackendBaseUrl && AppConfig.useFirebaseEmulators) {
          await FirebaseAuth.instance
              .useAuthEmulator(
                AppConfig.firebaseEmulatorHost,
                AppConfig.firebaseAuthEmulatorPort,
              )
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw Exception(
                  '[BOOT ERROR] FirebaseAuth emulator timeout',
                ),
              );
          debugPrint(
            'Firebase auth emulator enabled at ${AppConfig.firebaseEmulatorHost} '
            '(auth:${AppConfig.firebaseAuthEmulatorPort})',
          );
        }
      } catch (error, st) {
        debugPrint('[BOOT ERROR] Firebase auth fallback: $error');
        debugPrint('$st');
      }
    }

    if (!AppConfig.hasFirebaseConfig) {
      debugPrint(
        'Firebase environment values are not configured. Running in demo-safe mode.',
      );
    }

    if (!AppConfig.hasRazorpayKey) {
      debugPrint(
        'Razorpay key is not configured. Online payments will be disabled.',
      );
    }

    if (!AppConfig.hasGoogleMapsKey) {
      debugPrint(
        'Google Maps API key is not configured. Location flow will use address-only fallback.',
      );
    }

    return AppBootstrapResult(
      firebaseReady: firebaseReady,
      notificationsReady: notificationsReady,
    );
  }
}
