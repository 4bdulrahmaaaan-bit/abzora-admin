import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_config.dart';
import 'notification_service.dart';

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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      firebaseReady = true;
    } catch (error) {
      debugPrint('Firebase bootstrap fallback: $error');
      firebaseReady = Firebase.apps.isNotEmpty;
    }

    if (firebaseReady) {
      debugPrint('ABZORA Firebase project: ${Firebase.app().options.projectId}');
      if (AppConfig.hasBackendBaseUrl) {
        try {
          FirebaseDatabase.instance.goOffline();
          debugPrint('Firebase Realtime Database disabled in backend mode.');
        } catch (error) {
          debugPrint('Firebase RTDB bootstrap fallback: $error');
        }
      }
      try {
        if (!AppConfig.hasBackendBaseUrl && AppConfig.useFirebaseEmulators) {
          await FirebaseAuth.instance.useAuthEmulator(
            AppConfig.firebaseEmulatorHost,
            AppConfig.firebaseAuthEmulatorPort,
          );
          debugPrint(
            'Firebase auth emulator enabled at ${AppConfig.firebaseEmulatorHost} '
            '(auth:${AppConfig.firebaseAuthEmulatorPort})',
          );
        }
      } catch (error) {
        debugPrint('Firebase auth bootstrap fallback: $error');
      }
    }

    if (firebaseReady) {
      debugPrint('Notification bootstrap deferred until an authenticated session is available.');
    }

    if (!AppConfig.hasFirebaseConfig) {
      debugPrint('Firebase environment values are not configured. Running in demo-safe mode.');
    }

    if (!AppConfig.hasRazorpayKey) {
      debugPrint('Razorpay key is not configured. Online payments will be disabled.');
    }

    if (!AppConfig.hasGoogleMapsKey) {
      debugPrint('Google Maps API key is not configured. Location flow will use address-only fallback.');
    }

    return AppBootstrapResult(
      firebaseReady: firebaseReady,
      notificationsReady: notificationsReady,
    );
  }
}
