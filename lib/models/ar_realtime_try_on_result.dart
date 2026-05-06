class ArRealtimeTryOnResult {
  const ArRealtimeTryOnResult({
    required this.fitScore,
    required this.recommendedSize,
    required this.trackingConfidence,
    required this.fps,
    required this.bodyDetected,
    required this.timestampMs,
    this.styleHint,
  });

  final double fitScore;
  final String recommendedSize;
  final double trackingConfidence;
  final double fps;
  final bool bodyDetected;
  final int timestampMs;
  final String? styleHint;

  factory ArRealtimeTryOnResult.fromUnityEvent(Map<String, dynamic> map) {
    final payload = map['payload'] is Map
        ? Map<String, dynamic>.from(map['payload'] as Map)
        : map;
    return ArRealtimeTryOnResult(
      fitScore: ((payload['fitScore'] ?? payload['fit_score'] ?? 0) as num)
          .toDouble()
          .clamp(0, 100),
      recommendedSize:
          (payload['recommendedSize'] ?? payload['recommended_size'] ?? 'M')
              .toString()
              .toUpperCase(),
      trackingConfidence:
          ((payload['trackingConfidence'] ?? payload['poseConfidence'] ?? 0)
                  as num)
              .toDouble()
              .clamp(0, 1),
      fps: ((payload['fps'] ?? 0) as num).toDouble().clamp(0, 240),
      bodyDetected: payload['bodyDetected'] == true,
      timestampMs:
          ((payload['timestampMs'] ?? DateTime.now().millisecondsSinceEpoch)
                  as num)
              .toInt(),
      styleHint: payload['styleHint']?.toString(),
    );
  }
}
