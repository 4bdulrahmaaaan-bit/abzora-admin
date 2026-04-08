import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../services/pose_measurement_service.dart';
import '../../theme.dart';

class LiveBodyScanCapture {
  const LiveBodyScanCapture({
    required this.imagePath,
    this.poseRefinement,
  });

  final String imagePath;
  final PoseRefinementResult? poseRefinement;
}

class LiveBodyScanCameraScreen extends StatefulWidget {
  const LiveBodyScanCameraScreen({
    super.key,
    required this.title,
    required this.heightCm,
    required this.isFrontView,
  });

  final String title;
  final double heightCm;
  final bool isFrontView;

  @override
  State<LiveBodyScanCameraScreen> createState() =>
      _LiveBodyScanCameraScreenState();
}

class _LiveBodyScanCameraScreenState extends State<LiveBodyScanCameraScreen>
    with SingleTickerProviderStateMixin {
  final PoseMeasurementService _poseService = const PoseMeasurementService();

  CameraController? _controller;
  bool _isLoading = true;
  bool _isCapturing = false;
  bool _isProcessingFrame = false;
  String? _error;
  PoseFrameFeedback? _poseFeedback;
  final List<PoseRefinementResult> _recentRefinements = <PoseRefinementResult>[];
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No cameras available on this device.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
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
        _controller = controller;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing) {
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    _isProcessingFrame = true;
    try {
      final inputImage = _inputImageFromCameraImage(image, controller);
      if (inputImage == null) {
        return;
      }
      final feedback = await _poseService.analyzeLiveInputImage(
        inputImage,
        heightCm: widget.heightCm,
        isSideView: !widget.isFrontView,
      );
      final refinement = await _poseService.analyzeLiveRefinementInputImage(
        inputImage,
        heightCm: widget.heightCm,
        isSideView: !widget.isFrontView,
      );
      if (!mounted) {
        return;
      }
      final wasAligned = _poseFeedback?.isAligned ?? false;
      if (refinement != null) {
        _recentRefinements.add(refinement);
        if (_recentRefinements.length > 10) {
          _recentRefinements.removeAt(0);
        }
      }
      setState(() {
        _poseFeedback = feedback;
      });
      if (!wasAligned && feedback.isAligned) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Frame-level errors should not block the live preview.
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      await controller.stopImageStream();
      final file = await controller.takePicture();
      final fileRefinement = await _poseService.analyzeFromFile(
        file.path,
        heightCm: widget.heightCm,
        isSideView: !widget.isFrontView,
      );
      final smoothedRefinement = PoseRefinementResult.average(
        _recentRefinements.length > 5
            ? _recentRefinements.sublist(_recentRefinements.length - 5)
            : _recentRefinements,
      );
      final refinement = PoseRefinementResult.merge(
        fileRefinement,
        smoothedRefinement,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      Navigator.pop(
        context,
        LiveBodyScanCapture(
          imagePath: file.path,
          poseRefinement: refinement,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCapturing = false;
        _error = error.toString();
      });
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
    final feedback = _poseFeedback;
    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AbzioTheme.accentColor,
                  ),
                )
              : _error != null
                  ? _errorView()
                  : AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => Stack(
                        children: [
                          Positioned.fill(
                            child: _controller == null
                                ? const SizedBox.shrink()
                                : CameraPreview(_controller!),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _BodySilhouettePainter(
                                  pulse: _pulseController.value,
                                  feedback: feedback,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.62),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                  stops: const [0.0, 0.32, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 16,
                            right: 16,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        feedback?.message ??
                                            'Detecting your pose in real time',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 144,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.46),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(
                                                feedback?.state,
                                              ).withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _statusLabel(feedback?.state),
                                              style: TextStyle(
                                                color: _statusColor(
                                                  feedback?.state,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            widget.isFrontView
                                                ? 'Front scan'
                                                : 'Side scan',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.76,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        feedback?.alignmentHint ??
                                            'Align shoulders inside frame',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Samples: ${_recentRefinements.length}/10',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: _isCapturing
                                              ? null
                                              : (feedback?.progress ?? 0.24),
                                          minHeight: 8,
                                          backgroundColor:
                                              Colors.white.withValues(alpha: 0.1),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            _statusColor(feedback?.state),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _CameraHintChip(
                                            label: widget.isFrontView
                                                ? 'Shoulders level'
                                                : 'Side profile visible',
                                          ),
                                          const _CameraHintChip(
                                            label: 'Full body visible',
                                          ),
                                          _CameraHintChip(
                                            label: feedback?.isAligned == true
                                                ? 'Perfect alignment'
                                                : 'Adjust pose',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 106,
                            child: Text(
                              'Your images are never stored. Only measurements are محفوظ.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (_isCapturing)
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 30,
                            child: Column(
                              children: [
                                if (_isCapturing)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Processing your scan...',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: 180,
                                          child: LinearProgressIndicator(
                                            minHeight: 6,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            backgroundColor:
                                                Colors.white.withValues(
                                              alpha: 0.14,
                                            ),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(AbzioTheme.accentColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: _isCapturing ? null : _capture,
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha:
                                              0.8 + (_pulseController.value * 0.2),
                                        ),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AbzioTheme.accentColor.withValues(
                                            alpha: 0.22 +
                                                (_pulseController.value * 0.12),
                                          ),
                                          blurRadius: 30,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 62,
                                        height: 62,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFE0BC4A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Color _statusColor(PoseGuideState? state) {
    switch (state) {
      case PoseGuideState.aligned:
        return const Color(0xFF54D18F);
      case PoseGuideState.adjust:
        return AbzioTheme.accentColor;
      case PoseGuideState.detecting:
      case null:
        return Colors.white;
    }
  }

  String _statusLabel(PoseGuideState? state) {
    switch (state) {
      case PoseGuideState.aligned:
        return 'Perfect alignment';
      case PoseGuideState.adjust:
        return 'Adjust position';
      case PoseGuideState.detecting:
      case null:
        return 'Detecting';
    }
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 38),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Camera could not start.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodySilhouettePainter extends CustomPainter {
  const _BodySilhouettePainter({
    required this.pulse,
    required this.feedback,
  });

  final double pulse;
  final PoseFrameFeedback? feedback;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final guidePaint = Paint()
      ..color = _guideColor().withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + (pulse * 1.2);

    final fillPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    final guideRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.48,
      height: size.height * 0.68,
    );
    final guide = RRect.fromRectAndRadius(
      guideRect,
      const Radius.circular(120),
    );

    final layerBounds = Offset.zero & size;
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(layerBounds, overlayPaint);
    canvas.drawRRect(guide, fillPaint);
    canvas.restore();
    canvas.drawRRect(guide, guidePaint);

    final segments = feedback?.skeletonSegments ?? const [];
    if (segments.isEmpty) {
      return;
    }

    final allPoints = segments.expand((segment) => segment).toList();
    final minX = allPoints.map((point) => point.x).reduce(math.min);
    final maxX = allPoints.map((point) => point.x).reduce(math.max);
    final minY = allPoints.map((point) => point.y).reduce(math.min);
    final maxY = allPoints.map((point) => point.y).reduce(math.max);
    final rangeX = math.max(1.0, maxX - minX);
    final rangeY = math.max(1.0, maxY - minY);

    final skeletonPaint = Paint()
      ..color = _guideColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()
      ..color = _guideColor()
      ..style = PaintingStyle.fill;

    Offset mapPoint(NormalizedLandmarkPoint point) {
      final dx = ((point.x - minX) / rangeX).clamp(0.0, 1.0);
      final dy = ((point.y - minY) / rangeY).clamp(0.0, 1.0);
      return Offset(
        guideRect.left + (guideRect.width * dx),
        guideRect.top + (guideRect.height * dy),
      );
    }

    for (final segment in segments) {
      if (segment.length < 2) {
        continue;
      }
      final first = mapPoint(segment.first);
      final second = mapPoint(segment.last);
      canvas.drawLine(first, second, skeletonPaint);
      canvas.drawCircle(first, 4.5, nodePaint);
      canvas.drawCircle(second, 4.5, nodePaint);
    }
  }

  Color _guideColor() {
    switch (feedback?.state) {
      case PoseGuideState.aligned:
        return const Color(0xFF54D18F);
      case PoseGuideState.adjust:
        return AbzioTheme.accentColor;
      case PoseGuideState.detecting:
      case null:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.feedback != feedback;
}

class _CameraHintChip extends StatelessWidget {
  const _CameraHintChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
