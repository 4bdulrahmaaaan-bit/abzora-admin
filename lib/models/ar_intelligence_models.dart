enum ArDeviceTier { low, mid, flagship, premiumLidar }

enum TrackingConfidenceState { locked, stable, recovering, weak }

class TrackingReliabilityScore {
  const TrackingReliabilityScore({
    required this.overall,
    required this.stability,
    required this.coverage,
    required this.motionQuality,
    required this.confidenceState,
    required this.lowLightRisk,
    required this.fastMotionRisk,
    required this.partialBodyRisk,
  });

  final double overall;
  final double stability;
  final double coverage;
  final double motionQuality;
  final TrackingConfidenceState confidenceState;
  final double lowLightRisk;
  final double fastMotionRisk;
  final double partialBodyRisk;
}

class BodyConfidenceProfile {
  const BodyConfidenceProfile({
    required this.overall,
    required this.shoulderConfidence,
    required this.torsoConfidence,
    required this.hipConfidence,
  });

  final double overall;
  final double shoulderConfidence;
  final double torsoConfidence;
  final double hipConfidence;
}

class BodyMetricsSnapshot {
  const BodyMetricsSnapshot({
    required this.shoulderWidthNorm,
    required this.torsoRatio,
    required this.waistHipRatio,
    required this.postureTilt,
    required this.confidenceProfile,
  });

  final double shoulderWidthNorm;
  final double torsoRatio;
  final double waistHipRatio;
  final double postureTilt;
  final BodyConfidenceProfile confidenceProfile;
}

class FitConfidenceSnapshot {
  const FitConfidenceSnapshot({
    required this.recommendedSize,
    required this.fitScore,
    required this.confidence,
    required this.label,
    required this.explanation,
  });

  final String recommendedSize;
  final int fitScore;
  final double confidence;
  final String label;
  final String explanation;
}
