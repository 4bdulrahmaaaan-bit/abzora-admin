class JointKalmanFilter2D {
  JointKalmanFilter2D({
    this.processNoise = 0.008,
    this.measurementNoise = 0.06,
  });

  final double processNoise;
  final double measurementNoise;

  bool _initialized = false;
  double _x = 0;
  double _y = 0;
  double _vx = 0;
  double _vy = 0;
  double _px = 1;
  double _py = 1;

  ({double x, double y}) update({
    required double mx,
    required double my,
    required double dt,
    required double confidence,
  }) {
    final safeDt = dt <= 0 ? 0.016 : dt.clamp(0.008, 0.1);
    final conf = confidence.clamp(0.08, 1.0);
    final adaptiveMeasurementNoise = measurementNoise / conf;

    if (!_initialized) {
      _initialized = true;
      _x = mx;
      _y = my;
      _vx = 0;
      _vy = 0;
      return (x: _x, y: _y);
    }

    _x += _vx * safeDt;
    _y += _vy * safeDt;
    _px += processNoise;
    _py += processNoise;

    final kx = _px / (_px + adaptiveMeasurementNoise);
    final ky = _py / (_py + adaptiveMeasurementNoise);

    final residualX = mx - _x;
    final residualY = my - _y;
    _x += kx * residualX;
    _y += ky * residualY;

    _vx = ((_vx * 0.72) + ((residualX / safeDt) * 0.28)).clamp(-6.0, 6.0);
    _vy = ((_vy * 0.72) + ((residualY / safeDt) * 0.28)).clamp(-6.0, 6.0);

    _px *= (1 - kx);
    _py *= (1 - ky);
    return (x: _x, y: _y);
  }

  void reset() {
    _initialized = false;
    _x = 0;
    _y = 0;
    _vx = 0;
    _vy = 0;
    _px = 1;
    _py = 1;
  }
}
