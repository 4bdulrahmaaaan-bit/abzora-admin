enum BodyShapeClass {
  balanced,
  athletic,
  curved,
  straight,
}

enum PostureTendency {
  neutral,
  slightLeanLeft,
  slightLeanRight,
  forwardShoulders,
}

enum FitPreferenceType {
  trueToSize,
  relaxed,
  oversized,
  slim,
}

class BodyConfidence {
  const BodyConfidence({
    required this.overall,
    required this.poseReliability,
    required this.proportionReliability,
    required this.postureReliability,
  });

  final double overall;
  final double poseReliability;
  final double proportionReliability;
  final double postureReliability;
}

class ProportionAnalysis {
  const ProportionAnalysis({
    required this.shoulderProportion,
    required this.torsoProportion,
    required this.silhouetteIndex,
  });

  final double shoulderProportion;
  final double torsoProportion;
  final double silhouetteIndex;
}

class PostureAnalysis {
  const PostureAnalysis({
    required this.tendency,
    required this.tiltRadians,
  });

  final PostureTendency tendency;
  final double tiltRadians;
}

class BodyProfile {
  const BodyProfile({
    required this.shapeClass,
    required this.proportions,
    required this.posture,
    required this.fitPreferenceHint,
    required this.confidence,
  });

  final BodyShapeClass shapeClass;
  final ProportionAnalysis proportions;
  final PostureAnalysis posture;
  final FitPreferenceType fitPreferenceHint;
  final BodyConfidence confidence;
}

class FitRecommendationReason {
  const FitRecommendationReason({
    required this.title,
    required this.detail,
    required this.confidence,
  });

  final String title;
  final String detail;
  final double confidence;
}

class FitConfidenceResult {
  const FitConfidenceResult({
    required this.recommendedSize,
    required this.fitLabel,
    required this.fitConfidence,
    required this.humanConfidence,
    required this.reasons,
    required this.riskFlags,
  });

  final String recommendedSize;
  final String fitLabel;
  final double fitConfidence;
  final String humanConfidence;
  final List<FitRecommendationReason> reasons;
  final List<String> riskFlags;
}
