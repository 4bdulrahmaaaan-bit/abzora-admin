import '../models/ar_intelligence_models.dart';
import 'pose_measurement_service.dart';

class TrackingReliabilityEngine {
  double _rollingOverall = 0.7;
  TrackingConfidenceState _state = TrackingConfidenceState.stable;

  TrackingReliabilityScore evaluate({
    required TryOnPoseFrame frame,
    required double motionQuality,
  }) {
    final coverage = frame.feedback.progress.clamp(0.0, 1.0);
    final rotationStability =
        (1.0 - (frame.rotationRadians.abs() / 1.2)).clamp(0.0, 1.0);
    final widthStability =
        (1.0 - ((frame.shoulderWidth - 0.2).abs() * 2.8)).clamp(0.0, 1.0);
    final torsoStability =
        (1.0 - ((frame.torsoHeight - 0.34).abs() * 2.0)).clamp(0.0, 1.0);
    final geometricCoherence = _coherence(frame);
    final centerBias = _centerBias(frame);
    final stability =
        (rotationStability * 0.34) +
        (widthStability * 0.22) +
        (torsoStability * 0.2) +
        (geometricCoherence * 0.18) +
        (centerBias * 0.06);
    final instantaneousOverall =
        (coverage * 0.38) + (stability * 0.38) + (motionQuality * 0.24);
    _rollingOverall = ((_rollingOverall * 0.74) + (instantaneousOverall * 0.26))
        .clamp(0.0, 1.0);
    final lowLightRisk = (1.0 - coverage).clamp(0.0, 1.0);
    final fastMotionRisk = (1.0 - motionQuality).clamp(0.0, 1.0);
    final partialBodyRisk = (1.0 - centerBias).clamp(0.0, 1.0);
    _state = _nextState(
      overall: _rollingOverall,
      coverage: coverage,
      motionQuality: motionQuality,
      centerBias: centerBias,
    );
    return TrackingReliabilityScore(
      overall: _rollingOverall.clamp(0.0, 1.0),
      stability: stability.clamp(0.0, 1.0),
      coverage: coverage,
      motionQuality: motionQuality.clamp(0.0, 1.0),
      confidenceState: _state,
      lowLightRisk: lowLightRisk,
      fastMotionRisk: fastMotionRisk,
      partialBodyRisk: partialBodyRisk,
    );
  }

  double _coherence(TryOnPoseFrame frame) {
    final leftTorsoDx = (frame.leftShoulder.x - frame.leftHip.x).abs();
    final rightTorsoDx = (frame.rightShoulder.x - frame.rightHip.x).abs();
    final symmetry = (1.0 - (leftTorsoDx - rightTorsoDx).abs() * 3.2).clamp(0.0, 1.0);
    final shoulderYDiff = (frame.leftShoulder.y - frame.rightShoulder.y).abs();
    final hipYDiff = (frame.leftHip.y - frame.rightHip.y).abs();
    final lineLevel = (1.0 - ((shoulderYDiff + hipYDiff) * 2.4)).clamp(0.0, 1.0);
    return (symmetry * 0.55) + (lineLevel * 0.45);
  }

  double _centerBias(TryOnPoseFrame frame) {
    final xOffset = (frame.shoulderCenter.x - 0.5).abs();
    final yOffset = (frame.shoulderCenter.y - 0.36).abs();
    return (1.0 - ((xOffset * 1.6) + (yOffset * 1.2))).clamp(0.0, 1.0);
  }

  TrackingConfidenceState _nextState({
    required double overall,
    required double coverage,
    required double motionQuality,
    required double centerBias,
  }) {
    if (overall >= 0.82 && coverage >= 0.74 && motionQuality >= 0.66) {
      return TrackingConfidenceState.locked;
    }
    if (overall >= 0.66 && coverage >= 0.56 && centerBias >= 0.48) {
      return TrackingConfidenceState.stable;
    }
    if (overall >= 0.48) {
      return TrackingConfidenceState.recovering;
    }
    return TrackingConfidenceState.weak;
  }
}
