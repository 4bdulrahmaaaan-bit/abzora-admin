import 'dart:async';

import '../models/mediapipe_try_on_payload.dart';
import 'ar_quality_scaler.dart';

class MediaPipeArService {
  MediaPipeArService._();

  static final MediaPipeArService instance = MediaPipeArService._();

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  Timer? _bootTimer;
  bool _sessionActive = false;
  ArQualityProfile? _qualityProfile;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> initializeTryOn(MediaPipeTryOnPayload payload) async {
    _sessionActive = true;
    _eventsController.add(<String, dynamic>{
      'type': 'arTrackingState',
      'state': 'initializing',
      'productId': payload.productId,
    });
    _bootTimer?.cancel();
    _bootTimer = Timer(const Duration(milliseconds: 260), () {
      if (!_sessionActive) {
        return;
      }
      _eventsController.add(<String, dynamic>{
        'type': 'onLoaded',
        'productId': payload.productId,
      });
      _eventsController.add(<String, dynamic>{
        'type': 'arTrackingState',
        'state': 'tracking',
        'productId': payload.productId,
      });
      if (_qualityProfile != null) {
        _eventsController.add(<String, dynamic>{
          'type': 'quality_profile_updated',
          ..._qualityProfile!.toMap(),
        });
      }
    });
  }

  Future<void> updateMeasurements(Map<String, double> measurements) async {}

  Future<void> updateQualityProfile(ArQualityProfile profile) async {
    _qualityProfile = profile;
    if (!_sessionActive) {
      return;
    }
    _eventsController.add(<String, dynamic>{
      'type': 'quality_profile_updated',
      ...profile.toMap(),
    });
  }

  Future<void> updatePose(Map<String, dynamic> poseFrame) async {
    if (!_sessionActive) {
      return;
    }
    final confidence =
        ((poseFrame['trackingReliability'] as num?)?.toDouble() ?? 0.8).clamp(
          0.0,
          1.0,
        );
    _eventsController.add(<String, dynamic>{
      'type': 'onBodyDetection',
      'detected': true,
      'confidence': confidence,
    });
  }

  Future<String?> capture() async => null;

  Future<void> disposeSession() async {
    _sessionActive = false;
    _bootTimer?.cancel();
    _eventsController.add(<String, dynamic>{
      'type': 'arTrackingState',
      'state': 'stopped',
    });
  }

  Future<void> updateGarmentConfig(MediaPipeTryOnPayload payload) async {
    if (!_sessionActive) {
      return;
    }
    _eventsController.add(<String, dynamic>{
      'type': 'onFitCalculated',
      'recommendedSize': 'M',
      'fitScore': 84,
      'confidence': 0.86,
      'fitLabel': 'Balanced drape',
      'productId': payload.productId,
      'templateId': payload.templateId,
    });
  }

  Future<void> setViewTransform({
    required double rotateY,
    required double zoom,
  }) async {}

  Future<void> pause() async {
    _eventsController.add(<String, dynamic>{
      'type': 'arTrackingState',
      'state': 'limited',
    });
  }

  Future<void> resume() async {
    if (!_sessionActive) {
      return;
    }
    _eventsController.add(<String, dynamic>{
      'type': 'arTrackingState',
      'state': 'tracking',
    });
    if (_qualityProfile != null) {
      _eventsController.add(<String, dynamic>{
        'type': 'quality_profile_updated',
        ..._qualityProfile!.toMap(),
      });
    }
  }

  void dispose() {
    _bootTimer?.cancel();
    _sessionActive = false;
  }
}
