import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';

import '../models/models.dart';
import '../utils/app_mode_routes.dart';
import 'database_service.dart';

class NotificationService {
  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static String? _lastSyncedUserId;
  static String? _lastSyncedToken;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<bool> initNotifications() async {
    if (_initialized) {
      return true;
    }

    try {
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        debugPrint(
          'Notification permission not granted: ${settings.authorizationStatus}',
        );
        return false;
      }

      final token = await _fcm.getToken();
      // Security hardening: never print raw push tokens in logs.
      // Tokens are bearer-like identifiers and should be treated as sensitive.
      await _persistTokenForCurrentUser(token);

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
        }
      });

      _openedAppSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
        RemoteMessage message,
      ) {
        debugPrint('A new onMessageOpenedApp event was published!');
      });

      _tokenRefreshSubscription ??= _fcm.onTokenRefresh.listen((
        String refreshedToken,
      ) async {
        await _persistTokenForCurrentUser(refreshedToken);
      });

      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('Notification init skipped: $error');
      return false;
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('Handling a background message: ${message.messageId}');
  }

  Future<void> syncToken(AppUser user) async {
    try {
      final token = await _fcm.getToken();
      if (token != null &&
          (_lastSyncedUserId != user.id || _lastSyncedToken != token)) {
        await DatabaseService().updateFcmToken(userId: user.id, token: token);
        _lastSyncedUserId = user.id;
        _lastSyncedToken = token;
        debugPrint('FCM token synced to Realtime Database');
      }

      final normalizedRole = user.role.toLowerCase().trim();
      if (normalizedRole == 'super_admin' || normalizedRole == 'admin') {
        await _fcm.subscribeToTopic('admin_alerts');
        debugPrint('Subscribed to admin_alerts');
      } else if (hasVendorOperationsAccess(user) &&
          user.storeId != null &&
          user.storeId!.trim().isNotEmpty) {
        await _fcm.subscribeToTopic('store_alerts_${user.storeId}');
        debugPrint('Subscribed to store_alerts_${user.storeId}');
      } else if (hasRiderOperationsAccess(user)) {
        await _fcm.subscribeToTopic('rider_${user.id}');
        debugPrint('Subscribed to rider_${user.id}');
      }
    } catch (e) {
      debugPrint('Sync token failed: $e');
    }
  }

  Future<void> _persistTokenForCurrentUser(String? token) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || token == null || token.isEmpty) {
      return;
    }

    try {
      await DatabaseService().updateFcmToken(
        userId: firebaseUser.uid,
        token: token,
      );
      debugPrint('FCM token persisted for ${firebaseUser.uid}');
    } catch (error) {
      debugPrint('FCM token persistence skipped: $error');
    }
  }
}
