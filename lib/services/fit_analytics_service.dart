class FitAnalyticsService {
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  int _acceptedCount = 0;
  int _interactionCount = 0;

  void recordRecommendation({
    required String recommendedSize,
    required double fitConfidence,
    required double bodyProfileConfidence,
    required double trackingReliability,
  }) {
    _events.add(<String, dynamic>{
      'type': 'recommendation',
      'recommendedSize': recommendedSize,
      'fitConfidence': fitConfidence,
      'bodyProfileConfidence': bodyProfileConfidence,
      'trackingReliability': trackingReliability,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });
    _trim();
  }

  void recordInteraction({
    required String action,
    required String selectedSize,
    required String recommendedSize,
  }) {
    _interactionCount += 1;
    if (action == 'size_selected' && selectedSize == recommendedSize) {
      _acceptedCount += 1;
    }
    _events.add(<String, dynamic>{
      'type': 'interaction',
      'action': action,
      'selectedSize': selectedSize,
      'recommendedSize': recommendedSize,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });
    _trim();
  }

  Map<String, dynamic> summarize() {
    if (_events.isEmpty) {
      return const <String, dynamic>{
        'fitRecommendationAcceptanceRate': 0.0,
        'avgFitConfidence': 0.0,
        'avgBodyProfileConfidence': 0.0,
        'recommendationInteractions': 0,
      };
    }

    double avg(String key) {
      final values = _events
          .where((event) => event[key] is num)
          .map((event) => (event[key] as num).toDouble())
          .toList();
      if (values.isEmpty) return 0.0;
      final total = values.fold<double>(0.0, (sum, value) => sum + value);
      return total / values.length;
    }

    final acceptanceRate = _interactionCount == 0
        ? 0.0
        : _acceptedCount / _interactionCount;
    return <String, dynamic>{
      'fitRecommendationAcceptanceRate': acceptanceRate,
      'avgFitConfidence': avg('fitConfidence'),
      'avgBodyProfileConfidence': avg('bodyProfileConfidence'),
      'avgTrackingReliabilityForFit': avg('trackingReliability'),
      'recommendationInteractions': _interactionCount,
    };
  }

  void _trim() {
    if (_events.length <= 400) return;
    _events.removeRange(0, _events.length - 400);
  }
}
