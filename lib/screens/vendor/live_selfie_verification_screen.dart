import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../services/kyc_selfie_service.dart';

class LiveSelfieVerificationScreen extends StatefulWidget {
  const LiveSelfieVerificationScreen({super.key});

  @override
  State<LiveSelfieVerificationScreen> createState() =>
      _LiveSelfieVerificationScreenState();
}

class _LiveSelfieVerificationScreenState
    extends State<LiveSelfieVerificationScreen> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  CameraController? _cameraController;
  bool _initializing = true;
  bool _isProcessingFrame = false;
  bool _faceDetected = false;
  bool _livenessPassed = false;
  bool _eyesOpenSeen = false;
  bool _eyesClosedSeen = false;
  bool _headTurnSeen = false;
  int _retryCount = 0;
  String _instruction = 'Align your face inside the guide';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    unawaited(_cameraController?.dispose());
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.startImageStream(_processCameraImage);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _initializing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _instruction = 'Camera could not start. Please try again.';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _livenessPassed) {
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    _isProcessingFrame = true;
    try {
      final inputImage = _inputImageFromCameraImage(image, controller);
      if (inputImage == null) {
        return;
      }
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        return;
      }
      if (faces.isEmpty) {
        setState(() {
          _faceDetected = false;
          _instruction = 'Move closer and keep your face inside the guide';
        });
        return;
      }
      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 0;
      final rightEye = face.rightEyeOpenProbability ?? 0;
      final yaw = (face.headEulerAngleY ?? 0).abs();
      var nextInstruction = 'Blink once or turn your head slightly';
      var nextEyesOpenSeen = _eyesOpenSeen;
      var nextEyesClosedSeen = _eyesClosedSeen;
      var nextHeadTurnSeen = _headTurnSeen;
      var nextLivenessPassed = _livenessPassed;

      if (leftEye > 0.72 && rightEye > 0.72) {
        nextEyesOpenSeen = true;
      }
      if (nextEyesOpenSeen && leftEye < 0.35 && rightEye < 0.35) {
        nextEyesClosedSeen = true;
      }
      if (nextEyesOpenSeen && nextEyesClosedSeen && leftEye > 0.65 && rightEye > 0.65) {
        nextLivenessPassed = true;
        nextInstruction = 'Blink detected. You can capture now.';
      }
      if (yaw > 14) {
        nextHeadTurnSeen = true;
        nextLivenessPassed = true;
        nextInstruction = 'Head movement detected. You can capture now.';
      }

      setState(() {
        _faceDetected = true;
        _eyesOpenSeen = nextEyesOpenSeen;
        _eyesClosedSeen = nextEyesClosedSeen;
        _headTurnSeen = nextHeadTurnSeen;
        _livenessPassed = nextLivenessPassed;
        _instruction = nextInstruction;
      });
    } catch (_) {
      // Ignore frame-level errors to keep preview smooth.
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _capture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (!_livenessPassed) {
      setState(() {
        _retryCount += 1;
        _instruction = _retryCount >= 3
            ? 'Verification failed too many times. Please retry later.'
            : 'Complete the blink or head-turn check first.';
      });
      return;
    }
    try {
      await controller.stopImageStream();
      final file = await controller.takePicture();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        LiveSelfieCheckResult(
          imagePath: file.path,
          livenessPassed: true,
          livenessMode: _headTurnSeen ? 'head_turn' : 'blink',
          retryCount: _retryCount,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _retryCount += 1;
          _instruction = _retryCount >= 3
              ? 'Capture failed too many times. Please try again later.'
              : 'Capture failed. Keep still and try again.';
        });
      }
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    final camera = controller.description;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) {
      return null;
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }
    final bytes = _concatenatePlanes(image.planes);
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final writeBuffer = WriteBuffer();
    for (final plane in planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    return writeBuffer.done().buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Live Selfie Verification'),
      ),
      body: _initializing || controller == null || !controller.value.isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              children: [
                Positioned.fill(child: CameraPreview(controller)),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FaceGuidePainter(isReady: _livenessPassed),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.42),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Take a live selfie',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _instruction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _faceDetected
                                ? _livenessPassed
                                    ? 'Verified movement detected'
                                    : 'Blink or turn your head slightly'
                                : 'Center your face in the circle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Retries $_retryCount/3',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _livenessPassed
                                    ? const [Color(0xFFD9B14D), Color(0xFFB78716)]
                                    : const [Color(0xFF666666), Color(0xFF454545)],
                              ),
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: (_livenessPassed ? const Color(0xFFD9B14D) : Colors.black)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.isReady});

  final bool isReady;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.28);
    final rect = Offset.zero & size;
    final path = Path()..addRect(rect);
    final guideRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.58,
      height: size.width * 0.78,
    );
    path.addOval(guideRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final border = Paint()
      ..color = isReady ? const Color(0xFF2ECC71) : const Color(0xFFE0B84C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(guideRect, border);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) =>
      oldDelegate.isReady != isReady;
}
