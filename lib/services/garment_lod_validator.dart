class GarmentLodValidationResult {
  const GarmentLodValidationResult({
    required this.valid,
    required this.score,
    required this.notes,
  });

  final bool valid;
  final int score;
  final List<String> notes;
}

class GarmentLodValidator {
  const GarmentLodValidator();

  GarmentLodValidationResult validate({
    required Map<String, dynamic> garmentConfig,
    required String modelUrl,
  }) {
    final notes = <String>[];
    final lodModels = Map<String, dynamic>.from(
      garmentConfig['lodModels'] as Map? ?? const {},
    );
    if (lodModels.isEmpty) {
      notes.add('LOD models missing; provide lod0/lod1/lod2 URLs.');
    }
    final hasPrimaryModel = modelUrl.trim().isNotEmpty;
    if (!hasPrimaryModel) {
      notes.add('Primary model URL missing.');
    }
    if (hasPrimaryModel && !modelUrl.toLowerCase().startsWith('https://')) {
      notes.add('Primary model URL must be HTTPS.');
    }
    final score = (100 - (notes.length * 22)).clamp(0, 100);
    return GarmentLodValidationResult(
      valid: notes.isEmpty,
      score: score,
      notes: notes,
    );
  }
}
