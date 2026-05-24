import '../models/ar_intelligence_models.dart';
import 'garment_body_alignment_engine.dart';

class GarmentDeformationSnapshot {
  const GarmentDeformationSnapshot({
    required this.deformationStrength,
    required this.secondaryMotionDamping,
    required this.torsoScaleX,
    required this.torsoScaleY,
    required this.chestInflation,
    required this.waistTaper,
    required this.hipEase,
    required this.shoulderTension,
    required this.stability,
  });

  final double deformationStrength;
  final double secondaryMotionDamping;
  final double torsoScaleX;
  final double torsoScaleY;
  final double chestInflation;
  final double waistTaper;
  final double hipEase;
  final double shoulderTension;
  final double stability;
}

class LightweightGarmentDeformationEngine {
  GarmentDeformationSnapshot? _previous;

  GarmentDeformationSnapshot compute({
    required GarmentAlignmentSnapshot alignment,
    required ArDeviceTier deviceTier,
    required double motionQuality,
    required double trackingReliability,
    required double thermalLoad,
  }) {
    final tierBudget = _tierBudget(deviceTier);
    final confidence = ((alignment.attachmentConfidence * 0.55) +
            (trackingReliability * 0.3) +
            ((1 - thermalLoad).clamp(0.0, 1.0) * 0.15))
        .clamp(0.0, 1.0);
    final strength = (tierBudget * confidence).clamp(0.22, 1.0);
    final motionPenalty = (1 - motionQuality).clamp(0.0, 1.0);
    final damping = (0.48 + (motionPenalty * 0.36)).clamp(0.45, 0.88);

    final target = GarmentDeformationSnapshot(
      deformationStrength: strength,
      secondaryMotionDamping: damping,
      torsoScaleX: _blendToOne(alignment.torsoScale, strength, 0.36),
      torsoScaleY: _blendToOne(alignment.torsoScale, strength, 0.2),
      chestInflation: _blendToOne(alignment.chestScale, strength, 0.48),
      waistTaper: _blendToOne(alignment.waistScale, strength, 0.52),
      hipEase: _blendToOne(alignment.hipScale, strength, 0.45),
      shoulderTension: _blendToOne(alignment.shoulderScale, strength, 0.42),
      stability: ((alignment.stabilityScore * 0.65) + (motionQuality * 0.35))
          .clamp(0.0, 1.0),
    );

    final prev = _previous;
    if (prev == null) {
      _previous = target;
      return target;
    }

    final smoothing = (0.12 + (confidence * 0.42) - (motionPenalty * 0.1))
        .clamp(0.12, 0.56);
    double lerp(double a, double b) => a + ((b - a) * smoothing);
    final stabilized = GarmentDeformationSnapshot(
      deformationStrength: lerp(prev.deformationStrength, target.deformationStrength),
      secondaryMotionDamping: lerp(prev.secondaryMotionDamping, target.secondaryMotionDamping),
      torsoScaleX: lerp(prev.torsoScaleX, target.torsoScaleX),
      torsoScaleY: lerp(prev.torsoScaleY, target.torsoScaleY),
      chestInflation: lerp(prev.chestInflation, target.chestInflation),
      waistTaper: lerp(prev.waistTaper, target.waistTaper),
      hipEase: lerp(prev.hipEase, target.hipEase),
      shoulderTension: lerp(prev.shoulderTension, target.shoulderTension),
      stability: lerp(prev.stability, target.stability),
    );
    _previous = stabilized;
    return stabilized;
  }

  double _blendToOne(double value, double strength, double weight) {
    final clampedWeight = (weight * strength).clamp(0.0, 1.0);
    return (1 + ((value - 1) * clampedWeight)).clamp(0.82, 1.2);
  }

  double _tierBudget(ArDeviceTier tier) {
    switch (tier) {
      case ArDeviceTier.low:
        return 0.44;
      case ArDeviceTier.mid:
        return 0.62;
      case ArDeviceTier.flagship:
        return 0.82;
      case ArDeviceTier.premiumLidar:
        return 0.9;
    }
  }

  void reset() {
    _previous = null;
  }
}

