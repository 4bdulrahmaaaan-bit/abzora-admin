import '../models/mediapipe_try_on_payload.dart';

class GarmentCertificationResult {
  const GarmentCertificationResult({
    required this.approved,
    required this.qualityScore,
    required this.issues,
  });

  final bool approved;
  final int qualityScore;
  final List<String> issues;
}

class GarmentCertificationService {
  const GarmentCertificationService();

  GarmentCertificationResult certify(MediaPipeTryOnPayload payload) {
    final issues = <String>[];
    final model = payload.model3dUrl.trim();
    if (model.isEmpty) {
      issues.add('Missing model URL');
    } else if (!_isSecureModel(model)) {
      issues.add('Model URL must be HTTPS GLB/GLTF');
    }
    if (payload.rigProfile.trim().isEmpty) {
      issues.add('Missing rig profile');
    }
    if (payload.materialProfile.trim().isEmpty) {
      issues.add('Missing material profile');
    }
    final score = (100 - (issues.length * 18)).clamp(0, 100);
    return GarmentCertificationResult(
      approved: issues.isEmpty,
      qualityScore: score,
      issues: issues,
    );
  }

  bool _isSecureModel(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('https://') &&
        (lower.endsWith('.glb') || lower.endsWith('.gltf'));
  }
}
