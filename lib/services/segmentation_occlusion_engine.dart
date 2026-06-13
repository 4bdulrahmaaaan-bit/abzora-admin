class SegmentationSnapshot {
  const SegmentationSnapshot({
    required this.confidence,
    required this.occlusionEnabled,
    required this.maskQuality,
    required this.foregroundCoverage,
    required this.edgeSmoothing,
    required this.armOverlapConfidence,
    required this.torsoMaskConfidence,
    required this.reliability,
    required this.fallbackRecommended,
    required this.edgeStability,
    required this.maskAlpha,
    required this.occlusionBlend,
  });

  final double confidence;
  final bool occlusionEnabled;
  final double maskQuality;
  final double foregroundCoverage;
  final double edgeSmoothing;
  final double armOverlapConfidence;
  final double torsoMaskConfidence;
  final double reliability;
  final bool fallbackRecommended;
  final double edgeStability;
  final double maskAlpha;
  final double occlusionBlend;
}

class AdaptiveSegmentationProfile {
  const AdaptiveSegmentationProfile({
    required this.inferenceStride,
    required this.edgeSmoothing,
    required this.occlusionDetail,
    required this.maskFeather,
  });

  final int inferenceStride;
  final double edgeSmoothing;
  final double occlusionDetail;
  final double maskFeather;
}

class SegmentationQualityManager {
  const SegmentationQualityManager();

  AdaptiveSegmentationProfile profile({
    required String tierName,
    required double quality,
    required double thermalLoad,
  }) {
    final q = quality.clamp(0.0, 1.0);
    final t = thermalLoad.clamp(0.0, 1.0);
    final degraded = t > 0.7 || q < 0.45;
    switch (tierName.toLowerCase()) {
      case 'low':
        return AdaptiveSegmentationProfile(
          inferenceStride: degraded ? 4 : 3,
          edgeSmoothing: degraded ? 0.28 : 0.36,
          occlusionDetail: degraded ? 0.32 : 0.4,
          maskFeather: degraded ? 0.18 : 0.22,
        );
      case 'mid':
        return AdaptiveSegmentationProfile(
          inferenceStride: degraded ? 3 : 2,
          edgeSmoothing: degraded ? 0.36 : 0.5,
          occlusionDetail: degraded ? 0.44 : 0.62,
          maskFeather: degraded ? 0.2 : 0.26,
        );
      case 'premiumlidar':
      case 'premium_lidar':
      case 'premium':
        return AdaptiveSegmentationProfile(
          inferenceStride: degraded ? 2 : 1,
          edgeSmoothing: degraded ? 0.52 : 0.72,
          occlusionDetail: degraded ? 0.66 : 0.9,
          maskFeather: degraded ? 0.24 : 0.3,
        );
      default:
        return AdaptiveSegmentationProfile(
          inferenceStride: degraded ? 2 : 1,
          edgeSmoothing: degraded ? 0.46 : 0.64,
          occlusionDetail: degraded ? 0.58 : 0.82,
          maskFeather: degraded ? 0.22 : 0.28,
        );
    }
  }
}

class OcclusionConfidenceSystem {
  const OcclusionConfidenceSystem();

  double score({
    required double trackingReliability,
    required double motionQuality,
    required double segmentationQuality,
    required double armOverlapConfidence,
  }) {
    return ((trackingReliability * 0.35) +
            (motionQuality * 0.2) +
            (segmentationQuality * 0.3) +
            (armOverlapConfidence * 0.15))
        .clamp(0.0, 1.0);
  }
}

class SegmentationOcclusionEngine {
  bool _occlusionLatched = false;
  double _lastConfidence = 0;
  double _lastMaskQuality = 0.6;
  double _lastEdgeStability = 0.6;
  final SegmentationQualityManager _qualityManager =
      const SegmentationQualityManager();
  final OcclusionConfidenceSystem _occlusionConfidenceSystem =
      const OcclusionConfidenceSystem();

  SegmentationSnapshot evaluate({
    required double trackingReliability,
    required double motionQuality,
    required double segmentationBudget,
    required bool allowOcclusion,
    required String tierName,
    required double thermalLoad,
  }) {
    final confRaw = ((trackingReliability * 0.74) + (motionQuality * 0.26))
        .clamp(0.0, 1.0);
    final conf = (_lastConfidence * 0.56) + (confRaw * 0.44);
    _lastConfidence = conf;
    final profile = _qualityManager.profile(
      tierName: tierName,
      quality: segmentationBudget,
      thermalLoad: thermalLoad,
    );
    final qualityInstant = (conf * segmentationBudget).clamp(0.0, 1.0);
    final quality = ((_lastMaskQuality * 0.66) + (qualityInstant * 0.34)).clamp(
      0.0,
      1.0,
    );
    _lastMaskQuality = quality;
    final coverage = (0.36 + (quality * 0.54)).clamp(0.0, 1.0);
    final torsoMaskConfidence = ((coverage * 0.6) + (trackingReliability * 0.4))
        .clamp(0.0, 1.0);
    final armOverlapConfidence = ((motionQuality * 0.45) + (quality * 0.55))
        .clamp(0.0, 1.0);
    final reliability =
        ((torsoMaskConfidence * 0.55) + (armOverlapConfidence * 0.45)).clamp(
          0.0,
          1.0,
        );
    final occConfidence = _occlusionConfidenceSystem.score(
      trackingReliability: trackingReliability,
      motionQuality: motionQuality,
      segmentationQuality: quality,
      armOverlapConfidence: armOverlapConfidence,
    );

    final engage = allowOcclusion && occConfidence >= 0.52 && quality >= 0.46;
    final release = !allowOcclusion || occConfidence < 0.38 || quality < 0.3;
    if (engage) {
      _occlusionLatched = true;
    } else if (release) {
      _occlusionLatched = false;
    }
    final edgeStabilityInstant =
        ((quality * 0.62) +
                (torsoMaskConfidence * 0.18) +
                (armOverlapConfidence * 0.2))
            .clamp(0.0, 1.0);
    final edgeStability =
        ((_lastEdgeStability * 0.74) + (edgeStabilityInstant * 0.26)).clamp(
          0.0,
          1.0,
        );
    _lastEdgeStability = edgeStability;
    final maskAlpha =
        ((quality * 0.48) +
                (profile.maskFeather * 0.30) +
                (edgeStability * 0.22))
            .clamp(0.34, 0.88);
    final occlusionBlend =
        ((occConfidence * 0.48) +
                (profile.occlusionDetail * 0.28) +
                (edgeStability * 0.24))
            .clamp(0.28, 0.9);
    final fallbackRecommended = reliability < 0.42 || quality < 0.35;

    return SegmentationSnapshot(
      confidence: conf,
      occlusionEnabled: _occlusionLatched,
      maskQuality: quality,
      foregroundCoverage: coverage,
      edgeSmoothing: profile.edgeSmoothing,
      armOverlapConfidence: armOverlapConfidence,
      torsoMaskConfidence: torsoMaskConfidence,
      reliability: reliability,
      fallbackRecommended: fallbackRecommended,
      edgeStability: edgeStability,
      maskAlpha: maskAlpha,
      occlusionBlend: occlusionBlend,
    );
  }

  void reset() {
    _occlusionLatched = false;
    _lastConfidence = 0;
    _lastMaskQuality = 0.6;
    _lastEdgeStability = 0.6;
  }
}
