import 'dart:convert';
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

class ProductSizeRecommendation {
  const ProductSizeRecommendation({
    required this.recommendedSize,
    required this.confidence,
    required this.reasoning,
    required this.usedProductChart,
  });

  final String recommendedSize;
  final double confidence;
  final List<String> reasoning;
  final bool usedProductChart;
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
    final confidence =
        (_confidenceFor(input, bmi) + (poseRefinement?.confidenceBoost ?? 0))
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
      accuracyLabel:
          poseRefinement?.accuracyLabel ??
          (input.sideImagePath != null && input.sideImagePath!.isNotEmpty
              ? 'High'
              : input.frontImagePath != null && input.frontImagePath!.isNotEmpty
              ? 'Medium'
              : 'Low'),
      detectedBodyType:
          poseRefinement?.detectedBodyType ??
          _bodyTypeFromFrame(normalizedFrame),
      bodyTypeConfidence:
          poseRefinement?.bodyTypeConfidence ??
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
    return recommendProductSize(product, result).recommendedSize;
  }

  ProductSizeRecommendation recommendProductSize(
    Product product,
    SizePredictionResult result,
  ) {
    final normalizedSizes = product.sizes
        .map((size) => size.trim().toUpperCase())
        .where((size) => size.isNotEmpty)
        .toList();
    if (normalizedSizes.isEmpty) {
      return ProductSizeRecommendation(
        recommendedSize: result.shirtSize,
        confidence: result.confidence,
        reasoning: const [
          'No product sizes were listed, so we used the body profile size.',
        ],
        usedProductChart: false,
      );
    }

    final productChart = _buildProductSizeChart(product, normalizedSizes);
    if (productChart.isNotEmpty) {
      final best = _bestSizeFromChart(
        productChart,
        chest: result.chestCm,
        waist: result.waistCm,
        hip: result.hipCm,
      );
      if (best != null) {
        final fitConfidence = _productChartConfidence(
          productChart[best],
          chest: result.chestCm,
          waist: result.waistCm,
          hip: result.hipCm,
        );
        return ProductSizeRecommendation(
          recommendedSize: best,
          confidence: fitConfidence,
          reasoning: [
            'Aligned your scan with the product size chart.',
            'Chest, waist, and hip measurements were weighed against the garment measurements.',
          ],
          usedProductChart: true,
        );
      }
    }

    final normalized = normalizedSizes;
    if (normalized.contains(result.shirtSize.toUpperCase())) {
      return ProductSizeRecommendation(
        recommendedSize: result.shirtSize.toUpperCase(),
        confidence: result.confidence,
        reasoning: ['The product offers your body-profile size directly.'],
        usedProductChart: false,
      );
    }

    const order = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    final shirtIndex = order.indexOf(result.shirtSize.toUpperCase());
    if (shirtIndex < 0) {
      return ProductSizeRecommendation(
        recommendedSize: normalized.first,
        confidence: (result.confidence * 0.9).clamp(0.45, 0.96),
        reasoning: ['Used the closest available product size.'],
        usedProductChart: false,
      );
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

    return ProductSizeRecommendation(
      recommendedSize: best,
      confidence: (result.confidence - (bestDistance * 0.05)).clamp(0.48, 0.94),
      reasoning: [
        'Used the closest available product size to your scan recommendation.',
      ],
      usedProductChart: false,
    );
  }

  double _confidenceFor(BodyScanInput input, double bmi) {
    var value = input.sideImagePath != null && input.sideImagePath!.isNotEmpty
        ? 0.91
        : 0.84;
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

  Map<String, Map<String, double>> _buildProductSizeChart(
    Product product,
    List<String> availableSizes,
  ) {
    final chart = <String, Map<String, double>>{};
    final jsonSizeChart = _parseJsonSizeChart(
      product.attributeText('sizeChart'),
    );
    if (jsonSizeChart.isNotEmpty) {
      chart.addAll(jsonSizeChart);
    }

    for (final entry in product.attributes.entries) {
      final sizeMatch = RegExp(
        r'\b(xs|s|m|l|xl|xxl|xxxl)\b',
        caseSensitive: false,
      ).firstMatch(entry.key);
      if (sizeMatch == null) {
        continue;
      }
      final size = sizeMatch.group(1)!.toUpperCase();
      final metric = _metricFromKey(entry.key);
      final measurement = _toMeasurement(entry.value);
      if (metric == null || measurement == null) {
        continue;
      }
      chart.putIfAbsent(size, () => <String, double>{});
      chart[size]![metric] = measurement;
    }

    for (final entry in product.structuredAttributes) {
      final sizeLabel =
          entry['size']?.toString().trim().toUpperCase() ??
          entry['label']?.toString().trim().toUpperCase() ??
          '';
      if (!RegExp(r'^(XS|S|M|L|XL|XXL|XXXL)$').hasMatch(sizeLabel)) {
        continue;
      }
      final metric = _metricFromKey(entry['key']?.toString() ?? '');
      final measurement = _toMeasurement(entry['value']?.toString());
      if (metric == null || measurement == null) {
        continue;
      }
      chart.putIfAbsent(sizeLabel, () => <String, double>{});
      chart[sizeLabel]![metric] = measurement;
    }

    if (chart.isEmpty) {
      final categoryChart = _categorySizeChart(
        product.category,
        product.outfitType,
        availableSizes,
      );
      chart.addAll(categoryChart);
    }

    return chart;
  }

  Map<String, Map<String, double>> _parseJsonSizeChart(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const {};
      }
      final result = <String, Map<String, double>>{};
      for (final entry in decoded.entries) {
        final size = entry.key.toString().trim().toUpperCase();
        if (size.isEmpty) {
          continue;
        }
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        final parsed = <String, double>{};
        for (final metric in value.entries) {
          final metricName = _metricFromKey(metric.key.toString());
          final measurement = _toMeasurement(metric.value?.toString());
          if (metricName == null || measurement == null) {
            continue;
          }
          parsed[metricName] = measurement;
        }
        if (parsed.isNotEmpty) {
          result[size] = parsed;
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  String? _metricFromKey(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.contains('chest')) return 'chest';
    if (normalized.contains('waist')) return 'waist';
    if (normalized.contains('hip')) return 'hip';
    if (normalized.contains('shoulder')) return 'shoulder';
    if (normalized.contains('inseam')) return 'inseam';
    if (normalized.contains('arm')) return 'armLength';
    return null;
  }

  double? _toMeasurement(String? value) {
    if (value == null) {
      return null;
    }
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    final rangeMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*[-to]+\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (rangeMatch != null) {
      final left = double.tryParse(rangeMatch.group(1)!);
      final right = double.tryParse(rangeMatch.group(2)!);
      if (left != null && right != null) {
        return (left + right) / 2;
      }
    }
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  Map<String, Map<String, double>> _categorySizeChart(
    String category,
    String? outfitType,
    List<String> availableSizes,
  ) {
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedFit = (outfitType ?? '').trim().toLowerCase();
    final base = switch (normalizedCategory) {
      'pants' ||
      'trousers' ||
      'bottomwear' => <String, double>{'waist': 86, 'hip': 102, 'inseam': 79},
      'kurta' || 'ethnic' || 'traditional' => <String, double>{
        'chest': 104,
        'waist': 98,
        'shoulder': 45,
      },
      'jacket' || 'outerwear' => <String, double>{
        'chest': 106,
        'waist': 100,
        'shoulder': 46,
      },
      _ => <String, double>{'chest': 100, 'waist': 92, 'shoulder': 44},
    };
    final fitAdjustment = switch (normalizedFit) {
      'slim' => -2.0,
      'oversized' => 4.0,
      'relaxed' => 2.0,
      'athletic' => 1.0,
      _ => 0.0,
    };

    final sizes = availableSizes.isNotEmpty ? availableSizes : _shirtOrder;
    return {
      for (var i = 0; i < sizes.length; i += 1)
        sizes[i]: {
          for (final entry in base.entries)
            entry.key: entry.value + ((i - 2) * 4) + fitAdjustment,
        },
    };
  }

  String? _bestSizeFromChart(
    Map<String, Map<String, double>> chart, {
    required double chest,
    required double waist,
    required double hip,
  }) {
    if (chart.isEmpty) {
      return null;
    }
    String? bestSize;
    var bestScore = double.infinity;
    for (final entry in chart.entries) {
      var score = 0.0;
      final measurements = entry.value;
      if (measurements['chest'] != null) {
        score += (measurements['chest']! - chest).abs() * 1.2;
      }
      if (measurements['waist'] != null) {
        score += (measurements['waist']! - waist).abs() * 1.0;
      }
      if (measurements['hip'] != null) {
        score += (measurements['hip']! - hip).abs() * 0.9;
      }
      if (score < bestScore) {
        bestScore = score;
        bestSize = entry.key;
      }
    }
    return bestSize;
  }

  double _productChartConfidence(
    Map<String, double>? measurements, {
    required double chest,
    required double waist,
    required double hip,
  }) {
    if (measurements == null || measurements.isEmpty) {
      return 0.74;
    }
    var penalty = 0.0;
    var usedMetrics = 0;
    if (measurements['chest'] != null) {
      penalty +=
          ((measurements['chest']! - chest).abs() /
              math.max(measurements['chest']!, 1)) *
          1.2;
      usedMetrics += 1;
    }
    if (measurements['waist'] != null) {
      penalty +=
          ((measurements['waist']! - waist).abs() /
              math.max(measurements['waist']!, 1)) *
          1.0;
      usedMetrics += 1;
    }
    if (measurements['hip'] != null) {
      penalty +=
          ((measurements['hip']! - hip).abs() /
              math.max(measurements['hip']!, 1)) *
          0.9;
      usedMetrics += 1;
    }
    final base = usedMetrics >= 3
        ? 0.93
        : usedMetrics == 2
        ? 0.87
        : 0.81;
    return (base - (penalty * 0.35)).clamp(0.55, 0.97);
  }
}
