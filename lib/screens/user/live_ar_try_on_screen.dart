import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../services/ar_try_on_service.dart';
import '../../services/pose_measurement_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class LiveArTryOnScreen extends StatefulWidget {
  const LiveArTryOnScreen({
    super.key,
    required this.product,
    required this.accentColor,
  });

  final Product product;
  final Color accentColor;

  @override
  State<LiveArTryOnScreen> createState() => _LiveArTryOnScreenState();
}

class _LiveArTryOnScreenState extends State<LiveArTryOnScreen> {
  static const _profileCaptureKey = 'abzora_try_on_captures';

  final PoseMeasurementService _poseService = const PoseMeasurementService();
  final ArTryOnService _tryOnService = const ArTryOnService();

  late final ArGarmentMetadata _garment;
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  Size? _previewCanvasSize;
  TryOnPoseFrame? _trackingFrame;
  ArOverlayLayout? _overlayLayout;
  bool _isLoading = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _useFrontCamera = true;
  String? _error;
  double _zoomLevel = 1;
  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  double _fitAdjustment = 0;
  String? _lastCapturePath;

  @override
  void initState() {
    super.initState();
    _garment = _tryOnService.metadataFor(widget.product);
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera({bool? useFrontCamera}) async {
    final desiredFront = useFrontCamera ?? _useFrontCamera;
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw StateError('No cameras available on this device.');
      }

      final selected = _selectCamera(_cameras, desiredFront);
      final previous = _controller;
      await previous?.dispose();

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      _minZoomLevel = await controller.getMinZoomLevel();
      _maxZoomLevel = math.min(await controller.getMaxZoomLevel(), 3.0);
      _zoomLevel = _minZoomLevel;
      await controller.setZoomLevel(_zoomLevel);
      await controller.startImageStream(_processCameraImage);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _useFrontCamera = desiredFront;
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

  CameraDescription _selectCamera(
    List<CameraDescription> cameras,
    bool useFront,
  ) {
    final preferredDirection = useFront
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    return cameras.firstWhere(
      (camera) => camera.lensDirection == preferredDirection,
      orElse: () => cameras.first,
    );
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

      final nextFrame = await _poseService.analyzeTryOnLiveInputImage(
        inputImage,
        isSideView: false,
      );
      if (!mounted) {
        return;
      }

      final canvas = _previewCanvasSize;
      final nextLayout = canvas == null
          ? _overlayLayout
          : _tryOnService.buildLayout(
              canvasSize: canvas,
              guideRect: _guideRectFor(canvas),
              frame: nextFrame,
              metadata: _garment,
              fitAdjustment: _fitAdjustment,
              previous: _overlayLayout,
            );

      final wasAligned = _trackingFrame?.feedback.isAligned ?? false;
      setState(() {
        _trackingFrame = nextFrame;
        _overlayLayout = nextLayout;
      });
      final isAligned = nextFrame?.feedback.isAligned ?? false;
      if (!wasAligned && isAligned) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Ignore frame-level errors to keep the preview responsive.
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isCapturing) {
      return;
    }
    await _initializeCamera(useFrontCamera: !_useFrontCamera);
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final clamped = value.clamp(_minZoomLevel, _maxZoomLevel);
    await controller.setZoomLevel(clamped);
    if (!mounted) {
      return;
    }
    setState(() => _zoomLevel = clamped);
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      await controller.stopImageStream();
      final file = await controller.takePicture();
      await _persistCapture(file.path);
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _lastCapturePath = file.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Try-on capture saved to your profile.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $error')));
    } finally {
      try {
        await controller.startImageStream(_processCameraImage);
      } catch (_) {
        // Ignore restart errors and let the user retry or fallback.
      }
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _persistCapture(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_profileCaptureKey) ?? <String>[];
    final next = <String>[path, ...existing.where((item) => item != path)];
    await prefs.setStringList(_profileCaptureKey, next.take(12).toList());
  }

  Future<void> _shareLastCapture() async {
    final path = _lastCapturePath;
    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a try-on photo before sharing.')),
      );
      return;
    }
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Trying on ${widget.product.name} with ABZORA AR.',
    );
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) {
      return null;
    }

    final writeBuffer = WriteBuffer();
    for (final plane in image.planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    final bytes = writeBuffer.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Rect _guideRectFor(Size size) {
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.48,
      height: size.height * 0.68,
    );
  }

  String _statusText() {
    if (_error != null) {
      return 'Using image try-on fallback';
    }
    final feedback = _trackingFrame?.feedback;
    if (feedback == null) {
      return 'Detecting shoulders and torso...';
    }
    if (feedback.isAligned) {
      return 'Perfect alignment';
    }
    return feedback.alignmentHint ?? feedback.message;
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AbzioTheme.accentColor,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _previewCanvasSize = canvasSize;
                    final guideRect = _guideRectFor(canvasSize);
                    final overlayLayout =
                        _overlayLayout ??
                        _tryOnService.buildLayout(
                          canvasSize: canvasSize,
                          guideRect: guideRect,
                          frame: _trackingFrame,
                          metadata: _garment,
                          fitAdjustment: _fitAdjustment,
                        );

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: _error == null && _controller != null
                              ? CameraPreview(_controller!)
                              : _FallbackTryOnPreview(
                                  product: widget.product,
                                  accentColor: widget.accentColor,
                                ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.54),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.64),
                                  ],
                                  stops: const [0, 0.38, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _TryOnGuidePainter(
                                guideRect: guideRect,
                                accentColor: widget.accentColor,
                                isAligned:
                                    _trackingFrame?.feedback.isAligned ?? false,
                              ),
                            ),
                          ),
                        ),
                        _GarmentOverlay(
                          product: widget.product,
                          metadata: _garment,
                          layout: overlayLayout,
                          accentColor: widget.accentColor,
                        ),
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: _TopControls(
                            onBack: () => Navigator.pop(context),
                            onShare: _shareLastCapture,
                            onSwitchCamera: _switchCamera,
                            canSwitchCamera: _cameras.length > 1,
                            title: 'Live AR Try-On',
                            subtitle: widget.product.name,
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: _BottomControls(
                            statusText: _statusText(),
                            fitAdjustment: _fitAdjustment,
                            zoomLevel: _zoomLevel,
                            minZoomLevel: _minZoomLevel,
                            maxZoomLevel: _maxZoomLevel,
                            isCapturing: _isCapturing,
                            onZoomChanged: _setZoom,
                            onCapture: _capturePhoto,
                            onShare: _shareLastCapture,
                            onFitChanged: (value) {
                              setState(() {
                                _fitAdjustment = value;
                                if (_previewCanvasSize != null) {
                                  _overlayLayout = _tryOnService.buildLayout(
                                    canvasSize: _previewCanvasSize!,
                                    guideRect: _guideRectFor(_previewCanvasSize!),
                                    frame: _trackingFrame,
                                    metadata: _garment,
                                    fitAdjustment: value,
                                    previous: _overlayLayout,
                                  );
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.onBack,
    required this.onShare,
    required this.onSwitchCamera,
    required this.canSwitchCamera,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onSwitchCamera;
  final bool canSwitchCamera;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (canSwitchCamera) ...[
          _GlassIconButton(
            icon: Icons.flip_camera_android_rounded,
            onTap: onSwitchCamera,
          ),
          const SizedBox(width: 8),
        ],
        _GlassIconButton(icon: Icons.share_outlined, onTap: onShare),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.statusText,
    required this.fitAdjustment,
    required this.zoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.isCapturing,
    required this.onZoomChanged,
    required this.onCapture,
    required this.onShare,
    required this.onFitChanged,
  });

  final String statusText;
  final double fitAdjustment;
  final double zoomLevel;
  final double minZoomLevel;
  final double maxZoomLevel;
  final bool isCapturing;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final VoidCallback onShare;
  final ValueChanged<double> onFitChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final option in const [
                    (-0.08, 'Tight'),
                    (0.0, 'Regular'),
                    (0.08, 'Loose'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option.$2),
                        selected: fitAdjustment == option.$1,
                        onSelected: (_) => onFitChanged(option.$1),
                        selectedColor: AbzioTheme.accentColor,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: fitAdjustment == option.$1
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.zoom_in_rounded, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: zoomLevel.clamp(minZoomLevel, maxZoomLevel),
                      min: minZoomLevel,
                      max: maxZoomLevel,
                      onChanged: onZoomChanged,
                    ),
                  ),
                  Text(
                    '${zoomLevel.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 58,
                    width: 58,
                    child: ElevatedButton(
                      onPressed: isCapturing ? null : onCapture,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: AbzioTheme.accentColor,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                      ),
                      child: isCapturing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.camera_alt_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GarmentOverlay extends StatelessWidget {
  const _GarmentOverlay({
    required this.product,
    required this.metadata,
    required this.layout,
    required this.accentColor,
  });

  final Product product;
  final ArGarmentMetadata metadata;
  final ArOverlayLayout layout;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: layout.center.dx - (layout.size.width / 2),
      top: layout.center.dy - (layout.size.height / 2),
      child: IgnorePointer(
        child: Transform.rotate(
          angle: layout.rotationRadians,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: layout.opacity,
            child: SizedBox(
              width: layout.size.width,
              height: layout.size.height,
              child: layout.usingFallbackArt
                  ? CustomPaint(
                      painter: _FallbackGarmentPainter(accentColor: accentColor),
                    )
                  : CachedNetworkImage(
                      imageUrl: metadata.assetUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, imageUrl) => CustomPaint(
                        painter: _FallbackGarmentPainter(
                          accentColor: accentColor,
                        ),
                      ),
                      errorWidget: (context, imageUrl, error) => CustomPaint(
                        painter: _FallbackGarmentPainter(
                          accentColor: accentColor,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackTryOnPreview extends StatelessWidget {
  const _FallbackTryOnPreview({
    required this.product,
    required this.accentColor,
  });

  final Product product;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (product.images.isNotEmpty)
          AbzioNetworkImage(
            imageUrl: product.images.first,
            fallbackLabel: product.name,
            fit: BoxFit.cover,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.34),
                Colors.black.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 220,
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: CustomPaint(
              painter: _FallbackGarmentPainter(accentColor: accentColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.16),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _TryOnGuidePainter extends CustomPainter {
  const _TryOnGuidePainter({
    required this.guideRect,
    required this.accentColor,
    required this.isAligned,
  });

  final Rect guideRect;
  final Color accentColor;
  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isAligned ? accentColor : Colors.white.withValues(alpha: 0.6);
    final paint = Paint()
      ..color = color.withValues(alpha: isAligned ? 0.38 : 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(28)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TryOnGuidePainter oldDelegate) {
    return oldDelegate.guideRect != guideRect ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isAligned != isAligned;
  }
}

class _FallbackGarmentPainter extends CustomPainter {
  const _FallbackGarmentPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.92),
          Color.alphaBlend(
            accentColor.withValues(alpha: 0.18),
            const Color(0xFF111111),
          ),
        ],
      ).createShader(rect);

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.14,
        size.width * 0.26,
        size.height * 0.14,
      )
      ..lineTo(size.width * 0.4, size.height * 0.1)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.04,
        size.width * 0.6,
        size.height * 0.1,
      )
      ..lineTo(size.width * 0.74, size.height * 0.14)
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.14,
        size.width * 0.82,
        size.height * 0.2,
      )
      ..lineTo(size.width * 0.72, size.height * 0.46)
      ..lineTo(size.width * 0.7, size.height * 0.9)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.98,
        size.width * 0.3,
        size.height * 0.9,
      )
      ..lineTo(size.width * 0.28, size.height * 0.46)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.32), 18, false);
    canvas.drawPath(path, fill);

    final seam = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.16),
      Offset(size.width * 0.5, size.height * 0.86),
      seam,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackGarmentPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
