import 'dart:async';
import 'package:flutter/services.dart';

class MediaPipePoseFrameInput {
  const MediaPipePoseFrameInput({
    required this.jpegBytes,
    required this.width,
    required this.height,
    required this.rotation,
    required this.timestampMs,
  });

  final Uint8List jpegBytes;
  final int width;
  final int height;
  final int rotation;
  final int timestampMs;

  Map<String, dynamic> toMap() {
    return {
      'jpegBytes': jpegBytes,
      'width': width,
      'height': height,
      'rotation': rotation,
      'timestampMs': timestampMs,
    };
  }
}

class MediaPipePoseLandmark {
  const MediaPipePoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  final String type;
  final double x;
  final double y;
  final double z;
  final double visibility;

  factory MediaPipePoseLandmark.fromMap(Map<dynamic, dynamic> map) {
    return MediaPipePoseLandmark(
      type: map['type']?.toString() ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      z: (map['z'] as num?)?.toDouble() ?? 0,
      visibility: (map['visibility'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MediaPipePoseBridge {
  MediaPipePoseBridge._();
  static final MediaPipePoseBridge instance = MediaPipePoseBridge._();

  static const MethodChannel _channel = MethodChannel('abzora/mediapipe_pose');
  final StreamController<List<MediaPipePoseLandmark>> _landmarksController =
      StreamController<List<MediaPipePoseLandmark>>.broadcast();

  bool _initialized = false;
  bool _callbackBound = false;

  Stream<List<MediaPipePoseLandmark>> get landmarksStream =>
      _landmarksController.stream;

  Future<void> ensureInitialized({
    String modelAssetPath = 'assets/ml/pose_landmarker_lite.task',
  }) async {
    if (_initialized) {
      return;
    }
    final ok = await _channel.invokeMethod<bool>(
          'initialize',
          {'modelAssetPath': modelAssetPath},
        ) ??
        false;
    if (!ok) {
      throw PlatformException(
        code: 'mediapipe_init_failed',
        message:
            'MediaPipe Pose could not initialize. Ensure pose_landmarker_lite.task is bundled at assets/ml/pose_landmarker_lite.task.',
      );
    }
    if (!_callbackBound) {
      _channel.setMethodCallHandler(_handleNativeCallback);
      _callbackBound = true;
    }
    _initialized = true;
  }

  Future<void> setPoseCallbackEnabled(bool enabled) async {
    await ensureInitialized();
    await _channel.invokeMethod<bool>(
      'setPoseCallbackEnabled',
      {'enabled': enabled},
    );
  }

  Future<List<MediaPipePoseLandmark>> processFrame(
    MediaPipePoseFrameInput frame,
  ) async {
    await ensureInitialized();
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'processFrame',
      frame.toMap(),
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(MediaPipePoseLandmark.fromMap)
        .toList(growable: false);
  }

  Future<List<MediaPipePoseLandmark>> processImagePath(
    String imagePath, {
    int rotation = 0,
  }) async {
    await ensureInitialized();
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'processImagePath',
      {
        'path': imagePath,
        'rotation': rotation,
      },
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(MediaPipePoseLandmark.fromMap)
        .toList(growable: false);
  }

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<bool>('dispose');
    } catch (_) {
      // Ignore dispose failures.
    }
    await _landmarksController.close();
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method != 'onPose') {
      return;
    }
    final raw = call.arguments as List<dynamic>? ?? const <dynamic>[];
    final mapped = raw
        .whereType<Map>()
        .map(MediaPipePoseLandmark.fromMap)
        .toList(growable: false);
    if (!_landmarksController.isClosed) {
      _landmarksController.add(mapped);
    }
  }
}
