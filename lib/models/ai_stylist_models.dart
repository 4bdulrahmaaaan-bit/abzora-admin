class StyleProfile {
  const StyleProfile({
    required this.primaryStyle,
    required this.occasion,
    required this.confidence,
    required this.fitPreference,
  });

  final String primaryStyle;
  final String occasion;
  final double confidence;
  final String fitPreference;
}

class StylistSuggestion {
  const StylistSuggestion({
    required this.title,
    required this.subtitle,
    required this.confidence,
    required this.reasoning,
  });

  final String title;
  final String subtitle;
  final double confidence;
  final String reasoning;
}
