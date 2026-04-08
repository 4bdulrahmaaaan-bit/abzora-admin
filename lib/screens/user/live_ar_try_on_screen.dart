import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../models/outfit_recommendation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/ar_try_on_service.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/body_scan_service.dart';
import '../../services/camera_frame_encoder.dart';
import '../../services/mediapipe_pose_bridge.dart';
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

enum _TryOnMode { single, outfit }

class _ArFitSummary {
  const _ArFitSummary({
    required this.recommendedSize,
    required this.wearingSize,
    required this.fitConfidence,
    required this.fitType,
    required this.bodyType,
    required this.sourceLabel,
    required this.shoulderCm,
    required this.chestCm,
    required this.waistCm,
    required this.hipCm,
  });

  final String recommendedSize;
  final String wearingSize;
  final int fitConfidence;
  final String fitType;
  final String bodyType;
  final String sourceLabel;
  final double shoulderCm;
  final double chestCm;
  final double waistCm;
  final double hipCm;
}

class _LiveArTryOnScreenState extends State<LiveArTryOnScreen> {
  static const _profileCaptureKey = 'abzora_try_on_captures';

  final PoseMeasurementService _poseService = const PoseMeasurementService();
  final ArTryOnService _tryOnService = const ArTryOnService();
  final BodyScanService _bodyScanService = const BodyScanService();
  final BackendCommerceService _backendCommerceService = BackendCommerceService();

  late final ArGarmentMetadata _garment;
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  Size? _previewCanvasSize;
  TryOnPoseFrame? _trackingFrame;
  ArOverlayLayout? _overlayLayout;
  BodyProfile? _savedBodyProfile;
  _ArFitSummary? _fitSummary;
  List<OutfitRecommendation> _outfits = const [];
  OutfitRecommendation? _selectedOutfit;
  bool _isLoading = true;
  bool _isLoadingIntelligence = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _useFrontCamera = true;
  int _lastProcessedFrameMs = 0;
  int _poseFrameCounter = 0;
  String? _error;
  double _zoomLevel = 1;
  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  double _fitAdjustment = 0;
  String? _lastCapturePath;
  String? _selectedSizeOverride;
  _TryOnMode _mode = _TryOnMode.single;

  @override
  void initState() {
    super.initState();
    _garment = _tryOnService.metadataFor(widget.product);
    _initializeCamera();
    Future.microtask(_loadIntelligence);
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

  Future<void> _loadIntelligence() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;
      BodyProfile? profile;
      if (_backendCommerceService.isConfigured) {
        try {
          profile = await _backendCommerceService.getBodyProfile();
        } catch (_) {
          profile = null;
        }
      }

      List<OutfitRecommendation> outfits = const [];
      if (_backendCommerceService.isConfigured) {
        try {
          outfits = await _backendCommerceService.getOutfits(
            productId: widget.product.id,
            userId: userId,
            limit: 6,
            authenticated: userId != null && userId.isNotEmpty,
          );
        } catch (_) {
          outfits = const [];
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _savedBodyProfile = profile;
        _outfits = outfits;
        _selectedOutfit = outfits.isNotEmpty ? outfits.first : null;
        _isLoadingIntelligence = false;
      });
      _refreshFitSummary();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingIntelligence = false);
      _refreshFitSummary();
    }
  }

  void _refreshFitSummary() {
    final summary = _buildFitSummary(
      frame: _trackingFrame,
      profile: _savedBodyProfile,
      selectedSizeOverride: _selectedSizeOverride,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _fitSummary = summary;
      _selectedSizeOverride ??= summary.wearingSize;
      if (_previewCanvasSize != null) {
        _overlayLayout = _tryOnService.buildLayout(
          canvasSize: _previewCanvasSize!,
          guideRect: _guideRectFor(_previewCanvasSize!),
          frame: _trackingFrame,
          metadata: _garmentForMode,
          fitAdjustment: _effectiveFitAdjustment(summary: summary),
          previous: _overlayLayout,
        );
      }
    });
  }

  _ArFitSummary _buildFitSummary({
    required TryOnPoseFrame? frame,
    required BodyProfile? profile,
    required String? selectedSizeOverride,
  }) {
    final heightCm = (profile?.heightCm ?? 170).clamp(145.0, 205.0);
    final liveMetrics = _liveMeasurementMetrics(frame, profile, heightCm);
    final bodyType = _bodyTypeFromRatio(
      liveMetrics.chestCm / math.max(1, liveMetrics.waistCm),
    );
    final weightKg = (profile?.weightKg ?? _estimatedWeightKg(heightCm, bodyType.$1))
        .clamp(42.0, 120.0);
    final refinement = PoseRefinementResult(
      chestAdjustment: 0,
      waistAdjustment: 0,
      hipAdjustment: 0,
      shoulderAdjustment: 0,
      confidenceBoost: frame != null ? 0.16 : 0.02,
      highlights: <String>[
        if (frame != null)
          'Live AR pose tracking is refining your fit in real time'
        else
          'Using saved body profile until live tracking locks on',
      ],
      accuracyLabel: frame != null ? 'High' : (profile != null ? 'Medium' : 'Low'),
      detectedBodyType: bodyType.$1,
      bodyTypeConfidence: bodyType.$2,
      shoulderWidthCm: liveMetrics.shoulderCm,
      chestCm: liveMetrics.chestCm,
      waistCm: liveMetrics.waistCm,
      hipCm: liveMetrics.hipCm,
      bodyRatio: liveMetrics.chestCm / math.max(1, liveMetrics.waistCm),
      usedSideScan: false,
    );
    final result = _bodyScanService.analyze(
      BodyScanInput(
        heightCm: heightCm,
        weightKg: weightKg,
        bodyFrame: bodyType.$1.toLowerCase(),
      ),
      poseRefinement: refinement,
      productFit: _garment.fit,
    );
    final recommended = _bodyScanService.chooseBestProductSize(
      widget.product,
      result,
    );
    final wearing = selectedSizeOverride ??
        (widget.product.sizes.contains(recommended)
            ? recommended
            : (widget.product.sizes.isNotEmpty ? widget.product.sizes.first : recommended));
    final confidence = ((result.confidence * 100) + (frame != null ? 6 : 0))
        .round()
        .clamp(68, 98);
    return _ArFitSummary(
      recommendedSize: recommended,
      wearingSize: wearing,
      fitConfidence: confidence,
      fitType: result.fit.toLowerCase(),
      bodyType: bodyType.$1,
      sourceLabel: frame != null
          ? 'AR live measurements'
          : profile != null
              ? 'Saved body profile'
              : 'Manual estimation',
      shoulderCm: result.shoulderCm,
      chestCm: result.chestCm,
      waistCm: result.waistCm,
      hipCm: result.hipCm,
    );
  }

  ({double shoulderCm, double chestCm, double waistCm, double hipCm}) _liveMeasurementMetrics(
    TryOnPoseFrame? frame,
    BodyProfile? profile,
    double heightCm,
  ) {
    final baseShoulder = profile?.shoulderCm ?? (heightCm * 0.245);
    final baseChest = profile?.chestCm ?? (heightCm * 0.53);
    final baseWaist = profile?.waistCm ?? (heightCm * 0.42);
    final baseHip = profile?.hipCm ?? (baseWaist + 8);
    if (frame == null) {
      return (
        shoulderCm: baseShoulder,
        chestCm: baseChest,
        waistCm: baseWaist,
        hipCm: baseHip,
      );
    }

    final hipWidth = math.sqrt(
      math.pow(frame.leftHip.x - frame.rightHip.x, 2) +
          math.pow(frame.leftHip.y - frame.rightHip.y, 2),
    );
    final shoulderSignal = (frame.shoulderWidth / 0.34).clamp(0.82, 1.18);
    final hipSignal = (hipWidth / 0.28).clamp(0.82, 1.18);
    final torsoSignal = (frame.torsoHeight / 0.37).clamp(0.86, 1.16);

    return (
      shoulderCm: baseShoulder * shoulderSignal,
      chestCm: baseChest * ((shoulderSignal * 0.72) + (torsoSignal * 0.28)),
      waistCm: baseWaist * ((hipSignal * 0.64) + (torsoSignal * 0.36)),
      hipCm: baseHip * hipSignal,
    );
  }

  (String, double) _bodyTypeFromRatio(double ratio) {
    if (ratio > 1.18) {
      return ('Athletic', 0.91);
    }
    if (ratio < 0.96) {
      return ('Heavy', 0.84);
    }
    return ('Regular', 0.88);
  }

  double _estimatedWeightKg(double heightCm, String bodyType) {
    final base = heightCm - 103;
    return switch (bodyType.toLowerCase()) {
      'athletic' => base * 0.95,
      'heavy' => base * 1.04,
      _ => base * 0.89,
    };
  }

  ArGarmentMetadata get _garmentForMode {
    if (_mode != _TryOnMode.outfit || _selectedOutfit == null) {
      return _garment;
    }
    final top = _primaryOutfitItem(_selectedOutfit!);
    return _tryOnService.metadataFor(top ?? widget.product);
  }

  double _effectiveFitAdjustment({_ArFitSummary? summary}) {
    final reference = summary ?? _fitSummary;
    final selected = _selectedSizeOverride;
    if (reference == null || selected == null) {
      return _fitAdjustment;
    }
    const order = <String>['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    final recommendedIndex = order.indexOf(reference.recommendedSize.toUpperCase());
    final selectedIndex = order.indexOf(selected.toUpperCase());
    final delta = recommendedIndex < 0 || selectedIndex < 0
        ? 0
        : (selectedIndex - recommendedIndex);
    return (_fitAdjustment + (delta * 0.055)).clamp(-0.22, 0.28);
  }

  Product? _primaryOutfitItem(OutfitRecommendation outfit) {
    for (final item in outfit.items) {
      final type = _tryOnService.metadataFor(item).type;
      if (type == ArGarmentType.shirt ||
          type == ArGarmentType.top ||
          type == ArGarmentType.jacket ||
          type == ArGarmentType.dress) {
        return item;
      }
    }
    return outfit.items.isNotEmpty ? outfit.items.first : null;
  }

  List<Product> _secondaryOutfitItems(OutfitRecommendation outfit) {
    final primary = _primaryOutfitItem(outfit);
    return outfit.items
        .where((item) => item.id != primary?.id)
        .take(2)
        .toList();
  }

  List<Widget> _buildSecondaryOutfitOverlays({
    required OutfitRecommendation outfit,
    required Rect guideRect,
    required Size canvasSize,
  }) {
    if (_trackingFrame == null) {
      return const [];
    }
    return _secondaryOutfitItems(outfit).map((item) {
      final metadata = _tryOnService.metadataFor(item);
      final layout = _tryOnService.buildLayout(
        canvasSize: canvasSize,
        guideRect: guideRect,
        frame: _trackingFrame,
        metadata: metadata,
        fitAdjustment: _effectiveFitAdjustment(),
      );
      return _GarmentOverlay(
        product: item,
        metadata: metadata,
        layout: layout,
        accentColor: widget.accentColor,
      );
    }).toList();
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Keep processing close to 30fps for smoother overlay without overloading.
    if (nowMs - _lastProcessedFrameMs < 33) {
      return;
    }
    _lastProcessedFrameMs = nowMs;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _isProcessingFrame = true;
    try {
      _poseFrameCounter += 1;
      if (_poseFrameCounter % 2 != 0) {
        return;
      }
      final jpeg = CameraFrameEncoder.encodeJpeg(image);
      if (jpeg == null) {
        return;
      }
      final inputFrame = MediaPipePoseFrameInput(
        jpegBytes: jpeg,
        width: image.width,
        height: image.height,
        rotation: controller.description.sensorOrientation,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      final nextFrame = await _poseService.analyzeTryOnLiveInputImage(
        inputFrame,
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
              metadata: _garmentForMode,
              fitAdjustment: _effectiveFitAdjustment(),
              previous: _overlayLayout,
            );

      final wasAligned = _trackingFrame?.feedback.isAligned ?? false;
      setState(() {
        _trackingFrame = nextFrame;
        _overlayLayout = nextLayout;
        _fitSummary = _buildFitSummary(
          frame: nextFrame,
          profile: _savedBodyProfile,
          selectedSizeOverride: _selectedSizeOverride,
        );
        _selectedSizeOverride ??= _fitSummary?.wearingSize;
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
      await _syncBodyProfileFromFitSummary();
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

  Future<void> _syncBodyProfileFromFitSummary() async {
    final summary = _fitSummary;
    if (summary == null || !_backendCommerceService.isConfigured) {
      return;
    }
    final base = _savedBodyProfile;
    final profile = BodyProfile(
      heightCm: base?.heightCm ?? 170,
      weightKg: base?.weightKg ?? _estimatedWeightKg(base?.heightCm ?? 170, summary.bodyType),
      bodyType: summary.bodyType.toLowerCase(),
      recommendedSize: summary.recommendedSize,
      pantSize: base?.pantSize ?? '',
      shoulderCm: summary.shoulderCm,
      chestCm: summary.chestCm,
      waistCm: summary.waistCm,
      hipCm: summary.hipCm,
      confidence: summary.fitConfidence / 100,
      updatedAt: DateTime.now().toIso8601String(),
    );
    try {
      final saved = await _backendCommerceService.saveBodyProfile(profile);
      if (!mounted) {
        return;
      }
      setState(() => _savedBodyProfile = saved);
    } catch (_) {
      // Best-effort sync only.
    }
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
                    final fitSummary = _fitSummary;
                    final activeOutfit = _selectedOutfit;
                    final activePrimaryProduct =
                        _mode == _TryOnMode.outfit && activeOutfit != null
                        ? (_primaryOutfitItem(activeOutfit) ?? widget.product)
                        : widget.product;
                    final activePrimaryMetadata = _tryOnService.metadataFor(
                      activePrimaryProduct,
                    );
                    _previewCanvasSize = canvasSize;
                    final guideRect = _guideRectFor(canvasSize);
                    final overlayLayout =
                        _overlayLayout ??
                        _tryOnService.buildLayout(
                          canvasSize: canvasSize,
                          guideRect: guideRect,
                          frame: _trackingFrame,
                          metadata: activePrimaryMetadata,
                          fitAdjustment: _effectiveFitAdjustment(
                            summary: fitSummary,
                          ),
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
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.045),
                                  ),
                                ),
                              ),
                            ),
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
                          product: activePrimaryProduct,
                          metadata: activePrimaryMetadata,
                          layout: overlayLayout,
                          accentColor: widget.accentColor,
                        ),
                        if (_mode == _TryOnMode.outfit && activeOutfit != null)
                          ..._buildSecondaryOutfitOverlays(
                            outfit: activeOutfit,
                            guideRect: guideRect,
                            canvasSize: canvasSize,
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
                            fitSummary: fitSummary == null
                                ? null
                                : 'Wearing Size ${fitSummary.wearingSize} · ${fitSummary.fitConfidence}% fit',
                          ),
                        ),
                        if (_outfits.isNotEmpty || _isLoadingIntelligence)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 246,
                            child: _SmartOutfitRail(
                              isLoading: _isLoadingIntelligence,
                              mode: _mode,
                              outfits: _outfits,
                              selectedOutfitId: _selectedOutfit?.outfitId,
                              onModeChanged: (mode) {
                                setState(() {
                                  _mode = mode;
                                  _overlayLayout = _tryOnService.buildLayout(
                                    canvasSize: canvasSize,
                                    guideRect: guideRect,
                                    frame: _trackingFrame,
                                    metadata: _garmentForMode,
                                    fitAdjustment: _effectiveFitAdjustment(
                                      summary: fitSummary,
                                    ),
                                    previous: _overlayLayout,
                                  );
                                });
                              },
                              onSelectOutfit: (outfit) {
                                setState(() {
                                  _selectedOutfit = outfit;
                                  _mode = _TryOnMode.outfit;
                                  _overlayLayout = _tryOnService.buildLayout(
                                    canvasSize: canvasSize,
                                    guideRect: guideRect,
                                    frame: _trackingFrame,
                                    metadata: _garmentForMode,
                                    fitAdjustment: _effectiveFitAdjustment(
                                      summary: fitSummary,
                                    ),
                                    previous: _overlayLayout,
                                  );
                                });
                              },
                            ),
                          ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: _BottomControls(
                            productSizes: widget.product.sizes,
                            fitSummary: fitSummary,
                            statusText: _statusText(),
                            fitAdjustment: _fitAdjustment,
                            zoomLevel: _zoomLevel,
                            minZoomLevel: _minZoomLevel,
                            maxZoomLevel: _maxZoomLevel,
                            isCapturing: _isCapturing,
                            onZoomChanged: _setZoom,
                            onCapture: _capturePhoto,
                            onShare: _shareLastCapture,
                            onSelectSize: (size) {
                              setState(() {
                                _selectedSizeOverride = size;
                                _fitSummary = _buildFitSummary(
                                  frame: _trackingFrame,
                                  profile: _savedBodyProfile,
                                  selectedSizeOverride: size,
                                );
                                _overlayLayout = _tryOnService.buildLayout(
                                  canvasSize: canvasSize,
                                  guideRect: guideRect,
                                  frame: _trackingFrame,
                                  metadata: _garmentForMode,
                                  fitAdjustment: _effectiveFitAdjustment(
                                    summary: _fitSummary,
                                  ),
                                  previous: _overlayLayout,
                                );
                              });
                            },
                            onFitChanged: (value) {
                              setState(() {
                                _fitAdjustment = value;
                                _fitSummary = _buildFitSummary(
                                  frame: _trackingFrame,
                                  profile: _savedBodyProfile,
                                  selectedSizeOverride: _selectedSizeOverride,
                                );
                                if (_previewCanvasSize != null) {
                                  _overlayLayout = _tryOnService.buildLayout(
                                    canvasSize: _previewCanvasSize!,
                                    guideRect: _guideRectFor(_previewCanvasSize!),
                                    frame: _trackingFrame,
                                    metadata: _garmentForMode,
                                    fitAdjustment: _effectiveFitAdjustment(),
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
    this.fitSummary,
  });

  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onSwitchCamera;
  final bool canSwitchCamera;
  final String title;
  final String subtitle;
  final String? fitSummary;

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
                    if (fitSummary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        fitSummary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AbzioTheme.accentColor.withValues(alpha: 0.96),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _SmartOutfitRail extends StatelessWidget {
  const _SmartOutfitRail({
    required this.isLoading,
    required this.mode,
    required this.outfits,
    required this.selectedOutfitId,
    required this.onModeChanged,
    required this.onSelectOutfit,
  });

  final bool isLoading;
  final _TryOnMode mode;
  final List<OutfitRecommendation> outfits;
  final String? selectedOutfitId;
  final ValueChanged<_TryOnMode> onModeChanged;
  final ValueChanged<OutfitRecommendation> onSelectOutfit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ModeChip(
                    label: 'Single Item',
                    selected: mode == _TryOnMode.single,
                    onTap: () => onModeChanged(_TryOnMode.single),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    label: 'Full Outfit',
                    selected: mode == _TryOnMode.outfit,
                    onTap: () => onModeChanged(_TryOnMode.outfit),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'AI outfit suggestions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (isLoading)
                const SizedBox(
                  height: 92,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AbzioTheme.accentColor,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: outfits.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final outfit = outfits[index];
                      final selected = outfit.outfitId == selectedOutfitId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onSelectOutfit(outfit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 188,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? AbzioTheme.accentColor
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              ...outfit.items.take(3).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 40,
                                      height: 64,
                                      child: item.images.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: item.images.first,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.white12,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.checkroom_rounded,
                                                color: Colors.white54,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      outfit.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Try Full Look',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AbzioTheme.accentColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AbzioTheme.accentColor
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.productSizes,
    required this.fitSummary,
    required this.statusText,
    required this.fitAdjustment,
    required this.zoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.isCapturing,
    required this.onZoomChanged,
    required this.onCapture,
    required this.onShare,
    required this.onSelectSize,
    required this.onFitChanged,
  });

  final List<String> productSizes;
  final _ArFitSummary? fitSummary;
  final String statusText;
  final double fitAdjustment;
  final double zoomLevel;
  final double minZoomLevel;
  final double maxZoomLevel;
  final bool isCapturing;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final VoidCallback onShare;
  final ValueChanged<String> onSelectSize;
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
              if (fitSummary != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wearing Size ${fitSummary!.wearingSize}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fit Confidence: ${fitSummary!.fitConfidence}% · ${fitSummary!.fitType}',
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Source',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            fitSummary!.sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: productSizes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final size = productSizes[index];
                      final selected = fitSummary!.wearingSize.toUpperCase() ==
                          size.toUpperCase();
                      return ChoiceChip(
                        label: Text(size),
                        selected: selected,
                        onSelected: (_) => onSelectSize(size),
                        selectedColor: AbzioTheme.accentColor,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
    final garmentChild = layout.usingFallbackArt
        ? CustomPaint(
            painter: _FallbackGarmentPainter(
              accentColor: accentColor,
              type: metadata.type,
            ),
          )
        : CachedNetworkImage(
            imageUrl: metadata.assetUrl,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            fadeInDuration: const Duration(milliseconds: 100),
            placeholder: (context, imageUrl) => CustomPaint(
              painter: _FallbackGarmentPainter(
                accentColor: accentColor,
                type: metadata.type,
              ),
            ),
            errorWidget: (context, imageUrl, error) => CustomPaint(
              painter: _FallbackGarmentPainter(
                accentColor: accentColor,
                type: metadata.type,
              ),
            ),
          );

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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: layout.size.width * 0.08,
                    right: layout.size.width * 0.08,
                    bottom: -layout.size.height * 0.05,
                    height: layout.size.height * 0.16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.26),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (bounds) => RadialGradient(
                        center: const Alignment(0, -0.08),
                        radius: 0.98,
                        colors: const [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.88, 1.0],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: garmentChild,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.06),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.11),
                          ],
                          stops: const [0.0, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FabricNoisePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FabricNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.018);
    for (double y = 2; y < size.height; y += 8) {
      for (double x = 2; x < size.width; x += 8) {
        final seed = ((x * 13) + (y * 17)) % 29;
        if (seed < 8) {
          canvas.drawCircle(Offset(x, y), 0.65, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FabricNoisePainter oldDelegate) => false;
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
              painter: _FallbackGarmentPainter(
                accentColor: accentColor,
                type: ArGarmentType.shirt,
              ),
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
  const _FallbackGarmentPainter({
    required this.accentColor,
    required this.type,
  });

  final Color accentColor;
  final ArGarmentType type;

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

    final path = switch (type) {
      ArGarmentType.pants => _pantsPath(size),
      ArGarmentType.footwear => _footwearPath(size),
      ArGarmentType.accessory => _accessoryPath(size),
      _ => _upperBodyPath(size),
    };

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
    return oldDelegate.accentColor != accentColor || oldDelegate.type != type;
  }

  Path _upperBodyPath(Size size) {
    return Path()
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
  }

  Path _pantsPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.28, size.height * 0.06)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.0,
        size.width * 0.72,
        size.height * 0.06,
      )
      ..lineTo(size.width * 0.8, size.height * 0.32)
      ..lineTo(size.width * 0.66, size.height * 0.96)
      ..lineTo(size.width * 0.54, size.height * 0.96)
      ..lineTo(size.width * 0.5, size.height * 0.52)
      ..lineTo(size.width * 0.46, size.height * 0.96)
      ..lineTo(size.width * 0.34, size.height * 0.96)
      ..lineTo(size.width * 0.2, size.height * 0.32)
      ..close();
  }

  Path _footwearPath(Size size) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.08,
            size.height * 0.38,
            size.width * 0.34,
            size.height * 0.22,
          ),
          const Radius.circular(24),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.58,
            size.height * 0.38,
            size.width * 0.34,
            size.height * 0.22,
          ),
          const Radius.circular(24),
        ),
      );
  }

  Path _accessoryPath(Size size) {
    return Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.48),
          width: size.width * 0.64,
          height: size.height * 0.52,
        ),
      );
  }
}
