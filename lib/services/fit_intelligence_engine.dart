import '../models/ar_intelligence_models.dart';
import '../models/mediapipe_try_on_payload.dart';

class FitIntelligenceEngine {
  FitConfidenceSnapshot infer({
    required MediaPipeTryOnPayload payload,
    required BodyMetricsSnapshot body,
    required TrackingReliabilityScore tracking,
    required String selectedSize,
  }) {
    final garmentMeta = payload.garmentConfig;
    final garmentEase = _garmentEaseScore(garmentMeta);
    final posturePenalty = (body.postureTilt.abs() * 0.55).clamp(0.0, 0.22);
    final proportionScore = _proportionScore(body);
    final fitBase =
        ((tracking.overall * 100) * 0.5) +
        (body.confidenceProfile.overall * 28) +
        (proportionScore * 14) +
        (garmentEase * 8) -
        (posturePenalty * 100);
    final fitScore = fitBase.round().clamp(55, 96);
    final confidence = (fitScore / 100).clamp(0.0, 1.0);
    final label = fitScore >= 88
        ? 'Precision Drape'
        : fitScore >= 78
        ? 'Balanced Fit'
        : 'Estimated Fit';
    final explanation =
        'Body coherence is ${_band(proportionScore)} and tracking is ${_band(tracking.overall)} with ${_band(garmentEase)} ease behavior.';
    return FitConfidenceSnapshot(
      recommendedSize: selectedSize,
      fitScore: fitScore,
      confidence: confidence,
      label: label,
      explanation: explanation,
    );
  }

  double _proportionScore(BodyMetricsSnapshot body) {
    final shoulderBand = (1.0 - (body.shoulderWidthNorm - 0.21).abs() * 2.6).clamp(0.0, 1.0);
    final torsoBand = (1.0 - (body.torsoRatio - 0.62).abs() * 1.9).clamp(0.0, 1.0);
    final waistHipBand = (1.0 - (body.waistHipRatio - 0.85).abs() * 1.8).clamp(0.0, 1.0);
    return (shoulderBand * 0.34) + (torsoBand * 0.36) + (waistHipBand * 0.3);
  }

  double _garmentEaseScore(Map<String, dynamic> garmentMeta) {
    final fitPreset = garmentMeta['fit']?.toString().toLowerCase() ?? 'regular';
    switch (fitPreset) {
      case 'slim':
        return 0.62;
      case 'relaxed':
        return 0.84;
      case 'oversized':
        return 0.78;
      case 'athletic':
        return 0.74;
      default:
        return 0.8;
    }
  }

  String _band(double value) {
    if (value >= 0.82) {
      return 'high';
    }
    if (value >= 0.62) {
      return 'moderate';
    }
    return 'limited';
  }
}
