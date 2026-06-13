import 'dart:math' as math;

import '../services/pose_measurement_service.dart';
import 'joint_kalman_filter.dart';

class PoseStabilizationEngine {
  PoseStabilizationEngine({
    this.baseSmoothing = 0.28,
    this.maxJumpThreshold = 0.13,
    this.minSmoothing = 0.12,
    this.maxSmoothing = 0.48,
  });

  final double baseSmoothing;
  final double maxJumpThreshold;
  final double minSmoothing;
  final double maxSmoothing;

  TryOnPoseFrame? _previous;
  DateTime? _lastTimestamp;
  final JointKalmanFilter2D _leftShoulderFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _rightShoulderFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _leftElbowFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _rightElbowFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _leftWristFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _rightWristFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _leftHipFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _rightHipFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _shoulderCenterFilter = JointKalmanFilter2D();
  final JointKalmanFilter2D _hipCenterFilter = JointKalmanFilter2D();
  int _outlierStreak = 0;

  TryOnPoseFrame stabilize(TryOnPoseFrame frame) {
    final previous = _previous;
    final now = DateTime.now();
    final dt = _lastTimestamp == null
        ? 0.016
        : now.difference(_lastTimestamp!).inMilliseconds / 1000.0;
    _lastTimestamp = now;
    final confidence = frame.feedback.progress.clamp(0.0, 1.0);
    final adaptiveSmoothing = _adaptiveSmoothing(
      confidence: confidence,
      dt: dt,
    );

    NormalizedLandmarkPoint kalman(
      JointKalmanFilter2D filter,
      NormalizedLandmarkPoint point,
    ) {
      final state = filter.update(
        mx: point.x,
        my: point.y,
        dt: dt,
        confidence: confidence,
      );
      return NormalizedLandmarkPoint(state.x, state.y);
    }

    final filteredLeftShoulder = kalman(
      _leftShoulderFilter,
      frame.leftShoulder,
    );
    final filteredRightShoulder = kalman(
      _rightShoulderFilter,
      frame.rightShoulder,
    );
    final filteredLeftElbow = kalman(_leftElbowFilter, frame.leftElbow);
    final filteredRightElbow = kalman(_rightElbowFilter, frame.rightElbow);
    final filteredLeftWrist = kalman(_leftWristFilter, frame.leftWrist);
    final filteredRightWrist = kalman(_rightWristFilter, frame.rightWrist);
    final filteredLeftHip = kalman(_leftHipFilter, frame.leftHip);
    final filteredRightHip = kalman(_rightHipFilter, frame.rightHip);
    final filteredShoulderCenter = kalman(
      _shoulderCenterFilter,
      frame.shoulderCenter,
    );
    final filteredHipCenter = kalman(_hipCenterFilter, frame.hipCenter);

    final preSmoothed = TryOnPoseFrame(
      feedback: frame.feedback,
      leftShoulder: filteredLeftShoulder,
      rightShoulder: filteredRightShoulder,
      leftElbow: filteredLeftElbow,
      rightElbow: filteredRightElbow,
      leftWrist: filteredLeftWrist,
      rightWrist: filteredRightWrist,
      leftHip: filteredLeftHip,
      rightHip: filteredRightHip,
      shoulderCenter: filteredShoulderCenter,
      hipCenter: filteredHipCenter,
      shoulderWidth: frame.shoulderWidth,
      torsoHeight: frame.torsoHeight,
      rotationRadians: frame.rotationRadians,
    );

    if (previous == null) {
      _previous = preSmoothed;
      return preSmoothed;
    }

    final outlier = _isOutlier(previous: previous, next: preSmoothed);
    if (outlier) {
      _outlierStreak += 1;
    } else {
      _outlierStreak = 0;
    }
    final recoveryBlend = _outlierStreak >= 2 ? 0.08 : 1.0;
    final stabilizedSmoothing = (adaptiveSmoothing * recoveryBlend).clamp(
      minSmoothing * 0.6,
      maxSmoothing,
    );

    final stabilized = TryOnPoseFrame(
      feedback: preSmoothed.feedback,
      leftShoulder: _stabilizePoint(
        previous.leftShoulder,
        preSmoothed.leftShoulder,
        stabilizedSmoothing,
      ),
      rightShoulder: _stabilizePoint(
        previous.rightShoulder,
        preSmoothed.rightShoulder,
        stabilizedSmoothing,
      ),
      leftElbow: _stabilizePoint(
        previous.leftElbow,
        preSmoothed.leftElbow,
        stabilizedSmoothing,
      ),
      rightElbow: _stabilizePoint(
        previous.rightElbow,
        preSmoothed.rightElbow,
        stabilizedSmoothing,
      ),
      leftWrist: _stabilizePoint(
        previous.leftWrist,
        preSmoothed.leftWrist,
        stabilizedSmoothing,
      ),
      rightWrist: _stabilizePoint(
        previous.rightWrist,
        preSmoothed.rightWrist,
        stabilizedSmoothing,
      ),
      leftHip: _stabilizePoint(
        previous.leftHip,
        preSmoothed.leftHip,
        stabilizedSmoothing,
      ),
      rightHip: _stabilizePoint(
        previous.rightHip,
        preSmoothed.rightHip,
        stabilizedSmoothing,
      ),
      shoulderCenter: _stabilizePoint(
        previous.shoulderCenter,
        preSmoothed.shoulderCenter,
        stabilizedSmoothing,
      ),
      hipCenter: _stabilizePoint(
        previous.hipCenter,
        preSmoothed.hipCenter,
        stabilizedSmoothing,
      ),
      shoulderWidth: _smoothValue(
        previous.shoulderWidth,
        preSmoothed.shoulderWidth,
        stabilizedSmoothing,
      ),
      torsoHeight: _smoothValue(
        previous.torsoHeight,
        preSmoothed.torsoHeight,
        stabilizedSmoothing,
      ),
      rotationRadians: _smoothValue(
        previous.rotationRadians,
        preSmoothed.rotationRadians,
        stabilizedSmoothing,
      ),
    );
    _previous = stabilized;
    return stabilized;
  }

  void reset() {
    _previous = null;
    _lastTimestamp = null;
    _leftShoulderFilter.reset();
    _rightShoulderFilter.reset();
    _leftElbowFilter.reset();
    _rightElbowFilter.reset();
    _leftWristFilter.reset();
    _rightWristFilter.reset();
    _leftHipFilter.reset();
    _rightHipFilter.reset();
    _shoulderCenterFilter.reset();
    _hipCenterFilter.reset();
    _outlierStreak = 0;
  }

  NormalizedLandmarkPoint _stabilizePoint(
    NormalizedLandmarkPoint prev,
    NormalizedLandmarkPoint next,
    double adaptiveSmoothing,
  ) {
    final dx = next.x - prev.x;
    final dy = next.y - prev.y;
    final dist = math.sqrt((dx * dx) + (dy * dy));
    final t = dist > maxJumpThreshold
        ? (minSmoothing * 0.78)
        : adaptiveSmoothing.clamp(minSmoothing, maxSmoothing);
    return NormalizedLandmarkPoint(
      prev.x + ((next.x - prev.x) * t),
      prev.y + ((next.y - prev.y) * t),
    );
  }

  bool _isOutlier({
    required TryOnPoseFrame previous,
    required TryOnPoseFrame next,
  }) {
    final shoulderJump = _pointDistance(
      previous.shoulderCenter,
      next.shoulderCenter,
    );
    final hipJump = _pointDistance(previous.hipCenter, next.hipCenter);
    final widthJump = (previous.shoulderWidth - next.shoulderWidth).abs();
    final torsoJump = (previous.torsoHeight - next.torsoHeight).abs();
    return shoulderJump > (maxJumpThreshold * 1.3) ||
        hipJump > (maxJumpThreshold * 1.25) ||
        widthJump > 0.11 ||
        torsoJump > 0.13;
  }

  double _pointDistance(NormalizedLandmarkPoint a, NormalizedLandmarkPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  double _smoothValue(double prev, double next, double adaptiveSmoothing) {
    final delta = (next - prev).abs();
    final t = delta > 0.18
        ? (adaptiveSmoothing * 0.72).clamp(minSmoothing, maxSmoothing)
        : (adaptiveSmoothing * 1.08).clamp(minSmoothing, maxSmoothing);
    return prev + ((next - prev) * t);
  }

  double _adaptiveSmoothing({required double confidence, required double dt}) {
    final confidenceBoost = (0.6 + (confidence * 0.5)).clamp(0.45, 1.05);
    final dtPenalty = dt > 0.04 ? 0.82 : 1.0;
    return (baseSmoothing * confidenceBoost * dtPenalty).clamp(
      minSmoothing,
      maxSmoothing,
    );
  }
}
