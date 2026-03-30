import 'dart:math' as math;

import '../models/models.dart';
import 'pose_measurement_service.dart';

class BodyScanInput {
  const BodyScanInput({
    required this.heightCm,
    required this.weightKg,
    required this.bodyFrame,
    this.frontImagePath,
    this.sideImagePath,
  });

  final double heightCm;
  final double weightKg;
  final String bodyFrame;
  final String? frontImagePath;
  final String? sideImagePath;
}

class SizePredictionResult {
  const SizePredictionResult({
    required this.shirtSize,
    required this.pantSize,
    required this.chestCm,
    required this.waistCm,
    required this.hipCm,
    required this.shoulderCm,
    required this.sleeveCm,
    required this.lengthCm,
    required this.fit,
    required this.confidence,
    required this.bodyOutlineHighlights,
  });

  final String shirtSize;
  final String pantSize;
  final double chestCm;
  final double waistCm;
  final double hipCm;
  final double shoulderCm;
  final double sleeveCm;
  final double lengthCm;
  final String fit;
  final double confidence;
  final List<String> bodyOutlineHighlights;

  MeasurementProfile toMeasurementProfile({
    required String userId,
    required String label,
  }) {
    return MeasurementProfile(
      id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      label: label,
      method: 'ai_scan',
      unit: 'cm',
      chest: chestCm,
      shoulder: shoulderCm,
      waist: waistCm,
      sleeve: sleeveCm,
      length: lengthCm,
      recommendedSize: shirtSize,
    );
  }
}

class BodyScanService {
  const BodyScanService();

  SizePredictionResult analyze(
    BodyScanInput input, {
    PoseRefinementResult? poseRefinement,
  }) {
    final bmi = input.weightKg / math.pow(input.heightCm / 100, 2);
    final frameBias = switch (input.bodyFrame) {
      'slim' => -2.5,
      'heavy' => 3.6,
      'regular' => 0.0,
      'athletic' => 1.8,
      'curvy' => 3.6,
      _ => 0.0,
    };
    final chest = ((input.heightCm * 0.53) + (bmi * 1.45) + frameBias) +
        (poseRefinement?.chestAdjustment ?? 0);
    final waist = ((input.heightCm * 0.42) + (bmi * 1.10) + (frameBias * 0.9)) +
        (poseRefinement?.waistAdjustment ?? 0);
    final hip = (waist + (input.bodyFrame == 'curvy' ? 10 : 7)) +
        (poseRefinement?.hipAdjustment ?? 0);
    final shoulder = ((input.heightCm * 0.24) + (frameBias * 0.45)) +
        (poseRefinement?.shoulderAdjustment ?? 0);
    final sleeve = (input.heightCm * 0.34) + (frameBias * 0.2);
    final length = (input.heightCm * 0.41) + (frameBias * 0.2);

    final shirtSize = _shirtSizeFor(chest);
    final pantSize = _pantSizeFor(waist);
    final confidence = (_confidenceFor(input, bmi) +
            (poseRefinement?.confidenceBoost ?? 0))
        .clamp(0.74, 0.98);
    final fit = bmi >= 28
        ? 'Relaxed'
        : bmi <= 20
            ? 'Slim'
            : 'Regular';

    return SizePredictionResult(
      shirtSize: shirtSize,
      pantSize: pantSize,
      chestCm: chest,
      waistCm: waist,
      hipCm: hip,
      shoulderCm: shoulder,
      sleeveCm: sleeve,
      lengthCm: length,
      fit: fit,
      confidence: confidence,
      bodyOutlineHighlights: [
        'Shoulder width aligned with a $shirtSize upper-body fit',
        'Waist estimate points to $pantSize trousers',
        if (input.sideImagePath != null && input.sideImagePath!.isNotEmpty)
          'Side-view capture increased confidence for torso depth',
        ...?poseRefinement?.highlights,
      ],
    );
  }

  String chooseBestProductSize(Product product, SizePredictionResult result) {
    if (product.sizes.isEmpty) {
      return result.shirtSize;
    }
    final normalized = product.sizes.map((size) => size.toUpperCase()).toList();
    if (normalized.contains(result.shirtSize.toUpperCase())) {
      return result.shirtSize.toUpperCase();
    }
    const order = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    final shirtIndex = order.indexOf(result.shirtSize.toUpperCase());
    if (shirtIndex < 0) {
      return normalized.first;
    }
    String best = normalized.first;
    var bestDistance = 999;
    for (final size in normalized) {
      final index = order.indexOf(size);
      if (index < 0) {
        continue;
      }
      final distance = (index - shirtIndex).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = size;
      }
    }
    return best;
  }

  double _confidenceFor(BodyScanInput input, double bmi) {
    var value = input.sideImagePath != null && input.sideImagePath!.isNotEmpty ? 0.91 : 0.84;
    if (input.frontImagePath != null && input.frontImagePath!.isNotEmpty) {
      value += 0.03;
    }
    if (bmi < 18 || bmi > 32) {
      value -= 0.05;
    }
    return value.clamp(0.74, 0.96);
  }

  String _shirtSizeFor(double chest) {
    if (chest < 88) return 'XS';
    if (chest < 95) return 'S';
    if (chest < 102) return 'M';
    if (chest < 110) return 'L';
    if (chest < 118) return 'XL';
    return 'XXL';
  }

  String _pantSizeFor(double waist) {
    if (waist < 73) return '28';
    if (waist < 78) return '30';
    if (waist < 84) return '32';
    if (waist < 90) return '34';
    if (waist < 96) return '36';
    return '38';
  }
}
