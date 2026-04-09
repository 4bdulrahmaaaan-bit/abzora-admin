import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ar_try_on_models.dart';

class RealTimeArTryOnBridge {
  RealTimeArTryOnBridge._();

  static final RealTimeArTryOnBridge instance = RealTimeArTryOnBridge._();

  static const MethodChannel _channel = MethodChannel('abzora/realtime_ar_try_on');
  static const EventChannel _events = EventChannel('abzora/realtime_ar_try_on/events');

  Stream<Map<String, dynamic>>? _renderEvents;

  Future<void> initialize({
    required ArTryOnProductMetadata metadata,
    bool preferBackCamera = false,
    bool enableOcclusion = true,
  }) async {
    await _channel.invokeMethod<void>('initialize', {
      'productId': metadata.id,
      'overlayAssetUrl': metadata.overlayAssetUrl,
      'transparentAssetUrl': metadata.transparentAssetUrl,
      'model3dUrl': metadata.model3dUrl,
      'alignmentConfig': metadata.alignmentConfig,
      'arAsset': metadata.arAsset,
      'preferBackCamera': preferBackCamera,
      'enableOcclusion': enableOcclusion,
      'platform': defaultTargetPlatform.name,
    });
  }

  Future<void> updateGarment(ArTryOnProductMetadata metadata) async {
    await _channel.invokeMethod<void>('updateGarment', {
      'productId': metadata.id,
      'overlayAssetUrl': metadata.overlayAssetUrl,
      'transparentAssetUrl': metadata.transparentAssetUrl,
      'model3dUrl': metadata.model3dUrl,
      'alignmentConfig': metadata.alignmentConfig,
      'arAsset': metadata.arAsset,
    });
  }

  Future<void> updatePoseFrame({
    required Map<String, dynamic> poseFrame,
    required Size viewportSize,
    required bool bodyDetected,
    double lightingScore = 0.5,
  }) async {
    await _channel.invokeMethod<void>('updatePoseFrame', {
      'poseFrame': poseFrame,
      'viewportWidth': viewportSize.width,
      'viewportHeight': viewportSize.height,
      'bodyDetected': bodyDetected,
      'lightingScore': lightingScore,
    });
  }

  Future<void> setCameraFacing({required bool front}) async {
    await _channel.invokeMethod<void>('setCameraFacing', {'front': front});
  }

  Future<String?> capturePreview() async {
    final payload = await _channel.invokeMethod<String>('capturePreview');
    return payload?.trim().isEmpty ?? true ? null : payload?.trim();
  }

  Stream<Map<String, dynamic>> get renderEvents {
    return _renderEvents ??= _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return const <String, dynamic>{};
    });
  }

  Future<void> dispose() => _channel.invokeMethod<void>('dispose');

  String get platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
