import '../models/ar_intelligence_models.dart';

class ArQualityProfile {
  const ArQualityProfile({
    required this.deviceTier,
    required this.inferenceFps,
    required this.segmentationQuality,
    required this.renderQuality,
    required this.occlusionEnabled,
    required this.segmentationInferenceStride,
    required this.segmentationEdgeSmoothing,
    required this.occlusionDetail,
  });

  final ArDeviceTier deviceTier;
  final int inferenceFps;
  final double segmentationQuality;
  final double renderQuality;
  final bool occlusionEnabled;
  final int segmentationInferenceStride;
  final double segmentationEdgeSmoothing;
  final double occlusionDetail;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'deviceTier': deviceTier.name,
    'inferenceFps': inferenceFps,
    'segmentationQuality': segmentationQuality,
    'renderQuality': renderQuality,
    'occlusionEnabled': occlusionEnabled,
    'segmentationInferenceStride': segmentationInferenceStride,
    'segmentationEdgeSmoothing': segmentationEdgeSmoothing,
    'occlusionDetail': occlusionDetail,
  };
}

class ArQualityScaler {
  const ArQualityScaler();

  static const double _degradeLatch = 0.64;
  static const double _recoverLatch = 0.42;

  static bool _isDegraded = false;

  ArQualityProfile profileFor({
    required ArDeviceTier tier,
    required double thermalLoad,
    required double trackingReliability,
  }) {
    final clampedThermal = thermalLoad.clamp(0.0, 1.0);
    final clampedTracking = trackingReliability.clamp(0.0, 1.0);

    final base = _baseProfile(tier);
    final thermalPenalty = clampedThermal * 0.35;
    final trackingPenalty = (1 - clampedTracking) * 0.25;
    final totalPenalty = (thermalPenalty + trackingPenalty).clamp(0.0, 0.55);

    if (totalPenalty >= _degradeLatch) {
      _isDegraded = true;
    } else if (totalPenalty <= _recoverLatch) {
      _isDegraded = false;
    }

    final degradeBoost = _isDegraded ? 0.08 : 0.0;
    final effectivePenalty = (totalPenalty + degradeBoost).clamp(0.0, 0.62);
    final confidenceScale = (0.62 + (clampedTracking * 0.38)).clamp(0.52, 1.0);
    final segQuality = ((base.segmentationQuality - effectivePenalty) * confidenceScale)
        .clamp(0.24, 1.0);
    final renderQuality =
        (base.renderQuality - (effectivePenalty * 0.9)).clamp(0.36, 1.0);
    final fpsDrop = (effectivePenalty * 12).round();
    final fps = (base.inferenceFps - fpsDrop).clamp(12, base.inferenceFps);
    final occlusionEnabled = tier != ArDeviceTier.low &&
        !_isDegraded &&
        segQuality >= 0.45 &&
        base.occlusionEnabled;
    final stride = _isDegraded
        ? (base.segmentationInferenceStride + 1).clamp(1, 4)
        : base.segmentationInferenceStride;
    final edgeSmoothing = (base.segmentationEdgeSmoothing -
            (effectivePenalty * 0.28))
        .clamp(0.24, 0.84);
    final occlusionDetail = (base.occlusionDetail - (effectivePenalty * 0.35))
        .clamp(0.26, 0.92);

    return ArQualityProfile(
      deviceTier: base.deviceTier,
      inferenceFps: fps,
      segmentationQuality: segQuality,
      renderQuality: renderQuality,
      occlusionEnabled: occlusionEnabled,
      segmentationInferenceStride: stride,
      segmentationEdgeSmoothing: edgeSmoothing,
      occlusionDetail: occlusionDetail,
    );
  }

  ArQualityProfile _baseProfile(ArDeviceTier tier) {
    switch (tier) {
      case ArDeviceTier.low:
        return const ArQualityProfile(
          deviceTier: ArDeviceTier.low,
          inferenceFps: 18,
          segmentationQuality: 0.52,
          renderQuality: 0.55,
          occlusionEnabled: false,
          segmentationInferenceStride: 3,
          segmentationEdgeSmoothing: 0.34,
          occlusionDetail: 0.32,
        );
      case ArDeviceTier.mid:
        return const ArQualityProfile(
          deviceTier: ArDeviceTier.mid,
          inferenceFps: 22,
          segmentationQuality: 0.68,
          renderQuality: 0.7,
          occlusionEnabled: true,
          segmentationInferenceStride: 2,
          segmentationEdgeSmoothing: 0.52,
          occlusionDetail: 0.58,
        );
      case ArDeviceTier.flagship:
        return const ArQualityProfile(
          deviceTier: ArDeviceTier.flagship,
          inferenceFps: 28,
          segmentationQuality: 0.84,
          renderQuality: 0.84,
          occlusionEnabled: true,
          segmentationInferenceStride: 1,
          segmentationEdgeSmoothing: 0.68,
          occlusionDetail: 0.8,
        );
      case ArDeviceTier.premiumLidar:
        return const ArQualityProfile(
          deviceTier: ArDeviceTier.premiumLidar,
          inferenceFps: 30,
          segmentationQuality: 0.95,
          renderQuality: 0.94,
          occlusionEnabled: true,
          segmentationInferenceStride: 1,
          segmentationEdgeSmoothing: 0.76,
          occlusionDetail: 0.9,
        );
    }
  }
}
