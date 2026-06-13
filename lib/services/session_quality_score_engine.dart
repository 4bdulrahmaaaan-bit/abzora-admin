class SessionQualityScoreEngine {
  const SessionQualityScoreEngine();
  static double _previous = 0.72;

  double score({
    required double trackingReliability,
    required double motionQuality,
    required double segmentationConfidence,
    required double fpsNormalized,
    required double thermalHeadroom,
  }) {
    final tracking = trackingReliability.clamp(0.0, 1.0);
    final motion = motionQuality.clamp(0.0, 1.0);
    final segmentation = segmentationConfidence.clamp(0.0, 1.0);
    final fps = fpsNormalized.clamp(0.0, 1.0);
    final thermal = thermalHeadroom.clamp(0.0, 1.0);
    final base =
        ((tracking * 0.32) +
                (motion * 0.18) +
                (segmentation * 0.16) +
                (fps * 0.2) +
                (thermal * 0.14))
            .clamp(0.0, 1.0);
    final instabilityPenalty = (tracking < 0.45 && motion < 0.5) ? 0.08 : 0.0;
    final thermalPenalty = thermal < 0.35 ? 0.06 : 0.0;
    final raw = (base - instabilityPenalty - thermalPenalty).clamp(0.0, 1.0);
    final smoothed = (_previous * 0.42) + (raw * 0.58);
    _previous = smoothed;
    return smoothed;
  }
}
