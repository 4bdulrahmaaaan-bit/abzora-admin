import '../models/ai_stylist_models.dart';
import '../models/body_fit_intelligence_models.dart';
import '../models/outfit_recommendation_model.dart';

class FashionPreferenceEngine {
  const FashionPreferenceEngine();

  StyleProfile inferProfile({
    required BodyProfile? bodyProfile,
    required List<OutfitRecommendation> outfits,
    required double trackingReliability,
  }) {
    final primaryStyle = outfits.isNotEmpty
        ? (outfits.first.style.isEmpty ? 'Modern Minimal' : outfits.first.style)
        : 'Modern Minimal';
    final occasion = _occasionFromOutfits(outfits);
    final fitPreference = bodyProfile?.fitPreferenceHint.name ?? 'trueToSize';
    final confidence = (((bodyProfile?.confidence.overall ?? 0.65) * 0.6) +
            (trackingReliability * 0.4))
        .clamp(0.0, 1.0);
    return StyleProfile(
      primaryStyle: primaryStyle,
      occasion: occasion,
      confidence: confidence,
      fitPreference: fitPreference,
    );
  }

  String _occasionFromOutfits(List<OutfitRecommendation> outfits) {
    for (final outfit in outfits) {
      final occasion = outfit.occasion.trim();
      if (occasion.isNotEmpty) return occasion;
    }
    return 'Everyday Luxury';
  }
}

class OutfitRecommendationEngine {
  const OutfitRecommendationEngine();

  List<StylistSuggestion> buildSuggestions({
    required StyleProfile profile,
    required String fitLabel,
    required String selectedSize,
    required String recommendedSize,
    required List<OutfitRecommendation> outfits,
  }) {
    final suggestions = <StylistSuggestion>[
      StylistSuggestion(
        title: '$fitLabel · Size $recommendedSize',
        subtitle: 'Selected $selectedSize · refined recommendation',
        confidence: profile.confidence,
        reasoning:
            'Calibrated to your ${_preferenceLabel(profile.fitPreference)} preference and current body-mapping confidence.',
      ),
      StylistSuggestion(
        title: '${profile.primaryStyle} styling direction',
        subtitle: profile.occasion,
        confidence: (profile.confidence * 0.94).clamp(0.0, 1.0),
        reasoning:
            'Your proportions support a composed silhouette with clean drape in this direction.',
      ),
    ];

    if (outfits.isNotEmpty) {
      final outfit = outfits.first;
      suggestions.add(
        StylistSuggestion(
          title: outfit.title.isEmpty ? 'Editorial Look' : outfit.title,
          subtitle: outfit.bodyTypeLabel.isEmpty
              ? 'Curated for your profile'
              : outfit.bodyTypeLabel,
          confidence: (outfit.matchScore / 100).clamp(0.0, 1.0),
          reasoning: outfit.reasoning.isEmpty
              ? 'Selected for proportion harmony and occasion alignment.'
              : outfit.reasoning,
        ),
      );
    }
    return suggestions;
  }

  String _preferenceLabel(String value) {
    switch (value) {
      case 'trueToSize':
        return 'true-to-size';
      case 'oversized':
        return 'oversized';
      case 'relaxed':
        return 'relaxed';
      case 'slim':
        return 'slim';
      default:
        return 'balanced';
    }
  }
}

class AIStylistLayer {
  const AIStylistLayer();

  static const FashionPreferenceEngine _preferenceEngine =
      FashionPreferenceEngine();
  static const OutfitRecommendationEngine _recommendationEngine =
      OutfitRecommendationEngine();

  (StyleProfile, List<StylistSuggestion>) compose({
    required BodyProfile? bodyProfile,
    required List<OutfitRecommendation> outfits,
    required double trackingReliability,
    required String fitLabel,
    required String selectedSize,
    required String recommendedSize,
  }) {
    final profile = _preferenceEngine.inferProfile(
      bodyProfile: bodyProfile,
      outfits: outfits,
      trackingReliability: trackingReliability,
    );
    final suggestions = _recommendationEngine.buildSuggestions(
      profile: profile,
      fitLabel: fitLabel,
      selectedSize: selectedSize,
      recommendedSize: recommendedSize,
      outfits: outfits,
    );
    return (profile, suggestions);
  }
}
