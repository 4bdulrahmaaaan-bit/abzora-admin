import 'dart:math' as math;

import '../services/pose_measurement_service.dart';

class MotionQualityEvaluator {
  TryOnPoseFrame? _previous;
  double _rollingQuality = 0.7;
  final List<double> _motionWindow = <double>[];

  double evaluate(TryOnPoseFrame frame) {
    final previous = _previous;
    _previous = frame;
    if (previous == null) {
      return _rollingQuality;
    }

    final shoulderMotion = _distance(
      previous.shoulderCenter,
      frame.shoulderCenter,
    );
    final hipMotion = _distance(previous.hipCenter, frame.hipCenter);
    final widthVariance = (previous.shoulderWidth - frame.shoulderWidth).abs();
    final rotationDelta = (previous.rotationRadians - frame.rotationRadians).abs();
    final raw =
        1.0 -
        ((shoulderMotion * 1.6) +
            (hipMotion * 1.45) +
            (widthVariance * 1.0) +
            (rotationDelta * 0.7));
    final clamped = raw.clamp(0.0, 1.0);
    _motionWindow.add(clamped);
    if (_motionWindow.length > 20) {
      _motionWindow.removeAt(0);
    }
    final motionMedian = _median(_motionWindow);
    final blended = ((clamped * 0.62) + (motionMedian * 0.38)).clamp(0.0, 1.0);
    _rollingQuality = (_rollingQuality * 0.76) + (blended * 0.24);
    return _rollingQuality.clamp(0.0, 1.0);
  }

  void reset() {
    _previous = null;
    _rollingQuality = 0.7;
    _motionWindow.clear();
  }

  double _distance(NormalizedLandmarkPoint a, NormalizedLandmarkPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  double _median(List<double> values) {
    if (values.isEmpty) {
      return 0.5;
    }
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) * 0.5;
  }
}
