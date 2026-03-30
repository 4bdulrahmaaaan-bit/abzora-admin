import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/models.dart';
import 'database_service.dart';

class NotificationService {
  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

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

      final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        debugPrint('Notification permission not granted: ${settings.authorizationStatus}');
        return false;
      }

      final token = await _fcm.getToken();
      debugPrint('FCM Token: $token');
      await _persistTokenForCurrentUser(token);

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
        }
      });

      _openedAppSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
      });

      _tokenRefreshSubscription ??= _fcm.onTokenRefresh.listen((String refreshedToken) async {
        await _persistTokenForCurrentUser(refreshedToken);
      });

      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('Notification init skipped: $error');
      return false;
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Handling a background message: ${message.messageId}");
  }

  Future<void> syncToken(AppUser user) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await DatabaseService().updateFcmToken(userId: user.id, token: token);
        debugPrint('FCM token synced to Realtime Database');
      }
      
      if (user.role == 'super_admin' || user.role == 'admin') {
        await _fcm.subscribeToTopic('admin_alerts');
        debugPrint('Subscribed to admin_alerts');
      } else if (user.role == 'vendor' && user.storeId != null) {
        await _fcm.subscribeToTopic('store_alerts_${user.storeId}');
        debugPrint('Subscribed to store_alerts_${user.storeId}');
      } else if (user.role == 'rider') {
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
      await DatabaseService().updateFcmToken(userId: firebaseUser.uid, token: token);
      debugPrint('FCM token persisted for ${firebaseUser.uid}');
    } catch (error) {
      debugPrint('FCM token persistence skipped: $error');
    }
  }
}
