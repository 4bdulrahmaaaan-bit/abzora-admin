import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
  });

  final String title;

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
  String? _error;
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
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
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

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      final refinement = await _poseService.analyzeFromFile(file.path);
      if (!mounted) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AbzioTheme.accentColor),
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
                                  Colors.black.withValues(alpha: 0.68),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      'Stand straight and align within frame',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
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
                                  color: Colors.black.withValues(alpha: 0.44),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: const Text(
                                  'Keep your full body inside the outline. Hold the phone at chest level and capture in good lighting for the best fit estimate.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: const [
                                  _CameraHintChip(label: 'Chest level'),
                                  _CameraHintChip(label: 'Full body visible'),
                                  _CameraHintChip(label: 'Stand straight'),
                                ],
                              ),
                            ],
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
                                        'Analyzing your body...',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Getting your perfect fit',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
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
                                        alpha: 0.8 + (_pulseController.value * 0.2),
                                      ),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AbzioTheme.accentColor.withValues(
                                          alpha: 0.22 + (_pulseController.value * 0.12),
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
  });

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final guidePaint = Paint()
      ..color = const Color(0xFFE0BC4A)
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
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) =>
      oldDelegate.pulse != pulse;
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
