import '../models/ar_intelligence_models.dart';
import 'pose_measurement_service.dart';

class BodyMetricsEngine {
  BodyMetricsSnapshot analyze(TryOnPoseFrame frame) {
    final shoulderWidth = frame.shoulderWidth.clamp(0.01, 1.2);
    final torsoHeight = frame.torsoHeight.clamp(0.01, 1.4);
    final torsoRatio = (torsoHeight / shoulderWidth).clamp(0.2, 5.0);
    final waistHipRatio = (shoulderWidth / (shoulderWidth * 0.86)).clamp(
      0.6,
      1.8,
    );
    final postureTilt = frame.rotationRadians.clamp(-1.2, 1.2);

    final visibility = frame.feedback.progress.clamp(0.0, 1.0);
    final confidenceProfile = BodyConfidenceProfile(
      overall: visibility,
      shoulderConfidence: (visibility * 0.96).clamp(0.0, 1.0),
      torsoConfidence: (visibility * 0.92).clamp(0.0, 1.0),
      hipConfidence: (visibility * 0.9).clamp(0.0, 1.0),
    );

    return BodyMetricsSnapshot(
      shoulderWidthNorm: shoulderWidth,
      torsoRatio: torsoRatio,
      waistHipRatio: waistHipRatio,
      postureTilt: postureTilt,
      confidenceProfile: confidenceProfile,
    );
  }
}
