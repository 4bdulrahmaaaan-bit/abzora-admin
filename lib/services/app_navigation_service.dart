import 'package:flutter/material.dart';

class AppNavigationService {
  AppNavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static Future<void> resetToHome({String? message}) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil('/home', (_) => false);
    if (message != null && message.trim().isNotEmpty) {
      messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(message.trim()),
          ),
        );
    }
  }
}
