import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ar_try_on_models.dart';

class UnityTryOnBridge {
  UnityTryOnBridge._();

  static final UnityTryOnBridge instance = UnityTryOnBridge._();

  static const MethodChannel _channel = MethodChannel('abzora/unity_try_on');
  static const EventChannel _events = EventChannel('abzora/unity_try_on/events');

  Stream<Map<String, dynamic>>? _unityEvents;

  Future<void> initialize({
    required ArTryOnProductMetadata metadata,
    Map<String, double> measurements = const {},
    bool enableAvatar = true,
  }) async {
    await _channel.invokeMethod<void>('initialize', {
      'productId': metadata.id,
      'name': metadata.name,
      'category': metadata.category,
      'model3dUrl': metadata.model3dUrl,
      'unityAssetBundleUrl': metadata.unityAssetBundleUrl,
      'rigProfile': metadata.rigProfile,
      'materialProfile': metadata.materialProfile,
      'overlayAssetUrl': metadata.overlayAssetUrl,
      'alignmentConfig': metadata.alignmentConfig,
      'measurements': measurements,
      'enableAvatar': enableAvatar,
      'platform': defaultTargetPlatform.name,
    });
  }

  Future<void> loadGarment(ArTryOnProductMetadata metadata) async {
    await _channel.invokeMethod<void>('loadGarment', {
      'productId': metadata.id,
      'model3dUrl': metadata.model3dUrl,
      'unityAssetBundleUrl': metadata.unityAssetBundleUrl,
      'rigProfile': metadata.rigProfile,
      'materialProfile': metadata.materialProfile,
      'overlayAssetUrl': metadata.overlayAssetUrl,
      'alignmentConfig': metadata.alignmentConfig,
    });
  }

  Future<void> updatePose(Map<String, dynamic> poseFrame) async {
    await _channel.invokeMethod<void>('updatePose', {
      'poseFrame': poseFrame,
    });
  }

  Future<void> setMeasurements(Map<String, double> measurements) async {
    await _channel.invokeMethod<void>('setMeasurements', {
      'measurements': measurements,
    });
  }

  Future<String?> capture() async {
    final path = await _channel.invokeMethod<String>('capture');
    return path?.trim().isEmpty ?? true ? null : path?.trim();
  }

  Future<void> dispose() => _channel.invokeMethod<void>('dispose');

  Stream<Map<String, dynamic>> get events {
    return _unityEvents ??= _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return const <String, dynamic>{};
    });
  }
}
