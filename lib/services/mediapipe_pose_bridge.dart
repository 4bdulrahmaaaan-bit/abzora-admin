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
  final Map<String, MediaPipePoseLandmark> _previousByType =
      <String, MediaPipePoseLandmark>{};

  static const double _visibilityThreshold = 0.08;
  static const double _smoothingT = 0.28;
  int _processedFrames = 0;
  int _failedFrames = 0;
  double _avgLatencyMs = 0;
  double _lastLatencyMs = 0;

  Stream<List<MediaPipePoseLandmark>> get landmarksStream =>
      _landmarksController.stream;

  Future<void> ensureInitialized({
    String modelAssetPath = 'ml/pose_landmarker_lite.task',
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
            'MediaPipe Pose could not initialize. Ensure pose_landmarker_lite.task is bundled at android/app/src/main/assets/ml/pose_landmarker_lite.task.',
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
    final started = DateTime.now();
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'processFrame',
      frame.toMap(),
    );
    final latency = DateTime.now().difference(started).inMilliseconds.toDouble();
    _processedFrames += 1;
    _lastLatencyMs = latency;
    _avgLatencyMs = _processedFrames <= 1
        ? latency
        : ((_avgLatencyMs * 0.85) + (latency * 0.15));
    if (raw == null || raw.isEmpty) {
      _failedFrames += 1;
      return _handlePoseLoss();
    }
    return _optimizeLandmarks(
      raw.whereType<Map>().map(MediaPipePoseLandmark.fromMap).toList(),
    );
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
      return _handlePoseLoss();
    }
    return _optimizeLandmarks(
      raw.whereType<Map>().map(MediaPipePoseLandmark.fromMap).toList(),
    );
  }

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<bool>('dispose');
    } catch (_) {
      // Ignore dispose failures.
    }
    await _landmarksController.close();
  }

  Future<Map<String, dynamic>> diagnostics() async {
    await ensureInitialized();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDiagnostics',
      );
      if (raw != null) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    final total = _processedFrames + _failedFrames;
    return <String, dynamic>{
      'processedFrames': _processedFrames,
      'failedFrames': _failedFrames,
      'errorRate': total == 0 ? 0 : (_failedFrames / total),
      'lastLatencyMs': _lastLatencyMs,
      'avgLatencyMs': _avgLatencyMs,
      'callbackEnabled': true,
    };
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
    final optimized = mapped.isEmpty ? _handlePoseLoss() : _optimizeLandmarks(mapped);
    if (!_landmarksController.isClosed) {
      _landmarksController.add(optimized);
    }
  }

  List<MediaPipePoseLandmark> _optimizeLandmarks(
    List<MediaPipePoseLandmark> incoming,
  ) {
    final nextByType = <String, MediaPipePoseLandmark>{};
    for (final landmark in incoming) {
      final key = landmark.type.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      final previous = _previousByType[key];
      if (landmark.visibility < _visibilityThreshold) {
        if (previous != null) {
          nextByType[key] = MediaPipePoseLandmark(
            type: previous.type,
            x: previous.x,
            y: previous.y,
            z: previous.z,
            visibility: previous.visibility * 0.9,
          );
        }
        continue;
      }
      if (previous == null) {
        nextByType[key] = landmark;
      } else {
        nextByType[key] = MediaPipePoseLandmark(
          type: landmark.type,
          x: _lerp(previous.x, landmark.x, _smoothingT),
          y: _lerp(previous.y, landmark.y, _smoothingT),
          z: _lerp(previous.z, landmark.z, _smoothingT),
          visibility: _lerp(previous.visibility, landmark.visibility, 0.4),
        );
      }
    }
    _previousByType
      ..clear()
      ..addAll(nextByType);

    final ordered = nextByType.values.toList(growable: false)
      ..sort((a, b) => a.type.compareTo(b.type));
    return ordered;
  }

  List<MediaPipePoseLandmark> _handlePoseLoss() {
    if (_previousByType.isEmpty) {
      return const [];
    }
    final decayed = <String, MediaPipePoseLandmark>{};
    for (final entry in _previousByType.entries) {
      final value = entry.value;
      final nextVisibility = value.visibility * 0.78;
      if (nextVisibility < 0.12) {
        continue;
      }
      decayed[entry.key] = MediaPipePoseLandmark(
        type: value.type,
        x: value.x,
        y: value.y,
        z: value.z,
        visibility: nextVisibility,
      );
    }
    _previousByType
      ..clear()
      ..addAll(decayed);
    return decayed.values.toList(growable: false)
      ..sort((a, b) => a.type.compareTo(b.type));
  }

  double _lerp(double a, double b, double t) => a + ((b - a) * t);
}
