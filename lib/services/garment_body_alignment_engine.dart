import '../models/body_fit_intelligence_models.dart';
import 'pose_measurement_service.dart';

class GarmentAlignmentSnapshot {
  const GarmentAlignmentSnapshot({
    required this.attachmentConfidence,
    required this.shoulderScale,
    required this.chestScale,
    required this.torsoScale,
    required this.waistScale,
    required this.hipScale,
    required this.rotationRadians,
    required this.anchorShoulderLeftX,
    required this.anchorShoulderLeftY,
    required this.anchorShoulderRightX,
    required this.anchorShoulderRightY,
    required this.anchorCenterX,
    required this.anchorCenterY,
    required this.anchorWaistX,
    required this.anchorWaistY,
    required this.anchorHipX,
    required this.anchorHipY,
    required this.torsoLeanRadians,
    required this.shoulderSlopeRadians,
    required this.chestCenterX,
    required this.chestCenterY,
    required this.waistTaperFactor,
    required this.stabilityScore,
  });

  final double attachmentConfidence;
  final double shoulderScale;
  final double chestScale;
  final double torsoScale;
  final double waistScale;
  final double hipScale;
  final double rotationRadians;
  final double anchorShoulderLeftX;
  final double anchorShoulderLeftY;
  final double anchorShoulderRightX;
  final double anchorShoulderRightY;
  final double anchorCenterX;
  final double anchorCenterY;
  final double anchorWaistX;
  final double anchorWaistY;
  final double anchorHipX;
  final double anchorHipY;
  final double torsoLeanRadians;
  final double shoulderSlopeRadians;
  final double chestCenterX;
  final double chestCenterY;
  final double waistTaperFactor;
  final double stabilityScore;
}

class GarmentBodyAlignmentEngine {
  GarmentAlignmentSnapshot? _previous;

  GarmentAlignmentSnapshot compute({
    required TryOnPoseFrame frame,
    required BodyProfile bodyProfile,
    required double trackingReliability,
    required double segmentationReliability,
  }) {
    const shoulderBaseline = 0.34;
    const torsoBaseline = 0.30;
    final shoulderRatio = (frame.shoulderWidth / shoulderBaseline).clamp(
      0.84,
      1.46,
    );
    final torsoRatio = (frame.torsoHeight / torsoBaseline).clamp(0.86, 1.42);
    final silhouette = bodyProfile.proportions.silhouetteIndex.clamp(0.8, 2.5);
    final silhouetteBias = ((silhouette - 1.55) * 0.08).clamp(-0.09, 0.09);
    final postureTilt = bodyProfile.posture.tiltRadians.clamp(-0.4, 0.4);
    final postureBias = (postureTilt * 0.08).clamp(-0.03, 0.03);

    final shoulderScale = (shoulderRatio + silhouetteBias + postureBias).clamp(
      0.88,
      1.38,
    );
    final chestScale = ((shoulderScale * 0.78) + (torsoRatio * 0.22)).clamp(
      0.9,
      1.34,
    );
    final torsoScale =
        ((torsoRatio * 0.8) +
                (silhouetteBias * 0.2) +
                (postureBias * 0.1) +
                0.2)
            .clamp(0.88, 1.34);
    final waistScale = ((torsoScale * 0.72) + (silhouetteBias * 0.42) + 0.18)
        .clamp(0.72, 1.22);
    final hipScale = ((waistScale * 0.92) + 0.08).clamp(0.78, 1.28);

    final confidence =
        ((trackingReliability * 0.55) +
                (segmentationReliability * 0.25) +
                (bodyProfile.confidence.overall * 0.2))
            .clamp(0.0, 1.0);
    final smoothing = (0.10 + (confidence * 0.34)).clamp(0.10, 0.44);
    final torsoLean = frame.rotationRadians.clamp(-0.9, 0.9);
    final shoulderSlopeRadians = frame.rotationRadians.clamp(-0.45, 0.45);
    final shoulderCenterY = frame.shoulderCenter.y.clamp(0.0, 1.0);
    final hipCenterY = frame.hipCenter.y.clamp(0.0, 1.0);
    final chestCenterX =
        (frame.shoulderCenter.x +
                ((frame.hipCenter.x - frame.shoulderCenter.x) * 0.18))
            .clamp(0.0, 1.0);
    final chestCenterY =
        (shoulderCenterY + ((hipCenterY - shoulderCenterY) * 0.30)).clamp(
          0.0,
          1.0,
        );
    final verticalCenterY = ((shoulderCenterY * 0.74) + (chestCenterY * 0.26))
        .clamp(0.0, 1.0);
    final waistY = ((shoulderCenterY * 0.35) + (hipCenterY * 0.65)).clamp(
      0.0,
      1.0,
    );
    final torsoSlopeX = (frame.hipCenter.x - frame.shoulderCenter.x).clamp(
      -0.16,
      0.16,
    );
    final centerX = (frame.shoulderCenter.x + (torsoSlopeX * 0.30)).clamp(
      0.0,
      1.0,
    );
    final waistX =
        ((frame.shoulderCenter.x * 0.45) + (frame.hipCenter.x * 0.55)).clamp(
          0.0,
          1.0,
        );
    final stabilityScore =
        ((confidence * 0.7) +
                (bodyProfile.confidence.proportionReliability * 0.3))
            .clamp(0.0, 1.0);
    final waistTaperFactor = (waistScale / shoulderScale).clamp(0.68, 1.05);

    final computed = GarmentAlignmentSnapshot(
      attachmentConfidence: confidence,
      shoulderScale: shoulderScale,
      chestScale: chestScale,
      torsoScale: torsoScale,
      waistScale: waistScale,
      hipScale: hipScale,
      rotationRadians: torsoLean,
      anchorShoulderLeftX: frame.leftShoulder.x.clamp(0.0, 1.0),
      anchorShoulderLeftY: frame.leftShoulder.y.clamp(0.0, 1.0),
      anchorShoulderRightX: frame.rightShoulder.x.clamp(0.0, 1.0),
      anchorShoulderRightY: frame.rightShoulder.y.clamp(0.0, 1.0),
      anchorCenterX: centerX,
      anchorCenterY: verticalCenterY,
      anchorWaistX: waistX,
      anchorWaistY: waistY,
      anchorHipX: frame.hipCenter.x.clamp(0.0, 1.0),
      anchorHipY: hipCenterY,
      torsoLeanRadians: postureTilt,
      shoulderSlopeRadians: shoulderSlopeRadians,
      chestCenterX: chestCenterX,
      chestCenterY: chestCenterY,
      waistTaperFactor: waistTaperFactor,
      stabilityScore: stabilityScore,
    );

    final previous = _previous;
    if (previous == null) {
      _previous = computed;
      return computed;
    }

    double blend(double a, double b) => a + ((b - a) * smoothing);
    final stabilized = GarmentAlignmentSnapshot(
      attachmentConfidence: blend(
        previous.attachmentConfidence,
        computed.attachmentConfidence,
      ),
      shoulderScale: blend(previous.shoulderScale, computed.shoulderScale),
      chestScale: blend(previous.chestScale, computed.chestScale),
      torsoScale: blend(previous.torsoScale, computed.torsoScale),
      waistScale: blend(previous.waistScale, computed.waistScale),
      hipScale: blend(previous.hipScale, computed.hipScale),
      rotationRadians: blend(
        previous.rotationRadians,
        computed.rotationRadians,
      ),
      anchorShoulderLeftX: blend(
        previous.anchorShoulderLeftX,
        computed.anchorShoulderLeftX,
      ),
      anchorShoulderLeftY: blend(
        previous.anchorShoulderLeftY,
        computed.anchorShoulderLeftY,
      ),
      anchorShoulderRightX: blend(
        previous.anchorShoulderRightX,
        computed.anchorShoulderRightX,
      ),
      anchorShoulderRightY: blend(
        previous.anchorShoulderRightY,
        computed.anchorShoulderRightY,
      ),
      anchorCenterX: blend(previous.anchorCenterX, computed.anchorCenterX),
      anchorCenterY: blend(previous.anchorCenterY, computed.anchorCenterY),
      anchorWaistX: blend(previous.anchorWaistX, computed.anchorWaistX),
      anchorWaistY: blend(previous.anchorWaistY, computed.anchorWaistY),
      anchorHipX: blend(previous.anchorHipX, computed.anchorHipX),
      anchorHipY: blend(previous.anchorHipY, computed.anchorHipY),
      torsoLeanRadians: blend(
        previous.torsoLeanRadians,
        computed.torsoLeanRadians,
      ),
      shoulderSlopeRadians: blend(
        previous.shoulderSlopeRadians,
        computed.shoulderSlopeRadians,
      ),
      chestCenterX: blend(previous.chestCenterX, computed.chestCenterX),
      chestCenterY: blend(previous.chestCenterY, computed.chestCenterY),
      waistTaperFactor: blend(
        previous.waistTaperFactor,
        computed.waistTaperFactor,
      ),
      stabilityScore: blend(previous.stabilityScore, computed.stabilityScore),
    );
    _previous = stabilized;
    return stabilized;
  }

  void reset() {
    _previous = null;
  }
}
