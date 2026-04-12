import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/ar_try_on_models.dart';
import '../../models/models.dart';
import '../../models/outfit_recommendation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/ar_try_on_service.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/body_scan_service.dart';
import '../../services/camera_frame_encoder.dart';
import '../../services/mediapipe_pose_bridge.dart';
import '../../services/pose_measurement_service.dart';
import '../../services/real_time_ar_try_on_bridge.dart';
import '../../services/unity_try_on_bridge.dart';
import '../../theme.dart';
import '../../widgets/ar_native_try_on_view.dart';
import '../../widgets/state_views.dart';
import '../../widgets/unity_try_on_view.dart';

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
enum _ArRendererMode { auto, flutter, native, unity }

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
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _showCaptureFlash = false;
  bool _useFrontCamera = true;
  int _lastProcessedFrameMs = 0;
  int _poseFrameCounter = 0;
  String? _error;
  double _zoomLevel = 1;
  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  double _fitAdjustment = 0;
  double _sceneLuma = 0.5;
  String? _lastCapturePath;
  String? _selectedSizeOverride;
  bool _showOverlay = true;
  double _overlayEntryScale = 0.965;
  Product? _selectedProductOverride;
  final List<TryOnPoseFrame> _recentPoseFrames = <TryOnPoseFrame>[];
  _TryOnMode _mode = _TryOnMode.single;
  _ArRendererMode _rendererMode = _ArRendererMode.auto;
  ArTryOnProductMetadata? _nativeTryOnMetadata;
  bool _nativeRendererConfigured = false;
  ArTryOnProductMetadata? _unityTryOnMetadata;
  bool _unityRendererConfigured = false;
  String _tryOnSessionId = '';
  int _tryOnCaptureCount = 0;
  int _tryOnOutfitSwitchCount = 0;
  final List<ArTryOnFrameStat> _tryOnFrameStats = <ArTryOnFrameStat>[];

  @override
  void initState() {
    super.initState();
    _garment = _tryOnService.metadataFor(widget.product);
    _tryOnSessionId =
        'tryon_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}';
    _initializeCamera();
    Future.microtask(_loadIntelligence);
    Future.microtask(() => _configureNativeRenderer(widget.product));
    Future.microtask(() => _configureUnityRenderer(widget.product));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _overlayEntryScale = 1.0);
    });
  }

  @override
  void dispose() {
    unawaited(_persistTryOnSession());
    unawaited(RealTimeArTryOnBridge.instance.dispose());
    unawaited(UnityTryOnBridge.instance.dispose());
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
      });
      _refreshFitSummary();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _refreshFitSummary();
    }
  }

  Future<void> _configureNativeRenderer(Product product) async {
    if (_rendererMode == _ArRendererMode.flutter ||
        _rendererMode == _ArRendererMode.unity) {
      return;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final metadata = await _backendCommerceService.getTryOnProductMetadata(
        product.id,
      );
      if (!mounted) {
        return;
      }
      await RealTimeArTryOnBridge.instance.initialize(
        metadata: metadata,
        preferBackCamera: !_useFrontCamera,
        enableOcclusion: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeTryOnMetadata = metadata;
        _nativeRendererConfigured = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeTryOnMetadata = null;
        _nativeRendererConfigured = false;
      });
    }
  }

  Future<void> _configureUnityRenderer(Product product) async {
    if (_rendererMode == _ArRendererMode.flutter ||
        _rendererMode == _ArRendererMode.native) {
      return;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final metadata = await _backendCommerceService.getTryOnProductMetadata(
        product.id,
      );
      if (!mounted) {
        return;
      }
      final summary = _fitSummary;
      await UnityTryOnBridge.instance.initialize(
        metadata: metadata,
        measurements: {
          if (_savedBodyProfile?.heightCm != null)
            'heightCm': _savedBodyProfile!.heightCm,
          if (summary != null) 'shoulderCm': summary.shoulderCm,
          if (summary != null) 'chestCm': summary.chestCm,
          if (summary != null) 'waistCm': summary.waistCm,
          if (summary != null) 'hipCm': summary.hipCm,
        },
        enableAvatar: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _unityTryOnMetadata = metadata;
        _unityRendererConfigured = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _unityTryOnMetadata = null;
        _unityRendererConfigured = false;
      });
    }
  }

  Future<void> _switchNativeGarment(Product product) async {
    if (_rendererMode == _ArRendererMode.flutter ||
        _rendererMode == _ArRendererMode.unity) {
      return;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final metadata = await _backendCommerceService.getTryOnProductMetadata(
        product.id,
      );
      await RealTimeArTryOnBridge.instance.updateGarment(metadata);
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeTryOnMetadata = metadata;
        _nativeRendererConfigured = true;
      });
    } catch (_) {
      // Keep Flutter overlay active even if native renderer update fails.
    }
  }

  Future<void> _switchUnityGarment(Product product) async {
    if (_rendererMode == _ArRendererMode.flutter ||
        _rendererMode == _ArRendererMode.native) {
      return;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final metadata = await _backendCommerceService.getTryOnProductMetadata(
        product.id,
      );
      await UnityTryOnBridge.instance.loadGarment(metadata);
      if (!mounted) {
        return;
      }
      setState(() {
        _unityTryOnMetadata = metadata;
        _unityRendererConfigured = true;
      });
    } catch (_) {
      // Keep fallback renderers active if Unity garment load fails.
    }
  }

  Map<String, dynamic> _tryOnFrameToMap(TryOnPoseFrame frame) {
    Map<String, double> point(NormalizedLandmarkPoint value) => {
      'x': value.x,
      'y': value.y,
    };

    return {
      'leftShoulder': point(frame.leftShoulder),
      'rightShoulder': point(frame.rightShoulder),
      'leftHip': point(frame.leftHip),
      'rightHip': point(frame.rightHip),
      'shoulderCenter': point(frame.shoulderCenter),
      'hipCenter': point(frame.hipCenter),
      'rotationRadians': frame.rotationRadians,
      'shoulderWidth': frame.shoulderWidth,
      'torsoHeight': frame.torsoHeight,
    };
  }

  Future<void> _pushPoseToNative(TryOnPoseFrame? frame) async {
    final canvas = _previewCanvasSize;
    if (!_shouldUseNativeRenderer ||
        !_nativeRendererConfigured ||
        _nativeTryOnMetadata == null ||
        canvas == null) {
      return;
    }
    final poseConfidence = frame == null
        ? 0.0
        : (frame.feedback.progress.clamp(0.0, 1.0) * 0.6) +
            (frame.feedback.isAligned ? 0.35 : 0.1);
    _tryOnFrameStats.add(
      ArTryOnFrameStat(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        fps: 30,
        poseConfidence: poseConfidence.clamp(0.0, 1.0),
        bodyVisible: frame != null,
        lightingScore: _sceneLuma,
      ),
    );
    if (_tryOnFrameStats.length > 90) {
      _tryOnFrameStats.removeAt(0);
    }
    try {
      await RealTimeArTryOnBridge.instance.updatePoseFrame(
        poseFrame: frame == null ? const {} : _tryOnFrameToMap(frame),
        viewportSize: canvas,
        bodyDetected: frame != null,
        lightingScore: _sceneLuma,
      );
    } catch (_) {
      // Native renderer is optional. Keep Flutter overlay responsive.
    }
  }

  Future<void> _pushPoseToUnity(TryOnPoseFrame? frame) async {
    if (!_shouldUseUnityRenderer ||
        !_unityRendererConfigured ||
        _unityTryOnMetadata == null ||
        frame == null) {
      return;
    }
    try {
      await UnityTryOnBridge.instance.updatePose(_tryOnFrameToMap(frame));
    } catch (_) {
      // Unity mode is optional and should never block tracking.
    }
  }

  Future<void> _persistTryOnSession() async {
    if (!_backendCommerceService.isConfigured || _tryOnFrameStats.isEmpty) {
      return;
    }
    final summary = _fitSummary;
    final avgFps = _tryOnFrameStats.fold<double>(
          0,
          (sum, item) => sum + item.fps,
        ) /
        _tryOnFrameStats.length;
    final avgPoseConfidence = _tryOnFrameStats.fold<double>(
          0,
          (sum, item) => sum + item.poseConfidence,
        ) /
        _tryOnFrameStats.length;
    final peakFps = _tryOnFrameStats.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.fps),
    );
    final payload = ArTryOnSessionPayload(
      productId: (_selectedProductOverride ?? widget.product).id,
      sessionId: _tryOnSessionId,
      platform: RealTimeArTryOnBridge.instance.platformLabel,
      deviceModel: Platform.operatingSystemVersion,
      cameraFacing: _useFrontCamera ? 'front' : 'back',
      mode: _mode == _TryOnMode.outfit ? 'outfit' : 'live_overlay',
      captureCount: _tryOnCaptureCount,
      outfitSwitchCount: _tryOnOutfitSwitchCount,
      averageFps: avgFps,
      peakFps: peakFps,
      averagePoseConfidence: avgPoseConfidence,
      bodyProfileSnapshot: {
        if (_savedBodyProfile?.heightCm != null) 'heightCm': _savedBodyProfile!.heightCm,
        if (_savedBodyProfile?.weightKg != null) 'weightKg': _savedBodyProfile!.weightKg,
      },
      measurements: {
        if (summary != null) 'shoulderCm': summary.shoulderCm,
        if (summary != null) 'chestCm': summary.chestCm,
        if (summary != null) 'waistCm': summary.waistCm,
        if (summary != null) 'hipCm': summary.hipCm,
      },
      renderStats: {
        'renderer': _nativeRendererConfigured
            ? 'native_hybrid'
            : 'flutter_hybrid',
        'occlusionEnabled':
            (_trackingFrame?.feedback.isAligned ?? false) &&
            (_trackingFrame?.shoulderWidth ?? 0) > 0.08,
        'physicsEnabled': false,
        'frameSkipCount': _poseFrameCounter ~/ 2,
      },
      events: List<ArTryOnFrameStat>.from(_tryOnFrameStats),
      previewImageUrl: _lastCapturePath ?? '',
    );
    try {
      await _backendCommerceService.saveTryOnSession(payload);
    } catch (_) {
      // Session analytics should never block the UI teardown path.
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
      confidencePercent: frame != null ? 90 : (profile != null ? 74 : 56),
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
    if (_selectedProductOverride != null) {
      return _tryOnService.metadataFor(_selectedProductOverride!);
    }
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
      final sampledLuma = _estimateSceneLuma(image);
      _sceneLuma = ((_sceneLuma * 0.82) + (sampledLuma * 0.18)).clamp(0.0, 1.0);
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
      final smoothedFrame = _smoothTryOnFrame(nextFrame);
      if (!mounted) {
        return;
      }

      final canvas = _previewCanvasSize;
      final nextLayout = canvas == null
          ? _overlayLayout
          : _tryOnService.buildLayout(
              canvasSize: canvas,
              guideRect: _guideRectFor(canvas),
              frame: smoothedFrame,
              metadata: _garmentForMode,
              fitAdjustment: _effectiveFitAdjustment(),
              previous: _overlayLayout,
            );

      final wasAligned = _trackingFrame?.feedback.isAligned ?? false;
      setState(() {
        _trackingFrame = smoothedFrame;
        _overlayLayout = nextLayout;
        _fitSummary = _buildFitSummary(
          frame: smoothedFrame,
          profile: _savedBodyProfile,
          selectedSizeOverride: _selectedSizeOverride,
        );
        _selectedSizeOverride ??= _fitSummary?.wearingSize;
      });
      final isAligned = smoothedFrame?.feedback.isAligned ?? false;
      if (!wasAligned && isAligned) {
        HapticFeedback.selectionClick();
      }
      unawaited(_pushPoseToNative(smoothedFrame));
      unawaited(_pushPoseToUnity(smoothedFrame));
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
    await HapticFeedback.selectionClick();
    try {
      await RealTimeArTryOnBridge.instance.setCameraFacing(
        front: !_useFrontCamera,
      );
    } catch (_) {}
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
    if (_shouldUseUnityRenderer) {
      await _captureUnityPreview();
      return;
    }
    if (_shouldUseNativeRenderer) {
      await _captureNativePreview();
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      await controller.stopImageStream();
      final file = await controller.takePicture();
      await _triggerCaptureFlash();
      final watermarkedPath = await _applyCaptureWatermark(file.path);
      await _persistCapture(watermarkedPath);
      await _syncBodyProfileFromFitSummary();
      _tryOnCaptureCount += 1;
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _lastCapturePath = watermarkedPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Try-on capture saved with ABZORA mark.')),
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

  Future<void> _captureNativePreview() async {
    if (_isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final nativePath = await RealTimeArTryOnBridge.instance.capturePreview();
      await _triggerCaptureFlash();
      if (nativePath == null || nativePath.trim().isEmpty) {
        throw StateError('Native AR preview capture is unavailable.');
      }
      await _persistCapture(nativePath);
      await _syncBodyProfileFromFitSummary();
      _tryOnCaptureCount += 1;
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _lastCapturePath = nativePath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Native AR capture saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Native capture failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _captureUnityPreview() async {
    if (_isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final unityPath = await UnityTryOnBridge.instance.capture();
      await _triggerCaptureFlash();
      if (unityPath == null || unityPath.trim().isEmpty) {
        throw StateError('Unity capture is unavailable.');
      }
      await _persistCapture(unityPath);
      await _syncBodyProfileFromFitSummary();
      _tryOnCaptureCount += 1;
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _lastCapturePath = unityPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unity premium capture saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unity capture failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _triggerCaptureFlash() async {
    if (!mounted) {
      return;
    }
    setState(() => _showCaptureFlash = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) {
      return;
    }
    setState(() => _showCaptureFlash = false);
  }

  Future<void> _persistCapture(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_profileCaptureKey) ?? <String>[];
    final next = <String>[path, ...existing.where((item) => item != path)];
    await prefs.setStringList(_profileCaptureKey, next.take(12).toList());
  }

  Future<String> _applyCaptureWatermark(String sourcePath) async {
    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        return sourcePath;
      }

      final width = decoded.width;
      final height = decoded.height;
      final badgeWidth = (width * 0.24).round().clamp(90, 220);
      final badgeHeight = (height * 0.048).round().clamp(24, 52);
      final pad = (width * 0.03).round().clamp(10, 28);
      final x1 = width - badgeWidth - pad;
      final y1 = height - badgeHeight - pad;
      final x2 = x1 + badgeWidth;
      final y2 = y1 + badgeHeight;

      img.fillRect(
        decoded,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: img.ColorRgba8(16, 16, 16, 150),
      );
      img.drawRect(
        decoded,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: img.ColorRgba8(232, 199, 107, 215),
      );

      final emblemCenterX = x1 + (badgeHeight ~/ 2) + 5;
      final emblemCenterY = y1 + (badgeHeight ~/ 2);
      img.fillCircle(
        decoded,
        x: emblemCenterX,
        y: emblemCenterY,
        radius: (badgeHeight * 0.28).round().clamp(6, 12),
        color: img.ColorRgba8(232, 199, 107, 230),
      );
      img.drawLine(
        decoded,
        x1: emblemCenterX - 3,
        y1: emblemCenterY + 4,
        x2: emblemCenterX,
        y2: emblemCenterY - 5,
        color: img.ColorRgba8(25, 25, 25, 255),
      );
      img.drawLine(
        decoded,
        x1: emblemCenterX + 3,
        y1: emblemCenterY + 4,
        x2: emblemCenterX,
        y2: emblemCenterY - 5,
        color: img.ColorRgba8(25, 25, 25, 255),
      );

      final encoded = img.encodeJpg(decoded, quality: 92);
      if (encoded.isEmpty) {
        return sourcePath;
      }
      await File(sourcePath).writeAsBytes(encoded, flush: true);
      return sourcePath;
    } catch (_) {
      return sourcePath;
    }
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
    await HapticFeedback.selectionClick();
    if (!mounted) {
      return;
    }
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

  bool get _shouldUseNativeRenderer {
    return switch (_rendererMode) {
      _ArRendererMode.flutter => false,
      _ArRendererMode.unity => false,
      _ArRendererMode.native => _nativeTryOnMetadata != null,
      _ArRendererMode.auto => _nativeTryOnMetadata != null,
    };
  }

  bool get _shouldUseUnityRenderer {
    return switch (_rendererMode) {
      _ArRendererMode.unity => _unityTryOnMetadata != null,
      _ArRendererMode.auto =>
        _unityTryOnMetadata != null &&
        _unityTryOnMetadata!.unityAssetBundleUrl.trim().isNotEmpty,
      _ArRendererMode.flutter => false,
      _ArRendererMode.native => false,
    };
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
      if (_overlayLayout != null) {
        return 'Adjust position';
      }
      return 'Adjust position';
    }
    if (feedback.isAligned) {
      return 'Aligned';
    }
    return 'Adjust position';
  }

  String? _lightingHintText() {
    final feedback = _trackingFrame?.feedback;
    if (feedback == null) {
      return null;
    }
    final hint = (feedback.alignmentHint ?? feedback.message).toLowerCase();
    if (hint.contains('lighting') || hint.contains('light')) {
      return 'Improve lighting';
    }
    return null;
  }

  TryOnPoseFrame? _smoothTryOnFrame(TryOnPoseFrame? frame) {
    if (frame == null) {
      _recentPoseFrames.clear();
      return null;
    }
    _recentPoseFrames.add(frame);
    if (_recentPoseFrames.length > 6) {
      _recentPoseFrames.removeAt(0);
    }
    if (_recentPoseFrames.length < 3) {
      return frame;
    }

    final widths = _recentPoseFrames.map((item) => item.shoulderWidth).toList()
      ..sort();
    final medianWidth = widths[widths.length ~/ 2];
    final filtered = _recentPoseFrames
        .where(
          (item) =>
              (item.shoulderWidth - medianWidth).abs() <= (medianWidth * 0.28),
        )
        .toList();
    final source = filtered.isEmpty ? _recentPoseFrames : filtered;
    double avg(double Function(TryOnPoseFrame item) pick) =>
        source.map(pick).reduce((a, b) => a + b) / source.length;

    NormalizedLandmarkPoint avgPoint(
      NormalizedLandmarkPoint Function(TryOnPoseFrame item) pick,
    ) {
      final x = avg((item) => pick(item).x);
      final y = avg((item) => pick(item).y);
      return NormalizedLandmarkPoint(x, y);
    }

    return TryOnPoseFrame(
      feedback: frame.feedback,
      leftShoulder: avgPoint((item) => item.leftShoulder),
      rightShoulder: avgPoint((item) => item.rightShoulder),
      leftHip: avgPoint((item) => item.leftHip),
      rightHip: avgPoint((item) => item.rightHip),
      shoulderCenter: avgPoint((item) => item.shoulderCenter),
      hipCenter: avgPoint((item) => item.hipCenter),
      shoulderWidth: avg((item) => item.shoulderWidth),
      torsoHeight: avg((item) => item.torsoHeight),
      rotationRadians: avg((item) => item.rotationRadians),
    );
  }

  double _estimateSceneLuma(CameraImage image) {
    if (image.planes.isEmpty || image.planes.first.bytes.isEmpty) {
      return 0.5;
    }
    final yBytes = image.planes.first.bytes;
    final step = (yBytes.length ~/ 720).clamp(24, 320);
    var sum = 0;
    var count = 0;
    for (var i = 0; i < yBytes.length; i += step) {
      sum += yBytes[i];
      count++;
    }
    if (count == 0) {
      return 0.5;
    }
    return (sum / count) / 255.0;
  }

  List<Product> _availableTryOnProducts() {
    final byId = <String, Product>{widget.product.id: widget.product};
    for (final outfit in _outfits) {
      for (final item in outfit.items) {
        byId.putIfAbsent(item.id, () => item);
      }
    }
    return byId.values.toList();
  }

  Future<void> _openProductPicker() async {
    await HapticFeedback.selectionClick();
    if (!mounted) {
      return;
    }
    final products = _availableTryOnProducts();
    if (products.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<Product>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Change product',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: products.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final selectedProduct =
                            _selectedProductOverride ?? widget.product;
                        final isSelected = selectedProduct.id == product.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(product),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AbzioTheme.accentColor
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: product.images.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: product.images.first,
                                            fit: BoxFit.cover,
                                          )
                                        : const ColoredBox(
                                            color: Colors.white10,
                                            child: Icon(
                                              Icons.checkroom_rounded,
                                              color: Colors.white54,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AbzioTheme.accentColor,
                                    size: 18,
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
      },
    );

    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedProductOverride = selected.id == widget.product.id
          ? null
          : selected;
      _mode = _TryOnMode.single;
      _overlayLayout = null;
    });
    _tryOnOutfitSwitchCount += 1;
    unawaited(_switchNativeGarment(selected));
    unawaited(_switchUnityGarment(selected));
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
                    final lightingHint = _lightingHintText();
                    final activeOutfit = _selectedOutfit;
                    final activePrimaryProduct =
                        _selectedProductOverride ??
                        (_mode == _TryOnMode.outfit && activeOutfit != null
                            ? (_primaryOutfitItem(activeOutfit) ??
                                  widget.product)
                            : widget.product);
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
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 130),
                              opacity: _showCaptureFlash ? 0.26 : 0,
                              child: const ColoredBox(color: Colors.white),
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
                        if (_showOverlay && _shouldUseUnityRenderer)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: UnityTryOnView(
                                metadata: _unityTryOnMetadata!,
                                measurements: {
                                  if (_savedBodyProfile?.heightCm != null)
                                    'heightCm': _savedBodyProfile!.heightCm,
                                  if (fitSummary != null)
                                    'shoulderCm': fitSummary.shoulderCm,
                                  if (fitSummary != null)
                                    'chestCm': fitSummary.chestCm,
                                  if (fitSummary != null)
                                    'waistCm': fitSummary.waistCm,
                                  if (fitSummary != null)
                                    'hipCm': fitSummary.hipCm,
                                },
                              ),
                            ),
                          ),
                        if (_showOverlay &&
                            !_shouldUseUnityRenderer &&
                            _shouldUseNativeRenderer)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ArNativeTryOnView(
                                metadata: _nativeTryOnMetadata!,
                              ),
                            ),
                          ),
                        if (_showOverlay &&
                            !_shouldUseUnityRenderer &&
                            !_shouldUseNativeRenderer)
                          _GarmentOverlay(
                            product: activePrimaryProduct,
                            metadata: activePrimaryMetadata,
                            layout: overlayLayout,
                            accentColor: widget.accentColor,
                            sceneLuma: _sceneLuma,
                            entryScale: _overlayEntryScale,
                            occlusionEnabled:
                                (_trackingFrame?.feedback.isAligned ?? false) &&
                                (_trackingFrame?.shoulderWidth ?? 0) > 0.08,
                          ),
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: _TopControls(
                            onBack: () => Navigator.pop(context),
                            title: activePrimaryProduct.name,
                            fitSummary: fitSummary == null
                                ? null
                                : 'Wearing Size ${fitSummary.wearingSize} · ${fitSummary.fitConfidence}% fit',
                          ),
                        ),
                        if (lightingHint != null)
                          Positioned(
                            top: 86,
                            left: 16,
                            child: _GuidanceChip(
                              icon: Icons.wb_incandescent_rounded,
                              label: lightingHint,
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
                            rendererMode: _rendererMode,
                            nativeRendererAvailable: _nativeTryOnMetadata != null,
                            unityRendererAvailable: _unityTryOnMetadata != null,
                            fitAdjustment: _fitAdjustment,
                            zoomLevel: _zoomLevel,
                            minZoomLevel: _minZoomLevel,
                            maxZoomLevel: _maxZoomLevel,
                            isCapturing: _isCapturing,
                            onZoomChanged: _setZoom,
                            onCapture: _capturePhoto,
                            onShare: _shareLastCapture,
                            canSwitchCamera: _cameras.length > 1,
                            onSwitchCamera: _switchCamera,
                            onChangeProduct: _openProductPicker,
                            onRendererModeChanged: (mode) async {
                              HapticFeedback.selectionClick();
                              setState(() => _rendererMode = mode);
                              if (mode == _ArRendererMode.unity ||
                                  mode == _ArRendererMode.auto) {
                                await _configureUnityRenderer(
                                  _selectedProductOverride ?? widget.product,
                                );
                              }
                              if (mode != _ArRendererMode.flutter &&
                                  mode != _ArRendererMode.unity) {
                                await _configureNativeRenderer(
                                  _selectedProductOverride ?? widget.product,
                                );
                              }
                            },
                            showOverlay: _showOverlay,
                            onToggleBeforeAfter: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                final next = !_showOverlay;
                                _showOverlay = next;
                                if (next) {
                                  _overlayEntryScale = 0.965;
                                }
                              });
                              if (_showOverlay) {
                                Future<void>.delayed(
                                  const Duration(milliseconds: 16),
                                  () {
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(() => _overlayEntryScale = 1.0);
                                  },
                                );
                              }
                            },
                            onSelectSize: (size) {
                              HapticFeedback.selectionClick();
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
                              HapticFeedback.selectionClick();
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
    required this.title,
    this.fitSummary,
  });

  final VoidCallback onBack;
  final String title;
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
                      'AR Try-On',
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
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.productSizes,
    required this.fitSummary,
    required this.statusText,
    required this.rendererMode,
    required this.nativeRendererAvailable,
    required this.unityRendererAvailable,
    required this.fitAdjustment,
    required this.zoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.isCapturing,
    required this.onZoomChanged,
    required this.onCapture,
    required this.onShare,
    required this.canSwitchCamera,
    required this.onSwitchCamera,
    required this.onChangeProduct,
    required this.onRendererModeChanged,
    required this.showOverlay,
    required this.onToggleBeforeAfter,
    required this.onSelectSize,
    required this.onFitChanged,
  });

  final List<String> productSizes;
  final _ArFitSummary? fitSummary;
  final String statusText;
  final _ArRendererMode rendererMode;
  final bool nativeRendererAvailable;
  final bool unityRendererAvailable;
  final double fitAdjustment;
  final double zoomLevel;
  final double minZoomLevel;
  final double maxZoomLevel;
  final bool isCapturing;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final VoidCallback onShare;
  final bool canSwitchCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onChangeProduct;
  final ValueChanged<_ArRendererMode> onRendererModeChanged;
  final bool showOverlay;
  final VoidCallback onToggleBeforeAfter;
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Text(
                  statusText,
                  key: ValueKey<String>(statusText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _ArRendererMode.values)
                    ChoiceChip(
                      label: Text(
                        switch (option) {
                          _ArRendererMode.auto => 'Auto',
                          _ArRendererMode.flutter => 'Flutter',
                          _ArRendererMode.native => 'Native',
                          _ArRendererMode.unity => 'Unity',
                        },
                      ),
                      selected: rendererMode == option,
                      onSelected: ((option == _ArRendererMode.native &&
                                  !nativeRendererAvailable) ||
                              (option == _ArRendererMode.unity &&
                                  !unityRendererAvailable))
                          ? null
                          : (_) => onRendererModeChanged(option),
                      selectedColor: AbzioTheme.accentColor,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      disabledColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(
                        color: rendererMode == option
                            ? Colors.black
                            : (((option == _ArRendererMode.native &&
                                            !nativeRendererAvailable) ||
                                        (option == _ArRendererMode.unity &&
                                            !unityRendererAvailable)))
                                ? Colors.white38
                                : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
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
                  if (canSwitchCamera)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSwitchCamera,
                        icon: const Icon(Icons.flip_camera_android_rounded),
                        label: const Text('Switch'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  if (canSwitchCamera) const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      scale: isCapturing ? 0.98 : 1,
                      child: ElevatedButton.icon(
                        onPressed: isCapturing ? null : onCapture,
                        icon: isCapturing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt_rounded),
                        label: Text(isCapturing ? 'Capturing' : 'Capture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AbzioTheme.accentColor,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(42),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChangeProduct,
                      icon: const Icon(Icons.checkroom_rounded),
                      label: const Text('Product'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onToggleBeforeAfter,
                      icon: Icon(
                        showOverlay
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      label: Text(showOverlay ? 'Before' : 'After'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
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
    required this.sceneLuma,
    required this.entryScale,
    this.occlusionEnabled = false,
  });

  final Product product;
  final ArGarmentMetadata metadata;
  final ArOverlayLayout layout;
  final Color accentColor;
  final double sceneLuma;
  final double entryScale;
  final bool occlusionEnabled;

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
    final exposureDelta = ((sceneLuma - 0.5) * 0.24).clamp(-0.1, 0.1);
    final brightnessShift = 255 * exposureDelta;
    final colorMatchedGarment = ColorFiltered(
      colorFilter: ColorFilter.matrix([
        1, 0, 0, 0, brightnessShift,
        0, 1, 0, 0, brightnessShift,
        0, 0, 1, 0, brightnessShift,
        0, 0, 0, 1, 0,
      ]),
      child: garmentChild,
    );

    return Positioned(
      left: layout.center.dx - (layout.size.width / 2),
      top: layout.center.dy - (layout.size.height / 2),
      child: IgnorePointer(
        child: Transform.rotate(
          angle: layout.rotationRadians,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            scale: entryScale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
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
                            color: Colors.black.withValues(alpha: 0.16),
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: 0.16,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 1.0,
                                sigmaY: 1.0,
                              ),
                              child: colorMatchedGarment,
                            ),
                          ),
                          if (occlusionEnabled &&
                              _supportsFakeOcclusion(metadata.type))
                            CustomPaint(
                              foregroundPainter:
                                  const _ArmOcclusionCutoutPainter(),
                              child: colorMatchedGarment,
                            )
                          else
                            colorMatchedGarment,
                        ],
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
      ),
    );
  }

  bool _supportsFakeOcclusion(ArGarmentType type) {
    return type == ArGarmentType.shirt ||
        type == ArGarmentType.top ||
        type == ArGarmentType.jacket ||
        type == ArGarmentType.dress;
  }
}

class _ArmOcclusionCutoutPainter extends CustomPainter {
  const _ArmOcclusionCutoutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.black
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        size.shortestSide * 0.022,
      );

    final leftArm = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.02,
            size.height * 0.12,
            size.width * 0.26,
            size.height * 0.42,
          ),
          Radius.circular(size.width * 0.16),
        ),
      );
    final rightArm = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.72,
            size.height * 0.12,
            size.width * 0.26,
            size.height * 0.42,
          ),
          Radius.circular(size.width * 0.16),
        ),
      );
    final torsoCut = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.34,
            size.height * 0.06,
            size.width * 0.32,
            size.height * 0.12,
          ),
          Radius.circular(size.width * 0.1),
        ),
      );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(leftArm, maskPaint);
    canvas.drawPath(rightArm, maskPaint);
    canvas.drawPath(torsoCut, maskPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArmOcclusionCutoutPainter oldDelegate) => false;
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

class _GuidanceChip extends StatelessWidget {
  const _GuidanceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AbzioTheme.accentColor, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
