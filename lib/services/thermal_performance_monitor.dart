import 'dart:async';

class ThermalPerformanceSnapshot {
  const ThermalPerformanceSnapshot({
    required this.thermalLoad,
    required this.fpsEstimate,
    required this.gpuPressure,
  });

  final double thermalLoad;
  final double fpsEstimate;
  final double gpuPressure;
}

class ThermalPerformanceMonitor {
  Timer? _timer;
  double _thermalLoad = 0.12;
  double _fpsEstimate = 30;
  double _gpuPressure = 0.2;

  void start({
    required void Function(ThermalPerformanceSnapshot snapshot) onTick,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final snapshot = ThermalPerformanceSnapshot(
        thermalLoad: _thermalLoad.clamp(0.0, 1.0),
        fpsEstimate: _fpsEstimate.clamp(8.0, 60.0),
        gpuPressure: _gpuPressure.clamp(0.0, 1.0),
      );
      onTick(snapshot);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void updateEstimate({
    required double sessionQuality,
    required double trackingReliability,
  }) {
    final targetThermal = (1 - sessionQuality).clamp(0.0, 1.0);
    _thermalLoad = ((_thermalLoad * 0.5) + (targetThermal * 0.5)).clamp(
      0.0,
      1.0,
    );
    _fpsEstimate =
        ((_fpsEstimate * 0.35) + ((14 + (trackingReliability * 20)) * 0.65))
            .clamp(8.0, 60.0);
    _gpuPressure = ((_thermalLoad * 0.72) + ((1 - trackingReliability) * 0.28))
        .clamp(0.0, 1.0);
  }
}
