import '../models/ar_intelligence_models.dart';
import 'garment_body_alignment_engine.dart';
import 'lightweight_garment_deformation_engine.dart';

class ArCompositingSnapshot {
  const ArCompositingSnapshot({
    required this.shadowOpacity,
    required this.contactShadowOpacity,
    required this.shadowSoftness,
    required this.depthSeparation,
    required this.torsoDepthLift,
    required this.chestDepthLift,
    required this.overlapBlend,
    required this.layeringConfidence,
  });

  final double shadowOpacity;
  final double contactShadowOpacity;
  final double shadowSoftness;
  final double depthSeparation;
  final double torsoDepthLift;
  final double chestDepthLift;
  final double overlapBlend;
  final double layeringConfidence;
}

class LightweightArCompositingEngine {
  ArCompositingSnapshot? _previous;

  ArCompositingSnapshot compute({
    required ArDeviceTier tier,
    required double renderQuality,
    required double thermalLoad,
    required double trackingReliability,
    required double segmentationReliability,
    required double occlusionBlend,
    required GarmentAlignmentSnapshot alignment,
    required GarmentDeformationSnapshot deformation,
  }) {
    final tierFactor = _tierFactor(tier);
    final confidence = ((trackingReliability * 0.4) +
            (segmentationReliability * 0.35) +
            (alignment.attachmentConfidence * 0.15) +
            (deformation.stability * 0.1))
        .clamp(0.0, 1.0);
    final thermalPenalty = (thermalLoad * 0.45).clamp(0.0, 0.45);
    final qualityBudget = ((tierFactor * 0.45) +
            (renderQuality.clamp(0.0, 1.0) * 0.35) +
            (confidence * 0.2) -
            thermalPenalty)
        .clamp(0.2, 1.0);

    final target = ArCompositingSnapshot(
      shadowOpacity: (0.1 + (qualityBudget * 0.22)).clamp(0.08, 0.3),
      contactShadowOpacity:
          (0.12 + (qualityBudget * 0.25) + (confidence * 0.08)).clamp(0.1, 0.36),
      shadowSoftness: (0.42 + (qualityBudget * 0.34)).clamp(0.36, 0.86),
      depthSeparation: (0.2 + (qualityBudget * 0.38)).clamp(0.18, 0.62),
      torsoDepthLift: ((alignment.torsoScale - 1.0).abs() * 0.35 +
              (deformation.torsoScaleY - 1.0).abs() * 0.5 +
              (qualityBudget * 0.08))
          .clamp(0.02, 0.2),
      chestDepthLift: ((alignment.chestScale - 1.0).abs() * 0.46 +
              (deformation.chestInflation - 1.0).abs() * 0.55 +
              (qualityBudget * 0.1))
          .clamp(0.03, 0.26),
      overlapBlend: ((occlusionBlend * 0.7) + (confidence * 0.3)).clamp(0.2, 0.96),
      layeringConfidence: confidence,
    );

    final prev = _previous;
    if (prev == null) {
      _previous = target;
      return target;
    }
    final smoothing = (0.14 + (confidence * 0.4) - (thermalLoad * 0.12))
        .clamp(0.12, 0.5);
    double lerp(double a, double b) => a + ((b - a) * smoothing);

    final stabilized = ArCompositingSnapshot(
      shadowOpacity: lerp(prev.shadowOpacity, target.shadowOpacity),
      contactShadowOpacity:
          lerp(prev.contactShadowOpacity, target.contactShadowOpacity),
      shadowSoftness: lerp(prev.shadowSoftness, target.shadowSoftness),
      depthSeparation: lerp(prev.depthSeparation, target.depthSeparation),
      torsoDepthLift: lerp(prev.torsoDepthLift, target.torsoDepthLift),
      chestDepthLift: lerp(prev.chestDepthLift, target.chestDepthLift),
      overlapBlend: lerp(prev.overlapBlend, target.overlapBlend),
      layeringConfidence: lerp(prev.layeringConfidence, target.layeringConfidence),
    );
    _previous = stabilized;
    return stabilized;
  }

  double _tierFactor(ArDeviceTier tier) {
    switch (tier) {
      case ArDeviceTier.low:
        return 0.45;
      case ArDeviceTier.mid:
        return 0.65;
      case ArDeviceTier.flagship:
        return 0.85;
      case ArDeviceTier.premiumLidar:
        return 0.95;
    }
  }

  void reset() {
    _previous = null;
  }
}

