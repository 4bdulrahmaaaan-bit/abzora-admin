import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseRefinementResult {
  const PoseRefinementResult({
    required this.chestAdjustment,
    required this.waistAdjustment,
    required this.hipAdjustment,
    required this.shoulderAdjustment,
    required this.confidenceBoost,
    required this.highlights,
  });

  final double chestAdjustment;
  final double waistAdjustment;
  final double hipAdjustment;
  final double shoulderAdjustment;
  final double confidenceBoost;
  final List<String> highlights;

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
    return PoseRefinementResult(
      chestAdjustment: (front.chestAdjustment + side.chestAdjustment) / 2,
      waistAdjustment: (front.waistAdjustment + side.waistAdjustment) / 2,
      hipAdjustment: (front.hipAdjustment + side.hipAdjustment) / 2,
      shoulderAdjustment:
          (front.shoulderAdjustment + side.shoulderAdjustment) / 2,
      confidenceBoost: math.max(front.confidenceBoost, side.confidenceBoost),
      highlights: [...front.highlights, ...side.highlights],
    );
  }
}

class PoseMeasurementService {
  const PoseMeasurementService();

  Future<PoseRefinementResult?> analyzeFromFile(String imagePath) async {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.base,
    );
    final detector = PoseDetector(options: options);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final poses = await detector.processImage(input);
      if (poses.isEmpty) {
        return null;
      }
      return _buildRefinement(poses.first);
    } finally {
      await detector.close();
    }
  }

  PoseRefinementResult? _buildRefinement(Pose pose) {
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
        (leftAnkle == null && rightAnkle == null)) {
      return null;
    }

    final ankle = leftAnkle ?? rightAnkle!;
    final heightPixels = (ankle.y - nose.y).abs();
    if (heightPixels <= 0) {
      return null;
    }

    final shoulderWidth = _distance(leftShoulder.x, leftShoulder.y,
        rightShoulder.x, rightShoulder.y);
    final hipWidth =
        _distance(leftHip.x, leftHip.y, rightHip.x, rightHip.y);
    final torsoHeight = ((leftHip.y + rightHip.y) / 2 - nose.y).abs();

    final shoulderRatio = shoulderWidth / heightPixels;
    final hipRatio = hipWidth / heightPixels;
    final torsoRatio = torsoHeight / heightPixels;

    final shoulderAdjustment = ((shoulderRatio - 0.19) * 22).clamp(-2.4, 2.4);
    final chestAdjustment = ((shoulderRatio - 0.19) * 30).clamp(-3.5, 3.5);
    final waistAdjustment = ((hipRatio - 0.16) * 28).clamp(-3.0, 3.0);
    final hipAdjustment = ((hipRatio - 0.17) * 30).clamp(-3.2, 3.2);
    final confidenceBoost = torsoRatio > 0.34 ? 0.06 : 0.03;

    return PoseRefinementResult(
      chestAdjustment: chestAdjustment,
      waistAdjustment: waistAdjustment,
      hipAdjustment: hipAdjustment,
      shoulderAdjustment: shoulderAdjustment,
      confidenceBoost: confidenceBoost,
      highlights: [
        'Pose landmarks refined shoulder balance from live camera capture',
        if (hipRatio > 0.17)
          'Body proportions suggested a slightly roomier waist and hip fit'
        else
          'Body proportions supported a cleaner, sharper silhouette',
      ],
    );
  }

  double _distance(double x1, double y1, double x2, double y2) {
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
  }
}
