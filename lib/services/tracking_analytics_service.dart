class TrackingAnalyticsService {
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  int _dropStreak = 0;
  int _maxDropStreak = 0;

  void track(Map<String, dynamic> event) {
    final reliability =
        (event['trackingReliability'] as num?)?.toDouble() ?? 0.0;
    if (reliability < 0.35) {
      _dropStreak += 1;
      if (_dropStreak > _maxDropStreak) {
        _maxDropStreak = _dropStreak;
      }
    } else {
      _dropStreak = 0;
    }
    _events.add(event);
    if (_events.length > 500) {
      _events.removeRange(0, _events.length - 500);
    }
  }

  Map<String, dynamic> summarize() {
    if (_events.isEmpty) {
      return const <String, dynamic>{'count': 0};
    }
    double avg(String key) {
      final total = _events.fold<double>(
        0,
        (sum, e) => sum + ((e[key] as num?)?.toDouble() ?? 0.0),
      );
      return total / _events.length;
    }

    final trackingLossRate =
        _events
            .where(
              (e) =>
                  ((e['trackingReliability'] as num?)?.toDouble() ?? 0.0) <
                  0.35,
            )
            .length /
        _events.length;
    final weakSegmentationRate =
        _events
            .where(
              (e) =>
                  ((e['segmentationConfidence'] as num?)?.toDouble() ?? 0.0) <
                  0.42,
            )
            .length /
        _events.length;
    final thermalSpikeRate =
        _events
            .where(
              (e) => ((e['thermalLoad'] as num?)?.toDouble() ?? 0.0) > 0.72,
            )
            .length /
        _events.length;
    return <String, dynamic>{
      'count': _events.length,
      'trackingLossRate': trackingLossRate,
      'weakSegmentationRate': weakSegmentationRate,
      'thermalSpikeRate': thermalSpikeRate,
      'maxDropStreak': _maxDropStreak,
      'avgReliability': avg('trackingReliability'),
      'avgSegmentationConfidence': avg('segmentationConfidence'),
      'avgSessionQuality': avg('sessionQuality'),
      'avgThermalLoad': avg('thermalLoad'),
      'avgFps': avg('fps'),
      'avgBodyProfileConfidence': avg('bodyProfileConfidence'),
      'avgFitConfidence': avg('fitConfidence'),
    };
  }
}
