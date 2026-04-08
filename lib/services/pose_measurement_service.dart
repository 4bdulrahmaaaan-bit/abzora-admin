import 'dart:math' as math;

import 'mediapipe_pose_bridge.dart';

enum PoseGuideState {
  detecting,
  adjust,
  aligned,
}

class PoseFrameFeedback {
  const PoseFrameFeedback({
    required this.state,
    required this.message,
    required this.progress,
    required this.skeletonSegments,
    this.alignmentHint,
  });

  final PoseGuideState state;
  final String message;
  final double progress;
  final List<List<NormalizedLandmarkPoint>> skeletonSegments;
  final String? alignmentHint;

  bool get isAligned => state == PoseGuideState.aligned;
}

class TryOnPoseFrame {
  const TryOnPoseFrame({
    required this.feedback,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
    required this.shoulderCenter,
    required this.hipCenter,
    required this.shoulderWidth,
    required this.torsoHeight,
    required this.rotationRadians,
  });

  final PoseFrameFeedback feedback;
  final NormalizedLandmarkPoint leftShoulder;
  final NormalizedLandmarkPoint rightShoulder;
  final NormalizedLandmarkPoint leftHip;
  final NormalizedLandmarkPoint rightHip;
  final NormalizedLandmarkPoint shoulderCenter;
  final NormalizedLandmarkPoint hipCenter;
  final double shoulderWidth;
  final double torsoHeight;
  final double rotationRadians;
}

class NormalizedLandmarkPoint {
  const NormalizedLandmarkPoint(this.x, this.y);

  final double x;
  final double y;
}

class PoseRefinementResult {
  const PoseRefinementResult({
    required this.chestAdjustment,
    required this.waistAdjustment,
    required this.hipAdjustment,
    required this.shoulderAdjustment,
    required this.confidenceBoost,
    required this.highlights,
    required this.accuracyLabel,
    required this.detectedBodyType,
    required this.bodyTypeConfidence,
    required this.shoulderWidthCm,
    required this.chestCm,
    required this.waistCm,
    required this.hipCm,
    required this.bodyRatio,
    required this.usedSideScan,
    required this.confidencePercent,
  });

  final double chestAdjustment;
  final double waistAdjustment;
  final double hipAdjustment;
  final double shoulderAdjustment;
  final double confidenceBoost;
  final List<String> highlights;
  final String accuracyLabel;
  final String detectedBodyType;
  final double bodyTypeConfidence;
  final double shoulderWidthCm;
  final double chestCm;
  final double waistCm;
  final double hipCm;
  final double bodyRatio;
  final bool usedSideScan;
  final int confidencePercent;

  Map<String, double> toMeasurementCm() {
    return {
      'chest': chestCm,
      'waist': waistCm,
      'hips': hipCm,
    };
  }

  Map<String, dynamic> toMeasurementOutput() {
    return {
      'chest': chestCm,
      'waist': waistCm,
      'hips': hipCm,
      'confidence': confidencePercent,
    };
  }

  static PoseRefinementResult? merge(
    PoseRefinementResult? front,
    PoseRefinementResult? side,
  ) {
    if (front == null && side == null) {
      return null;
    }
    if (front == null) {
      return side;
    }
    if (side == null) {
      return front;
    }

    final improvedWaist = ((front.waistCm * 0.72) + (side.waistCm * 0.28));
    final improvedHip = ((front.hipCm * 0.72) + (side.hipCm * 0.28));
    final bodyRatio = improvedWaist <= 0 ? 1.0 : front.chestCm / improvedWaist;
    final bodyType = PoseMeasurementService._bodyTypeFromRatio(bodyRatio);

    return PoseRefinementResult(
      chestAdjustment: front.chestAdjustment,
      waistAdjustment: (front.waistAdjustment + side.waistAdjustment) / 2,
      hipAdjustment: (front.hipAdjustment + side.hipAdjustment) / 2,
      shoulderAdjustment: front.shoulderAdjustment,
      confidenceBoost: math.max(front.confidenceBoost, 0.12),
      highlights: [
        ...front.highlights,
        'Side scan improved waist depth estimation and overall accuracy',
      ],
      accuracyLabel: 'High',
      detectedBodyType: bodyType.$1,
      bodyTypeConfidence: math.max(
        front.bodyTypeConfidence,
        bodyType.$2,
      ).clamp(0.0, 0.99),
      shoulderWidthCm: front.shoulderWidthCm,
      chestCm: front.chestCm,
      waistCm: improvedWaist,
      hipCm: improvedHip,
      bodyRatio: bodyRatio,
      usedSideScan: true,
      confidencePercent: (((front.confidencePercent * 0.65) + (side.confidencePercent * 0.35))
              .round()
              .clamp(72, 98))
          .toInt(),
    );
  }

  static PoseRefinementResult? average(List<PoseRefinementResult> results) {
    if (results.isEmpty) {
      return null;
    }
    final trimmed = _discardOutliers(results);
    final effective = trimmed.isEmpty ? results : trimmed;
    double sum(double Function(PoseRefinementResult item) picker) =>
        effective.fold<double>(0, (total, item) => total + picker(item));
    final count = effective.length.toDouble();
    final avgChest = sum((item) => item.chestCm) / count;
    final avgWaist = sum((item) => item.waistCm) / count;
    final avgHip = sum((item) => item.hipCm) / count;
    final avgShoulder = sum((item) => item.shoulderWidthCm) / count;
    final avgRatio = avgWaist <= 0 ? 1.0 : avgChest / avgWaist;
    final bodyType = PoseMeasurementService._bodyTypeFromRatio(avgRatio);
    final spread = _relativeSpread(effective);
    final sampleScore = (effective.length / 10).clamp(0.0, 1.0);
    final stabilityScore = (1 - spread).clamp(0.0, 1.0);
    final confidencePercent = ((56 + (sampleScore * 24) + (stabilityScore * 20))
            .round()
            .clamp(56, 98))
        .toInt();
    return PoseRefinementResult(
      chestAdjustment: sum((item) => item.chestAdjustment) / count,
      waistAdjustment: sum((item) => item.waistAdjustment) / count,
      hipAdjustment: sum((item) => item.hipAdjustment) / count,
      shoulderAdjustment: sum((item) => item.shoulderAdjustment) / count,
      confidenceBoost: (sum((item) => item.confidenceBoost) / count)
          .clamp(0.04, 0.16),
      highlights: [
        'Averaged ${effective.length} pose frames for smoother measurements',
        if (effective.length < results.length)
          'Outlier frames were discarded to reduce noise and jitter',
      ],
      accuracyLabel: confidencePercent >= 88
          ? 'High'
          : confidencePercent >= 72
              ? 'Medium'
              : 'Low',
      detectedBodyType: bodyType.$1,
      bodyTypeConfidence: bodyType.$2,
      shoulderWidthCm: avgShoulder,
      chestCm: avgChest,
      waistCm: avgWaist,
      hipCm: avgHip,
      bodyRatio: avgRatio,
      usedSideScan: effective.any((item) => item.usedSideScan),
      confidencePercent: confidencePercent,
    );
  }

  static List<PoseRefinementResult> _discardOutliers(
    List<PoseRefinementResult> rows,
  ) {
    if (rows.length < 5) {
      return rows;
    }
    final chestMedian = _median(rows.map((e) => e.chestCm).toList());
    final waistMedian = _median(rows.map((e) => e.waistCm).toList());
    final hipMedian = _median(rows.map((e) => e.hipCm).toList());

    const tolerance = 0.12; // 12% median relative error tolerance
    final kept = rows.where((row) {
      final chestRel = _relativeDelta(row.chestCm, chestMedian);
      final waistRel = _relativeDelta(row.waistCm, waistMedian);
      final hipRel = _relativeDelta(row.hipCm, hipMedian);
      return chestRel <= tolerance && waistRel <= tolerance && hipRel <= tolerance;
    }).toList();
    return kept.length >= 4 ? kept : rows;
  }

  static double _relativeSpread(List<PoseRefinementResult> rows) {
    if (rows.length <= 1) {
      return 0;
    }
    final chestSpread = _coefficientOfVariation(rows.map((e) => e.chestCm).toList());
    final waistSpread = _coefficientOfVariation(rows.map((e) => e.waistCm).toList());
    final hipSpread = _coefficientOfVariation(rows.map((e) => e.hipCm).toList());
    return ((chestSpread + waistSpread + hipSpread) / 3).clamp(0.0, 1.0);
  }

  static double _coefficientOfVariation(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean.abs() < 0.0001) {
      return 0;
    }
    final variance = values.fold<double>(
              0,
              (sum, v) => sum + math.pow(v - mean, 2).toDouble(),
            ) /
            values.length;
    return (math.sqrt(variance) / mean.abs()).clamp(0.0, 1.0);
  }

  static double _median(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double _relativeDelta(double value, double baseline) {
    if (baseline.abs() < 0.0001) {
      return 0;
    }
    return ((value - baseline).abs() / baseline.abs()).clamp(0.0, 10.0);
  }
}

class PoseMeasurementService {
  const PoseMeasurementService();

  Future<PoseRefinementResult?> analyzeFromFile(
    String imagePath, {
    required double heightCm,
    bool isSideView = false,
  }) async {
    final landmarks = await MediaPipePoseBridge.instance.processImagePath(
      imagePath,
    );
    final pose = _toPose(landmarks);
    if (pose == null) {
      return null;
    }
    return _buildRefinement(
      pose,
      heightCm: heightCm,
      isSideView: isSideView,
    );
  }

  Future<PoseFrameFeedback> analyzeLiveInputImage(
    MediaPipePoseFrameInput inputFrame, {
    required double heightCm,
    bool isSideView = false,
  }) async {
    final landmarks = await MediaPipePoseBridge.instance.processFrame(inputFrame);
    final pose = _toPose(landmarks);
    if (pose == null) {
      return const PoseFrameFeedback(
        state: PoseGuideState.detecting,
        message: 'Detecting...',
        progress: 0.2,
        skeletonSegments: [],
        alignmentHint: 'Move your full body into the frame',
      );
    }
    return _buildFrameFeedback(
      pose,
      heightCm: heightCm,
      isSideView: isSideView,
    );
  }

  Future<TryOnPoseFrame?> analyzeTryOnLiveInputImage(
    MediaPipePoseFrameInput inputFrame, {
    bool isSideView = false,
  }) async {
    final landmarks = await MediaPipePoseBridge.instance.processFrame(inputFrame);
    final pose = _toPose(landmarks);
    if (pose == null) {
      return null;
    }
    return _buildTryOnFrame(
      pose,
      isSideView: isSideView,
    );
  }

  Future<PoseRefinementResult?> analyzeLiveRefinementInputImage(
    MediaPipePoseFrameInput inputFrame, {
    required double heightCm,
    bool isSideView = false,
  }) async {
    final landmarks = await MediaPipePoseBridge.instance.processFrame(inputFrame);
    final pose = _toPose(landmarks);
    if (pose == null) {
      return null;
    }
    return _buildRefinement(
      pose,
      heightCm: heightCm,
      isSideView: isSideView,
    );
  }

  Pose? _toPose(List<MediaPipePoseLandmark> landmarks) {
    if (landmarks.isEmpty) {
      return null;
    }
    final mapped = <PoseLandmarkType, PoseLandmark>{};
    for (final landmark in landmarks) {
      final type = PoseLandmarkType.fromMediaPipeType(landmark.type);
      if (type == null) {
        continue;
      }
      mapped[type] = PoseLandmark(
        x: landmark.x,
        y: landmark.y,
        z: landmark.z,
        visibility: landmark.visibility,
      );
    }
    if (mapped.isEmpty) {
      return null;
    }
    return Pose(mapped);
  }

  PoseFrameFeedback _buildFrameFeedback(
    Pose pose, {
    required double heightCm,
    required bool isSideView,
  }) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        nose == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return const PoseFrameFeedback(
        state: PoseGuideState.detecting,
        message: 'Detecting...',
        progress: 0.28,
        skeletonSegments: [],
        alignmentHint: 'Keep your full body visible from head to ankle',
      );
    }

    final skeleton = _skeletonSegments(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
      leftKnee: leftKnee,
      rightKnee: rightKnee,
      leftAnkle: leftAnkle,
      rightAnkle: rightAnkle,
      nose: nose,
    );

    final keyVisibility = <double>[
      leftShoulder.visibility,
      rightShoulder.visibility,
      leftHip.visibility,
      rightHip.visibility,
      leftKnee.visibility,
      rightKnee.visibility,
      leftAnkle.visibility,
      rightAnkle.visibility,
      nose.visibility,
    ];
    final avgVisibility =
        keyVisibility.reduce((a, b) => a + b) / keyVisibility.length;
    if (avgVisibility < 0.42) {
      return PoseFrameFeedback(
        state: PoseGuideState.detecting,
        message: 'Re-align body',
        progress: 0.26,
        skeletonSegments: skeleton,
        alignmentHint: 'Improve lighting and step into frame',
      );
    }

    final shoulderSlope =
        ((leftShoulder.y - rightShoulder.y).abs() / 220).clamp(0.0, 1.0);
    final hipSlope = ((leftHip.y - rightHip.y).abs() / 240).clamp(0.0, 1.0);
    final torsoCenterX =
        ((leftShoulder.x + rightShoulder.x + leftHip.x + rightHip.x) / 4);
    final bodyCenterOffset =
        ((torsoCenterX - nose.x).abs() / 180).clamp(0.0, 1.0);
    final heightPixels =
        (((leftAnkle.y + rightAnkle.y) / 2) - nose.y).abs().clamp(1.0, 9999.0);
    final shoulderWidth =
        _distance(leftShoulder.x, leftShoulder.y, rightShoulder.x, rightShoulder.y);
    final widthCoverage = (shoulderWidth / heightPixels).clamp(0.0, 1.0);

    final alignmentScore = (1 -
            (shoulderSlope * 0.28) -
            (hipSlope * 0.24) -
            (bodyCenterOffset * 0.34) +
            (widthCoverage * 0.22))
        .clamp(0.0, 1.0);

    if (alignmentScore >= 0.82) {
      return PoseFrameFeedback(
        state: PoseGuideState.aligned,
        message: 'Hold still',
        progress: 1.0,
        skeletonSegments: skeleton,
        alignmentHint: 'Hold still',
      );
    }
    if (alignmentScore >= 0.52) {
      return PoseFrameFeedback(
        state: PoseGuideState.adjust,
        message: 'Align shoulders',
        progress: 0.62,
        skeletonSegments: skeleton,
        alignmentHint: 'Align shoulders',
      );
    }
    return PoseFrameFeedback(
      state: PoseGuideState.detecting,
      message: 'Move back',
      progress: 0.34,
      skeletonSegments: skeleton,
      alignmentHint: 'Move back',
    );
  }

  TryOnPoseFrame? _buildTryOnFrame(
    Pose pose, {
    required bool isSideView,
  }) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        nose == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }

    final feedback = _buildFrameFeedback(
      pose,
      heightCm: 170,
      isSideView: isSideView,
    );
    final allPoints = <PoseLandmark>[
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
      nose,
    ];
    final avgVisibility =
        allPoints.map((point) => point.visibility).reduce((a, b) => a + b) /
        allPoints.length;
    final coreVisibility = [
      leftShoulder.visibility,
      rightShoulder.visibility,
      leftHip.visibility,
      rightHip.visibility,
    ].reduce((a, b) => a + b) /
        4;
    if (avgVisibility < 0.4 || coreVisibility < 0.5) {
      return null;
    }
    final minX = allPoints.map((point) => point.x).reduce(math.min);
    final maxX = allPoints.map((point) => point.x).reduce(math.max);
    final minY = allPoints.map((point) => point.y).reduce(math.min);
    final maxY = allPoints.map((point) => point.y).reduce(math.max);
    final rangeX = math.max(1.0, maxX - minX);
    final rangeY = math.max(1.0, maxY - minY);

    NormalizedLandmarkPoint normalize(PoseLandmark point) {
      return NormalizedLandmarkPoint(
        ((point.x - minX) / rangeX).clamp(0.0, 1.0),
        ((point.y - minY) / rangeY).clamp(0.0, 1.0),
      );
    }

    final normalizedLeftShoulder = normalize(leftShoulder);
    final normalizedRightShoulder = normalize(rightShoulder);
    final normalizedLeftHip = normalize(leftHip);
    final normalizedRightHip = normalize(rightHip);
    final shoulderCenter = NormalizedLandmarkPoint(
      (normalizedLeftShoulder.x + normalizedRightShoulder.x) / 2,
      (normalizedLeftShoulder.y + normalizedRightShoulder.y) / 2,
    );
    final hipCenter = NormalizedLandmarkPoint(
      (normalizedLeftHip.x + normalizedRightHip.x) / 2,
      (normalizedLeftHip.y + normalizedRightHip.y) / 2,
    );
    final shoulderWidth = _distance(
      normalizedLeftShoulder.x,
      normalizedLeftShoulder.y,
      normalizedRightShoulder.x,
      normalizedRightShoulder.y,
    );
    final torsoHeight = _distance(
      shoulderCenter.x,
      shoulderCenter.y,
      hipCenter.x,
      hipCenter.y,
    );
    final rotationRadians = math.atan2(
      normalizedRightShoulder.y - normalizedLeftShoulder.y,
      normalizedRightShoulder.x - normalizedLeftShoulder.x,
    );

    return TryOnPoseFrame(
      feedback: feedback,
      leftShoulder: normalizedLeftShoulder,
      rightShoulder: normalizedRightShoulder,
      leftHip: normalizedLeftHip,
      rightHip: normalizedRightHip,
      shoulderCenter: shoulderCenter,
      hipCenter: hipCenter,
      shoulderWidth: shoulderWidth,
      torsoHeight: torsoHeight,
      rotationRadians: rotationRadians,
    );
  }

  PoseRefinementResult? _buildRefinement(
    Pose pose, {
    required double heightCm,
    required bool isSideView,
  }) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }

    final shoulderMid = _midPoint(leftShoulder, rightShoulder);
    final ankleMid = _midPoint(leftAnkle, rightAnkle);
    final midHead = nose == null
        ? shoulderMid
        : PoseLandmark(
            x: (nose.x + shoulderMid.x) / 2,
            y: (nose.y + shoulderMid.y) / 2,
            z: (nose.z + shoulderMid.z) / 2,
            visibility: (nose.visibility + shoulderMid.visibility) / 2,
          );

    final bodyPixelHeight = _distance(
      midHead.x,
      midHead.y,
      ankleMid.x,
      ankleMid.y,
    ).clamp(1.0, 9999.0);
    final cmPerPixel = (heightCm / bodyPixelHeight).clamp(0.05, 0.9);

    final shoulderWidthPx = _distance(
      leftShoulder.x,
      leftShoulder.y,
      rightShoulder.x,
      rightShoulder.y,
    );
    final hipWidthPx = _distance(
      leftHip.x,
      leftHip.y,
      rightHip.x,
      rightHip.y,
    );

    final shoulderWidthCm = shoulderWidthPx * cmPerPixel;
    final hipWidthCm = hipWidthPx * cmPerPixel;
    final chestCm = shoulderWidthCm * 1.2;
    final waistCm = hipWidthCm * 0.9;
    final hipCm = hipWidthCm;

    final bodyRatio = waistCm <= 0 ? 1.0 : chestCm / waistCm;
    final bodyType = _bodyTypeFromRatio(bodyRatio);
    final shoulderAdjustment = ((shoulderWidthCm - 42) * 0.14).clamp(-2.4, 2.4);
    final chestAdjustment = ((chestCm - 96) * 0.18).clamp(-3.5, 3.5);
    final waistAdjustment = ((waistCm - 84) * 0.16).clamp(-3.5, 3.5);
    final hipAdjustment = ((hipCm - 94) * 0.16).clamp(-3.8, 3.8);
    final confidenceBoost = isSideView ? 0.12 : 0.07;

    return PoseRefinementResult(
      chestAdjustment: chestAdjustment,
      waistAdjustment: waistAdjustment,
      hipAdjustment: hipAdjustment,
      shoulderAdjustment: shoulderAdjustment,
      confidenceBoost: confidenceBoost,
      highlights: [
        if (isSideView)
          'Side scan improved waist depth estimation'
        else
          'Front scan mapped shoulders, chest, waist, hips, and knees',
        'Measurement conversion uses: chest ≈ shoulder × scale × 1.2, waist ≈ hips × scale × 0.9',
        'Images are processed on-device and only measurements are stored',
      ],
      accuracyLabel: isSideView ? 'High' : 'Medium',
      detectedBodyType: bodyType.$1,
      bodyTypeConfidence: bodyType.$2,
      shoulderWidthCm: shoulderWidthCm,
      chestCm: chestCm,
      waistCm: waistCm,
      hipCm: hipCm,
      bodyRatio: bodyRatio,
      usedSideScan: isSideView,
      confidencePercent: isSideView ? 86 : 78,
    );
  }

  static (String, double) _bodyTypeFromRatio(double ratio) {
    if (ratio > 1.2) {
      return ('Athletic', 0.92);
    }
    if (ratio < 0.9) {
      return ('Heavy', 0.88);
    }
    return ('Regular', 0.82);
  }

  List<List<NormalizedLandmarkPoint>> _skeletonSegments({
    required PoseLandmark leftShoulder,
    required PoseLandmark rightShoulder,
    required PoseLandmark leftHip,
    required PoseLandmark rightHip,
    required PoseLandmark leftKnee,
    required PoseLandmark rightKnee,
    required PoseLandmark leftAnkle,
    required PoseLandmark rightAnkle,
    required PoseLandmark nose,
  }) {
    final points = <List<PoseLandmark>>[
      [leftShoulder, rightShoulder],
      [leftShoulder, leftHip],
      [rightShoulder, rightHip],
      [leftHip, rightHip],
      [leftHip, leftKnee],
      [rightHip, rightKnee],
      [leftKnee, leftAnkle],
      [rightKnee, rightAnkle],
      [nose, leftShoulder],
      [nose, rightShoulder],
    ];
    return points
        .map(
          (segment) => segment
              .map((point) => NormalizedLandmarkPoint(point.x, point.y))
              .toList(),
        )
        .toList();
  }

  double _distance(double x1, double y1, double x2, double y2) {
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
  }

  PoseLandmark _midPoint(PoseLandmark a, PoseLandmark b) {
    return PoseLandmark(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      visibility: (a.visibility + b.visibility) / 2,
    );
  }
}

class Pose {
  const Pose(this.landmarks);

  final Map<PoseLandmarkType, PoseLandmark> landmarks;
}

class PoseLandmark {
  const PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  final double x;
  final double y;
  final double z;
  final double visibility;
}

enum PoseLandmarkType {
  nose('nose'),
  leftShoulder('left_shoulder'),
  rightShoulder('right_shoulder'),
  leftHip('left_hip'),
  rightHip('right_hip'),
  leftKnee('left_knee'),
  rightKnee('right_knee'),
  leftAnkle('left_ankle'),
  rightAnkle('right_ankle');

  const PoseLandmarkType(this.wireName);
  final String wireName;

  static PoseLandmarkType? fromMediaPipeType(String type) {
    final normalized = type.trim().toLowerCase();
    for (final value in PoseLandmarkType.values) {
      if (value.wireName == normalized) {
        return value;
      }
    }
    return null;
  }
}
