import '../models/ar_intelligence_models.dart';
import '../models/body_fit_intelligence_models.dart';
import '../models/mediapipe_try_on_payload.dart';

class FitConfidenceEngine {
  const FitConfidenceEngine();

  FitConfidenceResult evaluate({
    required BodyProfile bodyProfile,
    required TrackingReliabilityScore tracking,
    required MediaPipeTryOnPayload payload,
    required String selectedSize,
  }) {
    final fitPreset =
        (payload.garmentConfig['fitPreset'] ??
                payload.garmentConfig['fit'] ??
                'regular')
            .toString()
            .toLowerCase();
    final base = _baseConfidence(bodyProfile, tracking, fitPreset);
    final recommendedSize = _recommendedSize(
      selectedSize: selectedSize,
      bodyProfile: bodyProfile,
      fitPreset: fitPreset,
    );
    final label = _label(base);
    final reasons = _reasons(
      bodyProfile: bodyProfile,
      tracking: tracking,
      fitPreset: fitPreset,
      recommendedSize: recommendedSize,
    );
    final risks = _riskFlags(bodyProfile, tracking);
    return FitConfidenceResult(
      recommendedSize: recommendedSize,
      fitLabel: label,
      fitConfidence: base,
      humanConfidence: _humanConfidence(base),
      reasons: reasons,
      riskFlags: risks,
    );
  }

  double _baseConfidence(
    BodyProfile bodyProfile,
    TrackingReliabilityScore tracking,
    String fitPreset,
  ) {
    final presetWeight = switch (fitPreset) {
      'slim' => 0.93,
      'oversized' => 0.9,
      'relaxed' => 0.95,
      _ => 0.97,
    };
    return ((bodyProfile.confidence.overall * 0.56) +
            (tracking.overall * 0.44)) *
        presetWeight.clamp(0.0, 1.0);
  }

  String _recommendedSize({
    required String selectedSize,
    required BodyProfile bodyProfile,
    required String fitPreset,
  }) {
    final silhouette = bodyProfile.proportions.silhouetteIndex;
    if (fitPreset == 'slim' && silhouette >= 1.9) {
      return _sizeStep(selectedSize, -1);
    }
    if ((fitPreset == 'oversized' || fitPreset == 'relaxed') &&
        silhouette <= 1.45) {
      return _sizeStep(selectedSize, 1);
    }
    return selectedSize;
  }

  String _sizeStep(String size, int step) {
    const order = <String>['S', 'M', 'L', 'XL'];
    final i = order.indexOf(size.toUpperCase());
    if (i < 0) return size;
    final next = (i + step).clamp(0, order.length - 1);
    return order[next];
  }

  String _label(double confidence) {
    if (confidence >= 0.88) return 'Fit confidence: Strong';
    if (confidence >= 0.74) return 'Fit confidence: Balanced';
    if (confidence >= 0.58) return 'Fit confidence: Building';
    return 'Fit confidence: Limited';
  }

  String _humanConfidence(double confidence) {
    if (confidence >= 0.88) return 'High';
    if (confidence >= 0.74) return 'Medium';
    if (confidence >= 0.58) return 'Moderate';
    return 'Low';
  }

  List<FitRecommendationReason> _reasons({
    required BodyProfile bodyProfile,
    required TrackingReliabilityScore tracking,
    required String fitPreset,
    required String recommendedSize,
  }) {
    final reasons = <FitRecommendationReason>[];
    final hintText = switch (bodyProfile.fitPreferenceHint) {
      FitPreferenceType.relaxed => 'Relaxed fit is likely to feel most natural',
      FitPreferenceType.oversized =>
        'An oversized silhouette should suit your proportions',
      FitPreferenceType.slim =>
        'A slim line can work, with attention at the shoulders',
      FitPreferenceType.trueToSize =>
        'True-to-size should drape in a balanced way',
    };
    reasons.add(
      FitRecommendationReason(
        title: hintText,
        detail:
            'Silhouette ${bodyProfile.proportions.silhouetteIndex.toStringAsFixed(2)} with ${_postureLabel(bodyProfile.posture.tendency)} posture tendency.',
        confidence: bodyProfile.confidence.overall,
      ),
    );
    if (tracking.overall < 0.62) {
      reasons.add(
        FitRecommendationReason(
          title: 'Recommendation confidence is currently conservative',
          detail:
              'A steadier frame will improve shoulder and torso precision before final sizing.',
          confidence: tracking.overall,
        ),
      );
    } else {
      reasons.add(
        FitRecommendationReason(
          title: 'Body mapping is stable for fit guidance',
          detail:
              'Current tracking quality supports a confident recommendation for $fitPreset styling.',
          confidence: tracking.overall,
        ),
      );
    }
    reasons.add(
      FitRecommendationReason(
        title: 'Recommended size: $recommendedSize',
        detail:
            'Derived from body proportions, posture tendency, and garment ease behavior.',
        confidence:
            ((bodyProfile.confidence.proportionReliability * 0.6) +
                    (tracking.coverage * 0.4))
                .clamp(0.0, 1.0),
      ),
    );
    return reasons;
  }

  List<String> _riskFlags(
    BodyProfile bodyProfile,
    TrackingReliabilityScore tracking,
  ) {
    final risks = <String>[];
    if (tracking.overall < 0.55) {
      risks.add('Re-check fit once alignment lock stabilizes');
    }
    if (bodyProfile.posture.tendency == PostureTendency.forwardShoulders) {
      risks.add('Shoulder area may feel slightly narrow');
    }
    return risks;
  }

  String _postureLabel(PostureTendency tendency) {
    switch (tendency) {
      case PostureTendency.forwardShoulders:
        return 'forward-shoulder';
      case PostureTendency.slightLeanLeft:
        return 'slight left lean';
      case PostureTendency.slightLeanRight:
        return 'slight right lean';
      case PostureTendency.neutral:
        return 'neutral';
    }
  }
}
