import '../models/ar_intelligence_models.dart';
import 'pose_measurement_service.dart';

class RuntimeTelemetryEngine {
  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  int _fpsDropEvents = 0;
  int _trackingDropEvents = 0;

  void trackFrame({
    required int timestampMs,
    required TryOnPoseFrame frame,
    required TrackingReliabilityScore reliability,
    required BodyMetricsSnapshot body,
    required double fps,
    required double thermalLoad,
  }) {
    if (fps < 24) {
      _fpsDropEvents += 1;
    }
    if (reliability.overall < 0.45) {
      _trackingDropEvents += 1;
    }
    _buffer.add(<String, dynamic>{
      't': timestampMs,
      'poseProgress': frame.feedback.progress,
      'reliability': reliability.overall,
      'motionQuality': reliability.motionQuality,
      'bodyConfidence': body.confidenceProfile.overall,
      'fps': fps,
      'thermalLoad': thermalLoad,
    });
    if (_buffer.length > 240) {
      _buffer.removeAt(0);
    }
  }

  Map<String, dynamic> summarize() {
    if (_buffer.isEmpty) {
      return const <String, dynamic>{'sessionQuality': 0.0};
    }
    double avg(String key) {
      final total = _buffer.fold<double>(
        0,
        (sum, item) => sum + ((item[key] as num?)?.toDouble() ?? 0.0),
      );
      return total / _buffer.length;
    }

    final reliabilityTrend = _windowTrend('reliability', window: 24);
    final fpsTrend = _windowTrend('fps', window: 24);
    final sessionQuality =
        (avg('reliability') * 0.45) +
        (avg('fps') / 30.0).clamp(0.0, 1.0) * 0.35 +
        ((1 - avg('thermalLoad')).clamp(0.0, 1.0) * 0.2);
    return <String, dynamic>{
      'samples': _buffer.length,
      'avgReliability': avg('reliability'),
      'avgFps': avg('fps'),
      'avgThermalLoad': avg('thermalLoad'),
      'fpsDropEvents': _fpsDropEvents,
      'trackingDropEvents': _trackingDropEvents,
      'reliabilityTrend': reliabilityTrend,
      'fpsTrend': fpsTrend,
      'sessionQuality': sessionQuality.clamp(0.0, 1.0),
    };
  }

  double _windowTrend(String key, {required int window}) {
    if (_buffer.length < 4) {
      return 0;
    }
    final startIndex = (_buffer.length - window).clamp(0, _buffer.length - 1);
    final samples = _buffer.sublist(startIndex);
    final first = (samples.first[key] as num?)?.toDouble() ?? 0;
    final last = (samples.last[key] as num?)?.toDouble() ?? 0;
    return (last - first).clamp(-1.0, 1.0);
  }
}
