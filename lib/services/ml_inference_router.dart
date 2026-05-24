enum MlInferenceTarget { local, cloud, hybrid }

class MlInferenceRequest {
  const MlInferenceRequest({
    required this.modelKey,
    required this.features,
    required this.target,
  });

  final String modelKey;
  final Map<String, dynamic> features;
  final MlInferenceTarget target;
}

class MlInferenceResult {
  const MlInferenceResult({
    required this.values,
    required this.confidence,
    required this.source,
  });

  final Map<String, dynamic> values;
  final double confidence;
  final MlInferenceTarget source;
}

class MlInferenceRouter {
  const MlInferenceRouter();

  Future<MlInferenceResult> infer(MlInferenceRequest request) async {
    final normalizedTarget = _resolveTarget(request);
    final confidence = _estimateConfidence(request, normalizedTarget);
    final fitDelta = _safeDouble(request.features['fitDeltaHint']);
    final bodyScale = _safeDouble(request.features['bodyScale']);
    final thermalHeadroom = _safeDouble(request.features['thermalHeadroom']);
    final bias = ((bodyScale - 1.0) * 0.08) + ((thermalHeadroom - 0.5) * 0.04);
    return MlInferenceResult(
      values: <String, dynamic>{
        'fitDelta': (fitDelta + bias).clamp(-0.25, 0.25),
        'sizeBias': bias.clamp(-0.2, 0.2),
        'modelKey': request.modelKey,
        'resolvedTarget': normalizedTarget.name,
      },
      confidence: confidence,
      source: normalizedTarget,
    );
  }

  MlInferenceTarget _resolveTarget(MlInferenceRequest request) {
    if (request.target == MlInferenceTarget.hybrid) {
      final thermalHeadroom = _safeDouble(request.features['thermalHeadroom']);
      final connectivity = _safeDouble(request.features['connectivityScore']);
      if (thermalHeadroom < 0.35 && connectivity > 0.65) {
        return MlInferenceTarget.cloud;
      }
      return MlInferenceTarget.local;
    }
    return request.target;
  }

  double _estimateConfidence(
    MlInferenceRequest request,
    MlInferenceTarget target,
  ) {
    final signal = _safeDouble(request.features['signalQuality']);
    final base = target == MlInferenceTarget.local ? 0.72 : 0.8;
    return (base + ((signal - 0.5) * 0.22)).clamp(0.45, 0.95);
  }

  double _safeDouble(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    return 0.0;
  }
}
