import '../models/ar_intelligence_models.dart';
import '../models/body_fit_intelligence_models.dart';
import 'pose_measurement_service.dart';

class BodyProfileEngine {
  const BodyProfileEngine();

  BodyProfile build({
    required TryOnPoseFrame frame,
    required TrackingReliabilityScore tracking,
  }) {
    final shoulderProportion = frame.shoulderWidth.clamp(0.0, 1.0);
    final torsoProportion = frame.torsoHeight.clamp(0.0, 1.5);
    final silhouetteIndex = (torsoProportion / (shoulderProportion + 0.01))
        .clamp(0.0, 3.0);
    final tilt = frame.rotationRadians.clamp(-1.0, 1.0);
    final postureTendency = _postureFromTilt(tilt);
    final shape = _shapeFromSilhouette(silhouetteIndex);
    final fitHint = _fitHintFromShape(shape, postureTendency);

    final proportionReliability =
        (frame.feedback.progress * 0.7 + tracking.coverage * 0.3)
            .clamp(0.0, 1.0);
    final postureReliability =
        (1.0 - tilt.abs()).clamp(0.0, 1.0) * tracking.stability;
    final overall = ((tracking.overall * 0.5) +
            (proportionReliability * 0.3) +
            (postureReliability * 0.2))
        .clamp(0.0, 1.0);

    return BodyProfile(
      shapeClass: shape,
      proportions: ProportionAnalysis(
        shoulderProportion: shoulderProportion,
        torsoProportion: torsoProportion,
        silhouetteIndex: silhouetteIndex,
      ),
      posture: PostureAnalysis(
        tendency: postureTendency,
        tiltRadians: tilt,
      ),
      fitPreferenceHint: fitHint,
      confidence: BodyConfidence(
        overall: overall,
        poseReliability: tracking.overall,
        proportionReliability: proportionReliability,
        postureReliability: postureReliability,
      ),
    );
  }

  PostureTendency _postureFromTilt(double tilt) {
    if (tilt <= -0.22) return PostureTendency.slightLeanLeft;
    if (tilt >= 0.22) return PostureTendency.slightLeanRight;
    if (tilt.abs() >= 0.12) return PostureTendency.forwardShoulders;
    return PostureTendency.neutral;
  }

  BodyShapeClass _shapeFromSilhouette(double silhouetteIndex) {
    if (silhouetteIndex >= 2.1) return BodyShapeClass.straight;
    if (silhouetteIndex >= 1.7) return BodyShapeClass.balanced;
    if (silhouetteIndex >= 1.35) return BodyShapeClass.athletic;
    return BodyShapeClass.curved;
  }

  FitPreferenceType _fitHintFromShape(
    BodyShapeClass shape,
    PostureTendency posture,
  ) {
    if (posture == PostureTendency.forwardShoulders) {
      return FitPreferenceType.relaxed;
    }
    switch (shape) {
      case BodyShapeClass.athletic:
        return FitPreferenceType.trueToSize;
      case BodyShapeClass.curved:
        return FitPreferenceType.relaxed;
      case BodyShapeClass.straight:
        return FitPreferenceType.oversized;
      case BodyShapeClass.balanced:
        return FitPreferenceType.trueToSize;
    }
  }
}
