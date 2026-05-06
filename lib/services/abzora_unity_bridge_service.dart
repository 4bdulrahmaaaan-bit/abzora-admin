import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import '../models/abzora_unity_try_on_payload.dart';

class AbzoraUnityBridgeService {
  AbzoraUnityBridgeService._();

  static final AbzoraUnityBridgeService instance = AbzoraUnityBridgeService._();

  UnityWidgetController? _controller;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void attachController(UnityWidgetController controller) {
    _controller = controller;
  }

  Future<void> initializeTryOn(AbzoraUnityTryOnPayload payload) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('Unity controller not attached.');
    }

    await controller.postMessage(
      'FlutterUnityBridge',
      'InitializeTryOn',
      payload.toJson(),
    );
  }

  Future<void> updateMeasurements(Map<String, double> measurements) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final json = jsonEncode(<String, dynamic>{'measurements': measurements});
    await controller.postMessage('FlutterUnityBridge', 'SetMeasurements', json);
  }

  Future<void> updatePose(Map<String, dynamic> poseFrame) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final json = jsonEncode(<String, dynamic>{'poseFrame': poseFrame});
    await controller.postMessage('FlutterUnityBridge', 'UpdatePose', json);
  }

  Future<String?> capture() async {
    final controller = _controller;
    if (controller == null) {
      return null;
    }
    await controller.postMessage('FlutterUnityBridge', 'Capture', '');
    return null;
  }

  Future<void> disposeSession() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.postMessage('FlutterUnityBridge', 'DisposeSession', '');
  }

  Future<void> updateGarmentConfig(AbzoraUnityTryOnPayload payload) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.postMessage(
      'FlutterUnityBridge',
      'UpdateGarmentConfig',
      payload.toJson(),
    );
  }

  Future<void> setViewTransform({
    required double rotateY,
    required double zoom,
  }) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final json = jsonEncode(<String, dynamic>{
      'rotateY': rotateY,
      'zoom': zoom,
    });
    await controller.postMessage('FlutterUnityBridge', 'SetViewTransform', json);
  }

  Future<void> pause() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.resume();
    } catch (_) {}
  }

  void onUnityMessage(dynamic message) {
    final raw = message.toString();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _eventsController.add(decoded);
        return;
      }
      if (decoded is Map) {
        _eventsController.add(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[ABZORA Unity] non-json message: $raw');
      }
    }
  }

  void dispose() {
    _controller = null;
    _eventsController.close();
  }
}
