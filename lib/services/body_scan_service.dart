import 'dart:math' as math;

import '../models/models.dart';
import 'pose_measurement_service.dart';

class BodyScanInput {
  const BodyScanInput({
    required this.heightCm,
    required this.weightKg,
    required this.bodyFrame,
    this.fitPreference = 'regular',
    this.frontImagePath,
    this.sideImagePath,
  });

  final double heightCm;
  final double weightKg;
  final String bodyFrame;
  final String fitPreference;
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
    required this.armLengthCm,
    required this.inseamCm,
    required this.sleeveCm,
    required this.lengthCm,
    required this.fit,
    required this.confidence,
    required this.bodyOutlineHighlights,
    this.message = 'Best fit based on your body profile',
    this.reasoning = '',
    this.accuracyLabel = 'Medium',
    this.detectedBodyType = 'Regular',
    this.bodyTypeConfidence = 0.78,
    this.usedManualEstimate = false,
    this.canImproveWithSideScan = false,
    this.privacyNote =
        'Your images are never stored. Only measurements are محفوظ.',
  });

  final String shirtSize;
  final String pantSize;
  final double chestCm;
  final double waistCm;
  final double hipCm;
  final double shoulderCm;
  final double armLengthCm;
  final double inseamCm;
  final double sleeveCm;
  final double lengthCm;
  final String fit;
  final double confidence;
  final List<String> bodyOutlineHighlights;
  final String message;
  final String reasoning;
  final String accuracyLabel;
  final String detectedBodyType;
  final double bodyTypeConfidence;
  final bool usedManualEstimate;
  final bool canImproveWithSideScan;
  final String privacyNote;

  String get confidenceLabel {
    if (confidence >= 0.86) return 'High';
    if (confidence >= 0.72) return 'Medium';
    return 'Low';
  }

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
    String? productFit,
  }) {
    final refinement = poseRefinement;
    final bmi = input.weightKg / math.pow(input.heightCm / 100, 2);
    final normalizedFit = (productFit ?? '').trim().toLowerCase();
    final normalizedFitPreference = input.fitPreference.trim().toLowerCase();
    final normalizedFrame = input.bodyFrame.trim().toLowerCase();
    final reasons = <String>['Base size from weight'];
    var shirtIndex = _baseShirtIndex(input.weightKg);
    if (input.heightCm > 180) {
      shirtIndex += 1;
      reasons.add('Increased for taller height');
    } else if (input.heightCm < 165) {
      shirtIndex -= 1;
      reasons.add('Reduced for shorter height');
    }
    if (normalizedFrame == 'slim') {
      shirtIndex -= 1;
      reasons.add('Adjusted down for slim body type');
    } else if (normalizedFrame == 'heavy') {
      shirtIndex += 1;
      reasons.add('Adjusted up for heavy body type');
    }
    if (normalizedFit == 'slim') {
      shirtIndex += 1;
      reasons.add('Adjusted up for slim-fit product');
    } else if (normalizedFit == 'oversized') {
      shirtIndex -= 1;
      reasons.add('Adjusted down for oversized fit');
    }
    if (normalizedFitPreference == 'slim') {
      shirtIndex += 1;
      reasons.add('Adjusted up for slim fit preference');
    } else if (normalizedFitPreference == 'loose') {
      shirtIndex -= 1;
      reasons.add('Adjusted down for loose fit preference');
    }
    shirtIndex = shirtIndex.clamp(0, _shirtOrder.length - 1);
    final shirtSize = _shirtOrder[shirtIndex];
    final frameBias = switch (normalizedFrame) {
      'slim' => -2.0,
      'heavy' => 3.2,
      'regular' => 0.0,
      'athletic' => 1.6,
      'curvy' => 3.2,
      _ => 0.0,
    };
    final hasScanData = refinement != null;
    final chest = hasScanData
        ? refinement.chestCm
        : ((input.heightCm * 0.53) + (bmi * 1.45) + frameBias);
    final waist = hasScanData
        ? refinement.waistCm
        : ((input.heightCm * 0.42) + (bmi * 1.10) + (frameBias * 0.9));
    final hip = hasScanData
        ? refinement.hipCm
        : (waist + (input.bodyFrame == 'curvy' ? 10 : 7));
    final shoulder = hasScanData
        ? refinement.shoulderWidthCm
        : ((input.heightCm * 0.24) + (frameBias * 0.45));
    final sleeve = (input.heightCm * 0.34) + (frameBias * 0.2);
    final length = (input.heightCm * 0.41) + (frameBias * 0.2);
    final armLength = (input.heightCm * 0.36) + (frameBias * 0.16);
    final inseam = (input.heightCm * 0.46) + (frameBias * 0.2);

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
      armLengthCm: armLength,
      inseamCm: inseam,
      sleeveCm: sleeve,
      lengthCm: length,
      fit: fit,
      confidence: confidence,
      accuracyLabel: poseRefinement?.accuracyLabel ??
          (input.sideImagePath != null && input.sideImagePath!.isNotEmpty
              ? 'High'
              : input.frontImagePath != null && input.frontImagePath!.isNotEmpty
                  ? 'Medium'
                  : 'Low'),
      detectedBodyType: poseRefinement?.detectedBodyType ??
          _bodyTypeFromFrame(normalizedFrame),
      bodyTypeConfidence: poseRefinement?.bodyTypeConfidence ??
          (normalizedFrame == 'regular' ? 0.78 : 0.72),
      usedManualEstimate: !hasScanData,
      canImproveWithSideScan:
          input.frontImagePath != null &&
          input.frontImagePath!.isNotEmpty &&
          (input.sideImagePath == null || input.sideImagePath!.isEmpty),
      message: hasScanData
          ? 'Best fit based on your body profile'
          : 'Using manual estimation',
      reasoning: reasons.join(', '),
      privacyNote: 'Your images are never stored. Only measurements are محفوظ.',
      bodyOutlineHighlights: [
        'We suggest size $shirtSize',
        if (hasScanData)
          'Scan data is driving this recommendation with higher priority'
        else
          'Manual height, weight, and body frame are driving this estimate',
        'Shoulder width aligned with a $shirtSize upper-body fit',
        'Waist estimate points to $pantSize trousers',
        if (input.sideImagePath != null && input.sideImagePath!.isNotEmpty)
          'Side-view capture increased confidence for torso depth',
        ...?poseRefinement?.highlights,
      ],
    );
  }

  static const List<String> _shirtOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  int _baseShirtIndex(double weightKg) {
    if (weightKg < 60) return 1;
    if (weightKg <= 75) return 2;
    return 3;
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

  String _pantSizeFor(double waist) {
    if (waist < 73) return '28';
    if (waist < 78) return '30';
    if (waist < 84) return '32';
    if (waist < 90) return '34';
    if (waist < 96) return '36';
    return '38';
  }

  String _bodyTypeFromFrame(String frame) {
    switch (frame) {
      case 'slim':
        return 'Athletic';
      case 'heavy':
        return 'Heavy';
      default:
        return 'Regular';
    }
  }
}
