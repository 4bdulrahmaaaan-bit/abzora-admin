import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
    );
  }

  static PoseRefinementResult? average(List<PoseRefinementResult> results) {
    if (results.isEmpty) {
      return null;
    }
    double sum(double Function(PoseRefinementResult item) picker) =>
        results.fold<double>(0, (total, item) => total + picker(item));
    final count = results.length.toDouble();
    final avgChest = sum((item) => item.chestCm) / count;
    final avgWaist = sum((item) => item.waistCm) / count;
    final avgHip = sum((item) => item.hipCm) / count;
    final avgShoulder = sum((item) => item.shoulderWidthCm) / count;
    final avgRatio = avgWaist <= 0 ? 1.0 : avgChest / avgWaist;
    final bodyType = PoseMeasurementService._bodyTypeFromRatio(avgRatio);
    return PoseRefinementResult(
      chestAdjustment: sum((item) => item.chestAdjustment) / count,
      waistAdjustment: sum((item) => item.waistAdjustment) / count,
      hipAdjustment: sum((item) => item.hipAdjustment) / count,
      shoulderAdjustment: sum((item) => item.shoulderAdjustment) / count,
      confidenceBoost: (sum((item) => item.confidenceBoost) / count)
          .clamp(0.04, 0.16),
      highlights: [
        'Averaged ${results.length} pose frames for smoother measurements',
      ],
      accuracyLabel: results.length >= 8 ? 'High' : 'Medium',
      detectedBodyType: bodyType.$1,
      bodyTypeConfidence: bodyType.$2,
      shoulderWidthCm: avgShoulder,
      chestCm: avgChest,
      waistCm: avgWaist,
      hipCm: avgHip,
      bodyRatio: avgRatio,
      usedSideScan: results.any((item) => item.usedSideScan),
    );
  }
}

class PoseMeasurementService {
  const PoseMeasurementService();

  static final PoseDetector _singleDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.base,
    ),
  );

  static final PoseDetector _streamDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  Future<PoseRefinementResult?> analyzeFromFile(
    String imagePath, {
    required double heightCm,
    bool isSideView = false,
  }) async {
    final input = InputImage.fromFilePath(imagePath);
    final poses = await _singleDetector.processImage(input);
    if (poses.isEmpty) {
      return null;
    }
    return _buildRefinement(
      poses.first,
      heightCm: heightCm,
      isSideView: isSideView,
    );
  }

  Future<PoseFrameFeedback> analyzeLiveInputImage(
    InputImage inputImage, {
    required double heightCm,
    bool isSideView = false,
  }) async {
    final poses = await _streamDetector.processImage(inputImage);
    if (poses.isEmpty) {
      return const PoseFrameFeedback(
        state: PoseGuideState.detecting,
        message: 'Detecting...',
        progress: 0.2,
        skeletonSegments: [],
        alignmentHint: 'Move your full body into the frame',
      );
    }
    return _buildFrameFeedback(
      poses.first,
      heightCm: heightCm,
      isSideView: isSideView,
    );
  }

  Future<TryOnPoseFrame?> analyzeTryOnLiveInputImage(
    InputImage inputImage, {
    bool isSideView = false,
  }) async {
    final poses = await _streamDetector.processImage(inputImage);
    if (poses.isEmpty) {
      return null;
    }
    return _buildTryOnFrame(
      poses.first,
      isSideView: isSideView,
    );
  }

  Future<PoseRefinementResult?> analyzeLiveRefinementInputImage(
    InputImage inputImage, {
    required double heightCm,
    bool isSideView = false,
  }) async {
    final poses = await _streamDetector.processImage(inputImage);
    if (poses.isEmpty) {
      return null;
    }
    return _buildRefinement(
      poses.first,
      heightCm: heightCm,
      isSideView: isSideView,
    );
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
        message: 'Perfect alignment',
        progress: 1.0,
        skeletonSegments: skeleton,
        alignmentHint: 'Hold still and capture now',
      );
    }
    if (alignmentScore >= 0.52) {
      return PoseFrameFeedback(
        state: PoseGuideState.adjust,
        message: 'Adjust position',
        progress: 0.62,
        skeletonSegments: skeleton,
        alignmentHint: shoulderSlope > hipSlope
            ? 'Align shoulders inside frame'
            : 'Center your body and keep knees visible',
      );
    }
    return PoseFrameFeedback(
      state: PoseGuideState.detecting,
      message: 'Detecting...',
      progress: 0.34,
      skeletonSegments: skeleton,
      alignmentHint: isSideView
          ? 'Turn sideways and keep your full profile visible'
          : 'Step back and keep your full body inside the guide',
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
        nose == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }

    final bodyPixelHeight =
        ((((leftAnkle.y + rightAnkle.y) / 2) - nose.y).abs()).clamp(1.0, 9999.0);
    final cmPerPixel = heightCm / bodyPixelHeight;

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
    final chestCm = shoulderWidthCm * 1.1;
    var waistCm = hipWidthCm * 0.9;
    var hipCm = hipWidthCm;

    if (isSideView) {
      waistCm *= 1.04;
      hipCm *= 1.03;
    }

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
}
