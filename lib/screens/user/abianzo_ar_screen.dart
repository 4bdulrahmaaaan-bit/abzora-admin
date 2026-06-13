import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/ar_visual_tuning.dart';
import '../../models/ar_intelligence_models.dart';
import '../../models/ai_stylist_models.dart';
import '../../models/body_fit_intelligence_models.dart';
import '../../models/mediapipe_try_on_payload.dart';
import '../../models/ar_try_on_models.dart';
import '../../models/outfit_recommendation_model.dart';
import '../../services/mediapipe_ar_service.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/ar_quality_scaler.dart';
import '../../services/ai_stylist_engine.dart';
import '../../services/body_profile_engine.dart';
import '../../services/camera_frame_encoder.dart';
import '../../services/fit_confidence_engine.dart';
import '../../services/fit_analytics_service.dart';
import '../../services/garment_certification_service.dart';
import '../../services/garment_body_alignment_engine.dart';
import '../../services/garment_lod_validator.dart';
import '../../services/lightweight_garment_deformation_engine.dart';
import '../../services/lightweight_ar_compositing_engine.dart';
import '../../services/mediapipe_pose_bridge.dart';
import '../../services/ml_inference_router.dart';
import '../../services/motion_quality_evaluator.dart';
import '../../services/pose_measurement_service.dart';
import '../../services/pose_stabilization_engine.dart';
import '../../services/runtime_telemetry_engine.dart';
import '../../services/session_quality_score_engine.dart';
import '../../services/segmentation_occlusion_engine.dart';
import '../../services/thermal_performance_monitor.dart';
import '../../services/real_time_ar_try_on_bridge.dart';
import '../../services/tracking_analytics_service.dart';
import '../../services/tracking_reliability_engine.dart';
import 'widgets/ar_tryon_chrome_widgets.dart';

class AbianzoArScreen extends StatefulWidget {
  const AbianzoArScreen({
    super.key,
    required this.payload,
    this.onFitCalculated,
    this.onError,
  });

  final MediaPipeTryOnPayload payload;
  final ValueChanged<MediaPipeFitResult>? onFitCalculated;
  final ValueChanged<String>? onError;

  @override
  State<AbianzoArScreen> createState() => _AbianzoArScreenState();
}

class _AbianzoArScreenState extends State<AbianzoArScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const bool _useFlutterPosePipeline = true;
  static const bool _showDebugHud = kDebugMode;
  final MediaPipeArService _bridge = MediaPipeArService.instance;
  final RealTimeArTryOnBridge _nativeRenderer = RealTimeArTryOnBridge.instance;
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final PoseMeasurementService _poseMeasurementService =
      const PoseMeasurementService();
  final PoseStabilizationEngine _poseStabilizationEngine =
      PoseStabilizationEngine();
  final MotionQualityEvaluator _motionQualityEvaluator =
      MotionQualityEvaluator();
  final TrackingReliabilityEngine _trackingReliabilityEngine =
      TrackingReliabilityEngine();
  final BodyProfileEngine _bodyProfileEngine = const BodyProfileEngine();
  final FitConfidenceEngine _fitConfidenceEngine = const FitConfidenceEngine();
  final FitAnalyticsService _fitAnalyticsService = FitAnalyticsService();
  final AIStylistLayer _aiStylistLayer = const AIStylistLayer();
  final RuntimeTelemetryEngine _runtimeTelemetryEngine =
      RuntimeTelemetryEngine();
  final ArQualityScaler _qualityScaler = const ArQualityScaler();
  final SegmentationOcclusionEngine _segmentationEngine =
      SegmentationOcclusionEngine();
  final ThermalPerformanceMonitor _thermalMonitor = ThermalPerformanceMonitor();
  final GarmentCertificationService _garmentCertificationService =
      const GarmentCertificationService();
  final GarmentLodValidator _garmentLodValidator = const GarmentLodValidator();
  final GarmentBodyAlignmentEngine _garmentAlignmentEngine =
      GarmentBodyAlignmentEngine();
  final LightweightGarmentDeformationEngine _garmentDeformationEngine =
      LightweightGarmentDeformationEngine();
  final LightweightArCompositingEngine _compositingEngine =
      LightweightArCompositingEngine();
  final SessionQualityScoreEngine _sessionQualityScoreEngine =
      const SessionQualityScoreEngine();
  final TrackingAnalyticsService _trackingAnalyticsService =
      TrackingAnalyticsService();
  final MlInferenceRouter _mlInferenceRouter = const MlInferenceRouter();
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;
  late MediaPipeTryOnPayload _runtimePayload;
  CameraController? _poseCameraController;
  List<CameraDescription> _availableCameras = const <CameraDescription>[];
  int _cameraSwitchEpoch = 0;
  Uint8List? _debugJpegBytes;

  bool _isLoading = true;
  bool _cameraPermissionReady = false;
  bool _cameraPermissionDenied = false;
  bool _cameraRevealed = false;
  bool _bodyDetected = false;
  double _bodyConfidence = 0;
  BodyProfile? _bodyProfile;
  MediaPipeFitResult? _fitResult;
  Timer? _stylistTimer;
  Timer? _initTimeoutTimer;
  Timer? _renderHealthTimer;
  Timer? _lifecycleResumeDebounce;
  bool _stylistShown = false;
  bool _captureInProgress = false;
  bool _useFrontCamera = true;
  String _trackingState = 'initializing';
  TrackingConfidenceState _trackingConfidenceState =
      TrackingConfidenceState.recovering;
  bool _posePipelineReady = false;
  bool _poseStreamActive = false;
  bool _isProcessingPoseFrame = false;
  bool _poseRecoveryInProgress = false;
  bool _fallbackPoseSent = false;
  String _selectedSize = 'M';
  int _selectedColorIndex = 0;
  String _lastCapturePath = '';
  bool _savingLook = false;
  bool _fallbackActive = false;
  double _trackingReliability = 0;
  double _motionQuality = 0;
  double _lowLightRisk = 0;
  double _fastMotionRisk = 0;
  double _partialBodyRisk = 0;
  double _sessionQuality = 0;
  double _segmentationConfidence = 0.6;
  double _segmentationReliability = 0.6;
  double _armOverlapConfidence = 0.6;
  double _torsoMaskConfidence = 0.6;
  double _edgeSmoothing = 0.5;
  double _edgeStability = 0.6;
  double _maskAlpha = 0.7;
  double _occlusionBlend = 0.7;
  double _thermalLoad = 0.1;
  bool _occlusionEnabled = true;
  int _garmentQualityScore = 0;
  int _garmentLodScore = 0;
  ArDeviceTier _deviceTier = ArDeviceTier.mid;
  ArQualityProfile _qualityProfile = const ArQualityProfile(
    deviceTier: ArDeviceTier.mid,
    inferenceFps: 22,
    segmentationQuality: 0.68,
    renderQuality: 0.7,
    occlusionEnabled: true,
    segmentationInferenceStride: 2,
    segmentationEdgeSmoothing: 0.52,
    occlusionDetail: 0.58,
  );
  final List<String> _capturedLooks = <String>[];
  final List<OutfitRecommendation> _outfits = <OutfitRecommendation>[];
  String _sessionId = '';
  int _captureCount = 0;
  int _fitTrustAgreeCount = 0;
  int _fitTrustDisagreeCount = 0;
  int _stylistUsefulCount = 0;
  int _captureSatisfactionCount = 0;
  bool _trackingLockHapticFired = false;
  int _outfitSwitchCount = 0;
  final List<ArTryOnFrameStat> _frameStats = <ArTryOnFrameStat>[];
  late final AnimationController _captureFlashController;
  late final AnimationController _entryController;
  DateTime _lastPoseSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPoseSuccessAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRecoveryAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _poseFailureStreak = 0;
  int _poseDropCount = 0;
  int _poseDiagnosticsTick = 0;
  double _poseAvgLatencyMs = 0;
  double _poseErrorRate = 0;
  final List<double> _sessionQualityWindow = <double>[];
  final List<double> _thermalWindow = <double>[];
  bool _sustainedLiteMode = false;
  String _coachPrompt = '';
  StyleProfile? _styleProfile;
  List<StylistSuggestion> _stylistSuggestions = const <StylistSuggestion>[];
  DateTime _lastCoachPromptAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const List<String> _sizes = <String>['S', 'M', 'L'];
  static const List<Color> _colors = <Color>[
    Color(0xFFC6A769),
    Color(0xFF2E3C5A),
    Color(0xFF6A2C38),
    Color(0xFFE3E0D2),
  ];

  @override
  void initState() {
    super.initState();
    _runtimePayload = widget.payload;
    final cert = _garmentCertificationService.certify(_runtimePayload);
    _garmentQualityScore = cert.qualityScore;
    final lod = _garmentLodValidator.validate(
      garmentConfig: _runtimePayload.garmentConfig,
      modelUrl: _runtimePayload.model3dUrl,
    );
    _garmentLodScore = lod.score;
    _deviceTier = _resolveDeviceTier();
    _qualityProfile = _qualityScaler.profileFor(
      tier: _deviceTier,
      thermalLoad: _thermalLoad,
      trackingReliability: _trackingReliability,
    );
    _sessionId =
        'abianzo_${widget.payload.productId}_${DateTime.now().millisecondsSinceEpoch}';
    _captureFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 0,
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    WidgetsBinding.instance.addObserver(this);
    _eventsSubscription = _bridge.events.listen(_handleArEvent);
    _thermalMonitor.start(
      onTick: (snapshot) {
        _thermalLoad = snapshot.thermalLoad;
      },
    );
    _prepareCameraPermission();
    Future<void>.microtask(_loadOutfits);
  }

  ArDeviceTier _resolveDeviceTier() {
    if (Platform.isIOS) {
      return ArDeviceTier.flagship;
    }
    if (Platform.isAndroid) {
      return ArDeviceTier.mid;
    }
    return ArDeviceTier.low;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _lifecycleResumeDebounce?.cancel();
      _stopPoseStream();
      _bridge.pause();
      unawaited(_nativeRenderer.pause());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _lifecycleResumeDebounce?.cancel();
      _lifecycleResumeDebounce = Timer(const Duration(milliseconds: 280), () {
        if (!_cameraPermissionReady) {
          _prepareCameraPermission();
        }
        _startPosePipeline();
        _bridge.resume();
        unawaited(_nativeRenderer.resume());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stylistTimer?.cancel();
    _initTimeoutTimer?.cancel();
    _renderHealthTimer?.cancel();
    _eventsSubscription?.cancel();
    _captureFlashController.dispose();
    _entryController.dispose();
    _poseStabilizationEngine.reset();
    _motionQualityEvaluator.reset();
    _segmentationEngine.reset();
    _garmentAlignmentEngine.reset();
    _garmentDeformationEngine.reset();
    _compositingEngine.reset();
    _thermalMonitor.stop();
    _stopPoseStream();
    _disposePoseCamera();
    unawaited(_persistTryOnSession());
    unawaited(_nativeRenderer.dispose());
    _bridge.disposeSession();
    super.dispose();
  }

  void _handleArEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (type == 'onLoaded') {
      _initTimeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fallbackActive = false;
        });
        unawaited(_bridge.resume());
        _entryController.forward(from: 0);
        _scheduleRenderHealthCheck();
        Future<void>.delayed(ArVisualTuning.cameraRevealDelay, () {
          if (!mounted) return;
          setState(() => _cameraRevealed = true);
        });
        _scheduleStylistSuggestion();
      }
      return;
    }
    if (type == 'onFitCalculated') {
      final fit = MediaPipeFitResult.fromMap(event);
      if (mounted) {
        setState(() => _fitResult = fit);
      }
      widget.onFitCalculated?.call(fit);
      return;
    }
    if (type == 'onBodyDetection') {
      final detected = event['detected'] == true;
      final confidence = ((event['confidence'] as num?) ?? 0).toDouble();
      if (mounted) {
        setState(() {
          _bodyDetected = detected;
          _bodyConfidence = confidence;
          if (detected && confidence >= 0.25) {
            _fallbackActive = false;
          }
        });
      }
      if (detected && confidence >= 0.25) {
        _renderHealthTimer?.cancel();
        unawaited(_bridge.resume());
      }
      if (detected && _isLoading) {
        _initTimeoutTimer?.cancel();
        if (mounted) {
          setState(() => _isLoading = false);
        }
        _entryController.forward(from: 0);
      }
      return;
    }
    if (type == 'arTrackingState') {
      final state = event['state']?.toString() ?? '';
      if (mounted) {
        setState(() => _trackingState = state);
      }
      if (state == 'tracking' && !_trackingLockHapticFired) {
        _trackingLockHapticFired = true;
        HapticFeedback.lightImpact();
      } else if (state != 'tracking') {
        _trackingLockHapticFired = false;
      }
      if (state == 'unsupported' || state == 'failed') {
        widget.onError?.call('This device cannot start live AR try-on.');
      }
      return;
    }
    if (type == 'capture_complete') {
      final path = event['path']?.toString() ?? '';
      if (path.isNotEmpty) {
        unawaited(_handleCapturedPath(path));
      }
      return;
    }
    if (type == 'renderer_warning') {
      final message = event['message']?.toString() ?? 'AR runtime warning.';
      debugPrint('[Abianzo AR] warning: $message');
      widget.onError?.call(message);
      return;
    }
    if (type == 'onError' || type == 'renderer_error') {
      final code = event['code']?.toString() ?? 'renderer_error';
      final message = event['message']?.toString() ?? 'Unexpected AR error.';
      debugPrint('[Abianzo AR] $code: $message');
      if (code == 'ar_tracking_timeout') {
        // Tracking can stay in limited state on some devices even with a valid
        // camera feed/body signal. Avoid forcing visual fallback (yellow screen).
        if (!_bodyDetected) {
          _activateSmartPreviewFallback();
        }
        widget.onError?.call('Keep the phone steady while we align your fit.');
        return;
      }
      _activateSmartPreviewFallback();
      widget.onError?.call('Getting your perfect fit ready.');
    }
  }

  Future<void> _loadOutfits() async {
    try {
      final outfits = await _backendCommerce.getOutfits(
        productId: _runtimePayload.productId,
        limit: 6,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _outfits
          ..clear()
          ..addAll(outfits);
      });
      _refreshStylistLayer();
    } catch (_) {
      // Optional enhancement.
    }
  }

  void _refreshStylistLayer() {
    final fit = _fitResult;
    final stylist = _aiStylistLayer.compose(
      bodyProfile: _bodyProfile,
      outfits: _outfits,
      trackingReliability: _trackingReliability,
      fitLabel: fit?.fitLabel ?? 'Balanced Fit',
      selectedSize: _selectedSize,
      recommendedSize: fit?.recommendedSize ?? _selectedSize,
    );
    _styleProfile = stylist.$1;
    _stylistSuggestions = stylist.$2;
  }

  void _startInitTimeout() {
    _initTimeoutTimer?.cancel();
    _initTimeoutTimer = Timer(ArVisualTuning.initializationTimeout, () {
      if (!mounted || !_isLoading) return;
      if (_bodyDetected) {
        // Renderer may delay onLoaded on some devices while still providing
        // a valid body signal and camera feed. Do not force visual fallback.
        setState(() => _isLoading = false);
        _entryController.forward(from: 0);
        return;
      }
      _activateSmartPreviewFallback();
      widget.onError?.call('Getting your perfect fit ready.');
    });
  }

  Future<void> _activateSmartPreviewFallback() async {
    debugPrint('[Abianzo AR] Smart preview fallback active.');
    if (!mounted) return;
    await _bridge.pause();
    if (_poseCameraController == null || !_posePipelineReady) {
      try {
        await _initializePoseCamera();
      } catch (_) {
        // If initialization fails, UI will remain in fallback state and
        // permission gate/error messaging can guide the user.
      }
    }
    _initTimeoutTimer?.cancel();
    _renderHealthTimer?.cancel();
    if (_useFlutterPosePipeline && !_poseStreamActive) {
      unawaited(_startPosePipeline());
    }
    setState(() {
      _isLoading = false;
      _cameraRevealed = true;
      _fallbackActive = true;
    });
    _entryController.forward(from: 0);
  }

  void _scheduleRenderHealthCheck() {
    _renderHealthTimer?.cancel();
    _lifecycleResumeDebounce?.cancel();
    _renderHealthTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      final stalePose =
          DateTime.now().difference(_lastPoseSuccessAt).inSeconds >= 3;
      final trackingWeak =
          _trackingState.isEmpty ||
          _trackingState == 'initializing' ||
          _trackingState == 'limited';
      if (stalePose && _poseStreamActive) {
        unawaited(_attemptPoseRecovery(reason: 'stale_pose_stream'));
        return;
      }
      if (!_bodyDetected || _bodyConfidence < 0.16 || trackingWeak) {
        unawaited(_activateSmartPreviewFallback());
      }
    });
  }

  Widget _buildRenderSurface() {
    if (!_cameraPermissionReady) {
      return _buildCameraPermissionGate();
    }
    if (_fallbackActive) {
      final controller = _poseCameraController;
      if (controller == null || !controller.value.isInitialized) {
        Future<void>.microtask(() async {
          if (!mounted || !_fallbackActive) {
            return;
          }
          try {
            await _initializePoseCamera();
            if (_useFlutterPosePipeline && !_poseStreamActive) {
              await _startPosePipeline();
            }
            if (mounted) {
              setState(() {});
            }
          } catch (_) {}
        });
      }
      if (controller != null && controller.value.isInitialized) {
        return KeyedSubtree(
          key: ValueKey<String>(
            'pose-camera-${controller.description.name}-$_cameraSwitchEpoch',
          ),
          child: CameraPreview(controller),
        );
      }
      return const ColoredBox(color: Colors.black);
    }
    final controller = _poseCameraController;
    if (controller != null && controller.value.isInitialized) {
      return KeyedSubtree(
        key: ValueKey<String>(
          'pose-camera-${controller.description.name}-$_cameraSwitchEpoch',
        ),
        child: CameraPreview(controller),
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  Widget _buildNativeGarmentLayer() {
    if (!_cameraPermissionReady) {
      return const SizedBox.shrink();
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const SizedBox.shrink();
    }
    final lockBlend =
        (_trackingReliability * 0.75) + (_segmentationReliability * 0.25);
    final reveal = lockBlend.clamp(0.0, 1.0);
    final opacity = (0.36 + (reveal * 0.64)).clamp(0.0, 1.0);
    final scale = (0.985 + (reveal * 0.015)).clamp(0.985, 1.0);

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: opacity,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          scale: scale,
          child: Platform.isAndroid
              ? AndroidView(
                  key: ValueKey<String>(
                    'native-ar-${_runtimePayload.productId}-$_cameraSwitchEpoch',
                  ),
                  viewType: 'abzora/native_ar_try_on_view',
                  creationParams: <String, dynamic>{
                    'productId': _runtimePayload.productId,
                    'overlayAssetUrl': _runtimePayload.overlayAssetUrl,
                    'transparentAssetUrl':
                        _runtimePayload.overlayAssetUrl.isNotEmpty
                        ? _runtimePayload.overlayAssetUrl
                        : _runtimePayload.model3dUrl,
                    'model3dUrl': _normalizeCloudinaryModelUrl(
                      _runtimePayload.model3dUrl,
                    ),
                    'preferBackCamera': !_useFrontCamera,
                    'enableOcclusion': _occlusionEnabled,
                    'renderQuality': _qualityProfile.renderQuality,
                    'segmentationQuality': _qualityProfile.segmentationQuality,
                    'segmentationEdgeSmoothing':
                        _qualityProfile.segmentationEdgeSmoothing,
                    'segmentationInferenceStride':
                        _qualityProfile.segmentationInferenceStride,
                    'occlusionDetail': _qualityProfile.occlusionDetail,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                )
              : UiKitView(
                  key: ValueKey<String>(
                    'native-ar-${_runtimePayload.productId}-$_cameraSwitchEpoch',
                  ),
                  viewType: 'abzora/native_ar_try_on_view',
                  creationParams: <String, dynamic>{
                    'productId': _runtimePayload.productId,
                    'overlayAssetUrl': _runtimePayload.overlayAssetUrl,
                    'transparentAssetUrl':
                        _runtimePayload.overlayAssetUrl.isNotEmpty
                        ? _runtimePayload.overlayAssetUrl
                        : _runtimePayload.model3dUrl,
                    'model3dUrl': _normalizeCloudinaryModelUrl(
                      _runtimePayload.model3dUrl,
                    ),
                    'preferBackCamera': !_useFrontCamera,
                    'enableOcclusion': _occlusionEnabled,
                    'renderQuality': _qualityProfile.renderQuality,
                    'segmentationQuality': _qualityProfile.segmentationQuality,
                    'segmentationEdgeSmoothing':
                        _qualityProfile.segmentationEdgeSmoothing,
                    'segmentationInferenceStride':
                        _qualityProfile.segmentationInferenceStride,
                    'occlusionDetail': _qualityProfile.occlusionDetail,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                ),
        ),
      ),
    );
  }

  Future<void> _prepareCameraPermission() async {
    final hasPermission = await _ensureCameraPermission();
    if (!mounted) return;
    if (hasPermission) {
      setState(() {
        _cameraPermissionReady = true;
        _cameraPermissionDenied = false;
      });
      if (_useFlutterPosePipeline) {
        await _initializePoseCamera();
        await _startPosePipeline();
      }
      await _startArSession();
    }
  }

  Future<void> _startArSession() async {
    _startInitTimeout();
    try {
      await _bridge.initializeTryOn(_runtimePayload);
      await _nativeRenderer.initializePayload(
        payload: _runtimePayload,
        preferBackCamera: !_useFrontCamera,
        enableOcclusion: _qualityProfile.occlusionEnabled,
        segmentationQuality: _qualityProfile.segmentationQuality,
        segmentationEdgeSmoothing: _qualityProfile.segmentationEdgeSmoothing,
        segmentationInferenceStride:
            _qualityProfile.segmentationInferenceStride,
        occlusionDetail: _qualityProfile.occlusionDetail,
      );
      if (_useFlutterPosePipeline) {
        await _startPosePipeline();
      } else if (_runtimePayload.enableStaticPreviewFallback) {
        await _sendFallbackPoseFrameOnce();
      }
    } catch (error) {
      debugPrint('[Abianzo AR] Failed to start AR session: $error');
      await _activateSmartPreviewFallback();
      widget.onError?.call('Starting camera-first try-on mode.');
    }
  }

  Future<bool> _ensureCameraPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final requested = await Permission.camera.request();
        if (!requested.isGranted) {
          debugPrint('[Abianzo AR] Camera permission denied: $requested');
          if (mounted) {
            setState(() => _cameraPermissionDenied = true);
            widget.onError?.call('Camera access is needed to start Try Live.');
          }
          if (requested.isPermanentlyDenied) {
            await openAppSettings();
          }
          return false;
        }
      }

      _availableCameras = await availableCameras();
      return true;
    } on CameraException catch (error) {
      debugPrint(
        '[Abianzo AR] Camera permission check failed: ${error.code} ${error.description}',
      );
      if (mounted) {
        setState(() => _cameraPermissionDenied = true);
        widget.onError?.call('Camera access is needed to start Try Live.');
      }
      return false;
    } catch (error) {
      debugPrint('[Abianzo AR] Camera access failed: $error');
      if (mounted) {
        setState(() => _cameraPermissionDenied = true);
        widget.onError?.call('Camera access is needed to start Try Live.');
      }
      return false;
    }
  }

  Widget _buildCameraPermissionGate() {
    return ColoredBox(
      color: const Color(0xFF090B10),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 14),
              const Text(
                'Camera access is needed for Try Live',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Allow camera permission to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _prepareCameraPermission,
                child: const Text('Allow Camera'),
              ),
              if (_cameraPermissionDenied) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializePoseCamera() async {
    if (_posePipelineReady) {
      return;
    }
    if (_availableCameras.isEmpty) {
      _availableCameras = await availableCameras();
    }
    final description = _selectPoseCamera(_availableCameras);
    if (description == null) {
      debugPrint('[Abianzo AR] No camera available for pose pipeline.');
      return;
    }

    final controller = CameraController(
      description,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _poseCameraController = controller;
    _posePipelineReady = true;
    debugPrint('[Abianzo AR] Pose camera initialized: ${description.name}');
  }

  CameraDescription? _selectPoseCamera(List<CameraDescription> cameras) {
    final preferred = _useFrontCamera
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    for (final camera in cameras) {
      if (camera.lensDirection == preferred) {
        return camera;
      }
    }
    // If back camera was requested but exact back lens enum is unavailable on
    // this device (some OEMs expose external/unknown), prefer any non-front.
    if (!_useFrontCamera) {
      for (final camera in cameras) {
        if (camera.lensDirection != CameraLensDirection.front) {
          return camera;
        }
      }
    }
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }
    if (cameras.isNotEmpty) {
      return cameras.first;
    }
    return null;
  }

  Future<void> _startPosePipeline() async {
    if (!_useFlutterPosePipeline) {
      return;
    }
    if (!_cameraPermissionReady || _poseStreamActive) {
      return;
    }
    try {
      await _initializePoseCamera();
      final controller = _poseCameraController;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }
      await controller.startImageStream(_processPoseFrame);
      _poseStreamActive = true;
      _poseFailureStreak = 0;
      _poseRecoveryInProgress = false;
      debugPrint('[Abianzo AR] Pose stream started.');
    } catch (error) {
      debugPrint('[Abianzo AR] Failed to start pose stream: $error');
      if (_runtimePayload.enableStaticPreviewFallback) {
        await _sendFallbackPoseFrameOnce();
      }
    }
  }

  Future<void> _stopPoseStream() async {
    final controller = _poseCameraController;
    if (controller == null || !_poseStreamActive) {
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (_) {}
    _poseStreamActive = false;
  }

  Future<void> _disposePoseCamera() async {
    final controller = _poseCameraController;
    _poseCameraController = null;
    _posePipelineReady = false;
    if (controller == null) {
      return;
    }
    try {
      await controller.dispose();
    } catch (_) {}
  }

  int _lastTimestampMs = 0;

  Future<void> _processPoseFrame(CameraImage image) async {
    if (_isProcessingPoseFrame || !_cameraPermissionReady) {
      _poseDropCount += 1;
      return;
    }

    final now = DateTime.now();
    int currentTimestampMs = now.millisecondsSinceEpoch;
    if (currentTimestampMs <= _lastTimestampMs) {
      currentTimestampMs = _lastTimestampMs + 1;
    }
    _lastTimestampMs = currentTimestampMs;

    final adaptiveFps = _adaptiveInferenceFps();
    final frameIntervalMs = (1000 / adaptiveFps).round();
    if (now.difference(_lastPoseSentAt) <
        Duration(milliseconds: frameIntervalMs)) {
      _poseDropCount += 1;
      return;
    }

    _isProcessingPoseFrame = true;
    try {
      final jpegBytes = CameraFrameEncoder.encodeJpeg(image);
      if (jpegBytes == null) {
        throw Exception('Failed to encode camera frame to JPEG');
      }

      if (mounted) {
        setState(() {
          _debugJpegBytes = jpegBytes;
        });
      }

      // CameraX on some devices pre-rotates the image buffer.
      // If width < height, it's already in portrait, so rotation should be 0.
      final isPreRotated = image.width < image.height;
      final rotation = isPreRotated
          ? 0
          : (_poseCameraController?.description.sensorOrientation ?? 0);

      final rawPoseFrame = await _poseMeasurementService
          .analyzeTryOnLiveInputImage(
            MediaPipePoseFrameInput(
              jpegBytes: jpegBytes,
              width: image.width,
              height: image.height,
              rotation: rotation,
              timestampMs: currentTimestampMs,
            ),
          );

      if (rawPoseFrame == null) {
        _poseFailureStreak += 1;
        if (_poseFailureStreak >= 10) {
          unawaited(_attemptPoseRecovery(reason: 'empty_pose_frame'));
        }
        return;
      }
      _lastPoseSuccessAt = now;
      _poseFailureStreak = 0;

      final poseFrame = _poseStabilizationEngine.stabilize(rawPoseFrame);
      final motionQuality = _motionQualityEvaluator.evaluate(poseFrame);
      final reliability = _trackingReliabilityEngine.evaluate(
        frame: poseFrame,
        motionQuality: motionQuality,
      );
      final bodyProfile = _bodyProfileEngine.build(
        frame: poseFrame,
        tracking: reliability,
      );
      final garmentAlignment = _garmentAlignmentEngine.compute(
        frame: poseFrame,
        bodyProfile: bodyProfile,
        trackingReliability: reliability.overall,
        segmentationReliability: _segmentationReliability,
      );
      final garmentDeformation = _garmentDeformationEngine.compute(
        alignment: garmentAlignment,
        deviceTier: _qualityProfile.deviceTier,
        motionQuality: motionQuality,
        trackingReliability: reliability.overall,
        thermalLoad: _thermalLoad,
      );
      final compositing = _compositingEngine.compute(
        tier: _qualityProfile.deviceTier,
        renderQuality: _qualityProfile.renderQuality,
        thermalLoad: _thermalLoad,
        trackingReliability: reliability.overall,
        segmentationReliability: _segmentationReliability,
        occlusionBlend: _occlusionBlend,
        alignment: garmentAlignment,
        deformation: garmentDeformation,
      );
      _bodyProfile = bodyProfile;
      final fitIntelligence = _fitConfidenceEngine.evaluate(
        payload: _runtimePayload,
        bodyProfile: bodyProfile,
        tracking: reliability,
        selectedSize: _selectedSize,
      );
      final mlResult = await _mlInferenceRouter.infer(
        MlInferenceRequest(
          modelKey: 'fit_v1',
          features: <String, dynamic>{
            'trackingReliability': reliability.overall,
            'motionQuality': motionQuality,
            'bodyConfidence': bodyProfile.confidence.overall,
            'selectedSize': _selectedSize,
            'garmentQualityScore': _garmentQualityScore,
            'garmentLodScore': _garmentLodScore,
          },
          target: MlInferenceTarget.local,
        ),
      );
      final blendedFitConfidence =
          ((fitIntelligence.fitConfidence * 0.7) +
                  (mlResult.confidence.clamp(0.0, 1.0) * 0.3))
              .clamp(0.0, 1.0);
      _fitResult = MediaPipeFitResult(
        recommendedSize: fitIntelligence.recommendedSize,
        fitScore: (fitIntelligence.fitConfidence * 100).round().clamp(0, 100),
        confidence: blendedFitConfidence,
        fitLabel: fitIntelligence.fitLabel,
        templateId: _runtimePayload.templateId,
        productId: _runtimePayload.productId,
      );
      final stylist = _aiStylistLayer.compose(
        bodyProfile: _bodyProfile,
        outfits: _outfits,
        trackingReliability: _trackingReliability,
        fitLabel: _fitResult?.fitLabel ?? 'Balanced Fit',
        selectedSize: _selectedSize,
        recommendedSize: _fitResult?.recommendedSize ?? _selectedSize,
      );
      _styleProfile = stylist.$1;
      _stylistSuggestions = stylist.$2;
      _fitAnalyticsService.recordRecommendation(
        recommendedSize: fitIntelligence.recommendedSize,
        fitConfidence: fitIntelligence.fitConfidence,
        bodyProfileConfidence: bodyProfile.confidence.overall,
        trackingReliability: reliability.overall,
      );

      _lastPoseSentAt = now;
      _frameStats.add(
        ArTryOnFrameStat(
          timestampMs: now.millisecondsSinceEpoch,
          fps: 7.0,
          poseConfidence: reliability.overall.clamp(0.0, 1.0),
          bodyVisible: true,
          lightingScore: poseFrame.feedback.progress.clamp(0.0, 1.0),
        ),
      );
      if (_frameStats.length > 90) {
        _frameStats.removeAt(0);
      }
      _runtimeTelemetryEngine.trackFrame(
        timestampMs: now.millisecondsSinceEpoch,
        frame: poseFrame,
        reliability: reliability,
        body: BodyMetricsSnapshot(
          shoulderWidthNorm: bodyProfile.proportions.shoulderProportion,
          torsoRatio: bodyProfile.proportions.torsoProportion,
          waistHipRatio: bodyProfile.proportions.silhouetteIndex,
          postureTilt: bodyProfile.posture.tiltRadians,
          confidenceProfile: BodyConfidenceProfile(
            overall: bodyProfile.confidence.overall,
            shoulderConfidence: bodyProfile.confidence.proportionReliability,
            torsoConfidence: bodyProfile.confidence.proportionReliability,
            hipConfidence: bodyProfile.confidence.poseReliability,
          ),
        ),
        fps: 7.0,
        thermalLoad: (1 - reliability.overall).clamp(0.0, 1.0),
      );
      final telemetrySummary = _runtimeTelemetryEngine.summarize();
      _trackingReliability = reliability.overall;
      _trackingConfidenceState = reliability.confidenceState;
      _lowLightRisk = reliability.lowLightRisk;
      _fastMotionRisk = reliability.fastMotionRisk;
      _partialBodyRisk = reliability.partialBodyRisk;
      _motionQuality = motionQuality;
      final avgFps = (telemetrySummary['avgFps'] as num?)?.toDouble() ?? 7.0;
      _sessionQuality = _sessionQualityScoreEngine.score(
        trackingReliability: _trackingReliability,
        motionQuality: _motionQuality,
        segmentationConfidence: _segmentationConfidence,
        fpsNormalized: avgFps / 30.0,
        thermalHeadroom: 1 - _thermalLoad,
      );
      _pushSessionWindows(
        sessionQuality: _sessionQuality,
        thermalLoad: _thermalLoad,
      );
      _evaluateSustainedUiMode();
      _evaluateCoachPrompt();
      _thermalLoad = (1 - _sessionQuality).clamp(0.0, 1.0);
      final segmentation = _segmentationEngine.evaluate(
        trackingReliability: _trackingReliability,
        motionQuality: _motionQuality,
        segmentationBudget: _qualityProfile.segmentationQuality,
        allowOcclusion: _qualityProfile.occlusionEnabled,
        tierName: _qualityProfile.deviceTier.name,
        thermalLoad: _thermalLoad,
      );
      _segmentationConfidence = segmentation.confidence;
      _segmentationReliability = segmentation.reliability;
      _armOverlapConfidence = segmentation.armOverlapConfidence;
      _torsoMaskConfidence = segmentation.torsoMaskConfidence;
      _edgeSmoothing = segmentation.edgeSmoothing;
      _edgeStability = segmentation.edgeStability;
      _maskAlpha = segmentation.maskAlpha;
      _occlusionBlend = segmentation.occlusionBlend;
      _occlusionEnabled = segmentation.occlusionEnabled;
      if (segmentation.fallbackRecommended && _bodyDetected) {
        _coachPrompt =
            'Segmentation recovering. Hold still for cleaner layering';
      }
      _qualityProfile = _qualityScaler.profileFor(
        tier: _deviceTier,
        thermalLoad: _thermalLoad,
        trackingReliability: _trackingReliability,
      );
      _thermalMonitor.updateEstimate(
        sessionQuality: _sessionQuality,
        trackingReliability: _trackingReliability,
      );
      await _bridge.updateQualityProfile(_qualityProfile);
      _trackingAnalyticsService.track(<String, dynamic>{
        'trackingReliability': _trackingReliability,
        'motionQuality': _motionQuality,
        'trackingConfidenceState': _trackingConfidenceState.name,
        'lowLightRisk': _lowLightRisk,
        'fastMotionRisk': _fastMotionRisk,
        'partialBodyRisk': _partialBodyRisk,
        'segmentationConfidence': _segmentationConfidence,
        'segmentationReliability': _segmentationReliability,
        'armOverlapConfidence': _armOverlapConfidence,
        'torsoMaskConfidence': _torsoMaskConfidence,
        'edgeSmoothing': _edgeSmoothing,
        'edgeStability': _edgeStability,
        'maskAlpha': _maskAlpha,
        'occlusionBlend': _occlusionBlend,
        'sessionQuality': _sessionQuality,
        'thermalLoad': _thermalLoad,
        'fps': 7.0,
        'bodyProfileConfidence': bodyProfile.confidence.overall,
        'fitConfidence': fitIntelligence.fitConfidence,
        'poseDropCount': _poseDropCount,
        'poseFailureStreak': _poseFailureStreak,
        'poseAvgLatencyMs': _poseAvgLatencyMs,
        'poseErrorRate': _poseErrorRate,
        'garmentAttachmentConfidence': garmentAlignment.attachmentConfidence,
        'garmentStabilityScore': garmentAlignment.stabilityScore,
        'garmentDeformationStrength': garmentDeformation.deformationStrength,
        'garmentSecondaryDamping': garmentDeformation.secondaryMotionDamping,
        'shadowOpacity': compositing.shadowOpacity,
        'depthSeparation': compositing.depthSeparation,
        'layeringConfidence': compositing.layeringConfidence,
      });
      _poseDiagnosticsTick += 1;
      if (_poseDiagnosticsTick % 18 == 0) {
        unawaited(_refreshPoseDiagnostics());
      }

      final poseMap = _buildPoseFrameMap(
        frame: poseFrame,
        alignment: garmentAlignment,
        deformation: garmentDeformation,
        compositing: compositing,
      );
      final liveBodyDetected = true; // FORCE unlock tracking for upper body
      await _bridge.updatePose(poseMap);
      if (mounted) {
        final size = MediaQuery.sizeOf(context);
        unawaited(
          _nativeRenderer.updatePoseFrame(
            poseFrame: poseMap,
            viewportSize: size,
            bodyDetected: liveBodyDetected,
            lightingScore: poseFrame.feedback.progress.clamp(0.0, 1.0),
            segmentationMaskAlpha: _maskAlpha,
            segmentationEdgeStability: _edgeStability,
            occlusionBlend: _occlusionBlend,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _bodyDetected = liveBodyDetected;
          _bodyConfidence = math.max(
            reliability.overall,
            poseFrame.feedback.progress * 0.88,
          );
        });
      }
    } catch (error) {
      debugPrint('[Abianzo AR] Pose frame processing failed: $error');
      _poseFailureStreak += 1;
      if (_poseFailureStreak >= 6) {
        unawaited(_attemptPoseRecovery(reason: 'pose_processing_error'));
      }
    } finally {
      _isProcessingPoseFrame = false;
    }
  }

  int _adaptiveInferenceFps() {
    var fps = _qualityProfile.inferenceFps;
    if (_poseAvgLatencyMs >= 90) {
      fps -= 5;
    } else if (_poseAvgLatencyMs >= 65) {
      fps -= 3;
    }
    if (_poseErrorRate >= 0.24) {
      fps -= 4;
    } else if (_poseErrorRate >= 0.12) {
      fps -= 2;
    }
    if (_thermalLoad > 0.76) {
      fps -= 2;
    }
    return fps.clamp(10, _qualityProfile.inferenceFps);
  }

  void _pushSessionWindows({
    required double sessionQuality,
    required double thermalLoad,
  }) {
    _sessionQualityWindow.add(sessionQuality.clamp(0.0, 1.0));
    _thermalWindow.add(thermalLoad.clamp(0.0, 1.0));
    if (_sessionQualityWindow.length > 45) {
      _sessionQualityWindow.removeAt(0);
    }
    if (_thermalWindow.length > 45) {
      _thermalWindow.removeAt(0);
    }
  }

  void _evaluateSustainedUiMode() {
    if (_sessionQualityWindow.length < 12 || _thermalWindow.length < 12) {
      return;
    }
    double avg(List<double> values) =>
        values.fold<double>(0, (a, b) => a + b) / values.length;
    final avgQuality = avg(_sessionQualityWindow);
    final avgThermal = avg(_thermalWindow);

    final shouldEnable = avgQuality < 0.52 || avgThermal > 0.66;
    final shouldDisable = avgQuality > 0.65 && avgThermal < 0.52;
    if (shouldEnable && !_sustainedLiteMode) {
      _sustainedLiteMode = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (shouldDisable && _sustainedLiteMode) {
      _sustainedLiteMode = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _evaluateCoachPrompt() {
    final now = DateTime.now();
    if (now.difference(_lastCoachPromptAt) <
        const Duration(milliseconds: 900)) {
      return;
    }
    String next = '';
    if (!_bodyDetected || _bodyConfidence < 0.18) {
      next = 'Step back slightly so your full torso is visible';
    } else if (_trackingConfidenceState == TrackingConfidenceState.weak) {
      next = 'Hold still and keep shoulders centered to recover fit lock';
    } else if (_lowLightRisk > 0.58) {
      next = 'Increase lighting near your torso for cleaner attachment';
    } else if (_fastMotionRisk > 0.56) {
      next = 'Slow movement briefly to keep drape natural';
    } else if (_partialBodyRisk > 0.52 ||
        _trackingReliability < 0.42 ||
        _trackingState == 'limited') {
      next = 'Keep full upper body in frame for stable fit';
    } else if (_thermalLoad > 0.74 || _sustainedLiteMode) {
      next = 'Optimizing performance for smoother try-on';
    } else if (_segmentationConfidence < 0.45) {
      next = 'Improve lighting for cleaner drape edges';
    }
    if (next != _coachPrompt) {
      _coachPrompt = next;
      _lastCoachPromptAt = now;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _refreshPoseDiagnostics() async {
    try {
      final diagnostics = await MediaPipePoseBridge.instance.diagnostics();
      _poseAvgLatencyMs =
          (diagnostics['avgLatencyMs'] as num?)?.toDouble() ??
          _poseAvgLatencyMs;
      _poseErrorRate =
          (diagnostics['errorRate'] as num?)?.toDouble() ?? _poseErrorRate;
    } catch (_) {
      // Non-fatal, keep local estimates.
    }
  }

  Future<void> _attemptPoseRecovery({required String reason}) async {
    if (_poseRecoveryInProgress || !_cameraPermissionReady) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastRecoveryAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastRecoveryAt = now;
    _poseRecoveryInProgress = true;
    debugPrint('[Abianzo AR] Pose recovery triggered: $reason');
    try {
      await _stopPoseStream();
      await Future<void>.delayed(const Duration(milliseconds: 160));
      await _startPosePipeline();
      _poseFailureStreak = 0;
      _trackingState = 'limited';
      if (mounted) {
        setState(() {});
      }
      await _bridge.resume();
    } catch (error) {
      debugPrint('[Abianzo AR] Pose recovery failed: $error');
      await _activateSmartPreviewFallback();
    } finally {
      _poseRecoveryInProgress = false;
    }
  }

  Map<String, dynamic> _buildPoseFrameMap({
    required TryOnPoseFrame frame,
    required GarmentAlignmentSnapshot alignment,
    required GarmentDeformationSnapshot deformation,
    required ArCompositingSnapshot compositing,
  }) {
    Map<String, double> point(NormalizedLandmarkPoint value) =>
        <String, double>{'x': value.x, 'y': value.y};

    final spineCenter = NormalizedLandmarkPoint(
      (frame.shoulderCenter.x + frame.hipCenter.x) / 2,
      (frame.shoulderCenter.y + frame.hipCenter.y) / 2,
    );

    return <String, dynamic>{
      'leftShoulder': point(frame.leftShoulder),
      'rightShoulder': point(frame.rightShoulder),
      'leftElbow': point(frame.leftElbow),
      'rightElbow': point(frame.rightElbow),
      'leftWrist': point(frame.leftWrist),
      'rightWrist': point(frame.rightWrist),
      'leftHip': point(frame.leftHip),
      'rightHip': point(frame.rightHip),
      'shoulderCenter': point(frame.shoulderCenter),
      'hipCenter': point(frame.hipCenter),
      'spineCenter': point(spineCenter),
      'rotationRadians': frame.rotationRadians,
      'shoulderWidth': frame.shoulderWidth,
      'hipWidth': frame.shoulderWidth * 0.86,
      'torsoHeight': frame.torsoHeight,
      'lightingScore': frame.feedback.progress.clamp(0.0, 1.0),
      'trackingReliability': _trackingReliability,
      'motionQuality': _motionQuality,
      'segmentationConfidence': _segmentationConfidence,
      'segmentationReliability': _segmentationReliability,
      'armOverlapConfidence': _armOverlapConfidence,
      'torsoMaskConfidence': _torsoMaskConfidence,
      'edgeSmoothing': _edgeSmoothing,
      'edgeStability': _edgeStability,
      'maskAlpha': _maskAlpha,
      'occlusionBlend': _occlusionBlend,
      'thermalLoad': _thermalLoad,
      'occlusionEnabled': _occlusionEnabled,
      'renderQuality': _qualityProfile.renderQuality,
      'segmentationQuality': _qualityProfile.segmentationQuality,
      'deviceTier': _qualityProfile.deviceTier.name,
      'garmentQualityScore': _garmentQualityScore,
      'garmentLodScore': _garmentLodScore,
      'garmentAlignment': <String, dynamic>{
        'attachmentConfidence': alignment.attachmentConfidence,
        'stabilityScore': alignment.stabilityScore,
        'rotationRadians': alignment.rotationRadians,
        'torsoLeanRadians': alignment.torsoLeanRadians,
        'shoulderSlopeRadians': alignment.shoulderSlopeRadians,
        'waistTaperFactor': alignment.waistTaperFactor,
        'scales': <String, dynamic>{
          'shoulder': alignment.shoulderScale,
          'chest': alignment.chestScale,
          'torso': alignment.torsoScale,
          'waist': alignment.waistScale,
          'hip': alignment.hipScale,
        },
        'anchors': <String, dynamic>{
          'shoulderLeft': <String, dynamic>{
            'x': alignment.anchorShoulderLeftX,
            'y': alignment.anchorShoulderLeftY,
          },
          'shoulderRight': <String, dynamic>{
            'x': alignment.anchorShoulderRightX,
            'y': alignment.anchorShoulderRightY,
          },
          'center': <String, dynamic>{
            'x': alignment.anchorCenterX,
            'y': alignment.anchorCenterY,
          },
          'chest': <String, dynamic>{
            'x': alignment.chestCenterX,
            'y': alignment.chestCenterY,
          },
          'waist': <String, dynamic>{
            'x': alignment.anchorWaistX,
            'y': alignment.anchorWaistY,
          },
          'hip': <String, dynamic>{
            'x': alignment.anchorHipX,
            'y': alignment.anchorHipY,
          },
        },
      },
      'garmentDeformation': <String, dynamic>{
        'deformationStrength': deformation.deformationStrength,
        'secondaryMotionDamping': deformation.secondaryMotionDamping,
        'stability': deformation.stability,
        'torso': <String, dynamic>{
          'scaleX': deformation.torsoScaleX,
          'scaleY': deformation.torsoScaleY,
        },
        'regions': <String, dynamic>{
          'shoulderTension': deformation.shoulderTension,
          'chestInflation': deformation.chestInflation,
          'waistTaper': deformation.waistTaper,
          'hipEase': deformation.hipEase,
        },
      },
      'arCompositing': <String, dynamic>{
        'shadowOpacity': compositing.shadowOpacity,
        'contactShadowOpacity': compositing.contactShadowOpacity,
        'shadowSoftness': compositing.shadowSoftness,
        'depthSeparation': compositing.depthSeparation,
        'torsoDepthLift': compositing.torsoDepthLift,
        'chestDepthLift': compositing.chestDepthLift,
        'overlapBlend': compositing.overlapBlend,
        'layeringConfidence': compositing.layeringConfidence,
      },
    };
  }

  Future<void> _sendFallbackPoseFrameOnce() async {
    if (_fallbackPoseSent) {
      return;
    }
    _fallbackPoseSent = true;
    try {
      await _bridge.updatePose(<String, dynamic>{
        'leftShoulder': <String, double>{'x': 0.40, 'y': 0.30},
        'rightShoulder': <String, double>{'x': 0.60, 'y': 0.30},
        'leftHip': <String, double>{'x': 0.44, 'y': 0.56},
        'rightHip': <String, double>{'x': 0.56, 'y': 0.56},
        'shoulderCenter': <String, double>{'x': 0.50, 'y': 0.30},
        'hipCenter': <String, double>{'x': 0.50, 'y': 0.56},
        'spineCenter': <String, double>{'x': 0.50, 'y': 0.43},
        'rotationRadians': 0.0,
        'shoulderWidth': 0.20,
        'hipWidth': 0.16,
        'torsoHeight': 0.26,
        'lightingScore': 0.50,
        'garmentAlignment': <String, dynamic>{
          'attachmentConfidence': 0.55,
          'stabilityScore': 0.55,
          'rotationRadians': 0.0,
          'torsoLeanRadians': 0.0,
          'scales': <String, dynamic>{
            'shoulder': 1.0,
            'chest': 1.0,
            'torso': 1.0,
            'waist': 1.0,
            'hip': 1.0,
          },
          'anchors': <String, dynamic>{
            'shoulderLeft': <String, dynamic>{'x': 0.40, 'y': 0.30},
            'shoulderRight': <String, dynamic>{'x': 0.60, 'y': 0.30},
            'center': <String, dynamic>{'x': 0.50, 'y': 0.40},
            'waist': <String, dynamic>{'x': 0.50, 'y': 0.48},
            'hip': <String, dynamic>{'x': 0.50, 'y': 0.56},
          },
        },
        'garmentDeformation': <String, dynamic>{
          'deformationStrength': 0.5,
          'secondaryMotionDamping': 0.6,
          'stability': 0.55,
          'torso': <String, dynamic>{'scaleX': 1.0, 'scaleY': 1.0},
          'regions': <String, dynamic>{
            'shoulderTension': 1.0,
            'chestInflation': 1.0,
            'waistTaper': 1.0,
            'hipEase': 1.0,
          },
        },
        'arCompositing': <String, dynamic>{
          'shadowOpacity': 0.14,
          'contactShadowOpacity': 0.18,
          'shadowSoftness': 0.5,
          'depthSeparation': 0.3,
          'torsoDepthLift': 0.06,
          'chestDepthLift': 0.08,
          'overlapBlend': 0.55,
          'layeringConfidence': 0.5,
        },
      });
      if (mounted) {
        setState(() {
          _bodyDetected = true;
          _bodyConfidence = 0.5;
        });
      }
      debugPrint('[Abianzo AR] Sent fallback pose frame.');
    } catch (error) {
      debugPrint('[Abianzo AR] Failed to send fallback pose frame: $error');
    }
  }

  void _scheduleStylistSuggestion() {
    _stylistTimer?.cancel();
    _stylistTimer = Timer(ArVisualTuning.stylistDelay, () {
      if (!mounted || _stylistShown) return;
      _stylistShown = true;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFFF7F4EE),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (context) {
          final recommendation = _fitResult?.recommendedSize ?? _selectedSize;
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'AI Stylist',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  'This style suits your body type. Try $recommendation for a sharper fit.',
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _selectSize(recommendation);
                    },
                    child: const Text('Apply Suggestion'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Future<void> _captureLook() async {
    if (_captureInProgress) return;
    if (_trackingReliability < 0.48 || _segmentationReliability < 0.45) {
      HapticFeedback.selectionClick();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold steady for a cleaner, editorial capture'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _captureInProgress = true);
    try {
      _captureFlashController.forward(from: 0);
      final nativePath = await _nativeRenderer.capturePreview();
      if (nativePath != null && nativePath.isNotEmpty) {
        await _handleCapturedPath(nativePath);
        return;
      }
      await _bridge.capture();
      if (_lastCapturePath.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Capture unavailable right now. Try again in a moment.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _captureInProgress = false);
    }
  }

  Future<void> _handleCapturedPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    HapticFeedback.mediumImpact();
    _captureCount += 1;
    _capturedLooks.insert(0, path);
    if (_capturedLooks.length > 8) {
      _capturedLooks.removeRange(8, _capturedLooks.length);
    }
    _lastCapturePath = path;
    if (mounted) {
      setState(() {});
    }
    await _showCaptureActions(path);
  }

  Future<void> _showCaptureActions(String path) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Save to profile'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _saveLookToProfile(path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share to WhatsApp / Instagram'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _shareLook(path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download image'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _downloadLook(path);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveLookToProfile(String path) async {
    if (_savingLook) return;
    setState(() => _savingLook = true);
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw StateError('Captured image not found.');
      }
      final bytes = await file.readAsBytes();
      final imageUrl = await _backendCommerce.uploadArLookImage(
        bytes: bytes,
        filename: 'ar_look_${DateTime.now().millisecondsSinceEpoch}.png',
        mimeSubtype: 'png',
      );
      if (imageUrl.isEmpty) {
        throw StateError('Image upload failed.');
      }
      await _backendCommerce.saveArLook(
        productId: _runtimePayload.productId,
        templateId: _runtimePayload.templateId,
        imageUrl: imageUrl,
        size: _selectedSize,
        fitScore: _fitResult?.fitScore ?? 0,
        confidence: _fitResult?.confidence ?? 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Look saved to profile'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _showTrustFeedbackSheet(source: 'save');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingLook = false);
    }
  }

  Future<void> _shareLook(String path) async {
    HapticFeedback.selectionClick();
    final file = await _createWatermarkedShareFile(path);
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      text: 'Trying this on Abianzo',
      subject: 'Abianzo Try Live',
    );
    if (!mounted) return;
    await _showPostShareNudge();
  }

  Future<void> _showPostShareNudge() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Your look is trending',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get feedback from friends.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Share.share(
                      'Trying this on Abianzo. Send to 3 friends.',
                    );
                    await _showTrustFeedbackSheet(source: 'share');
                  },
                  child: const Text('Send to 3 friends'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadLook(String path) async {
    try {
      HapticFeedback.selectionClick();
      final source = File(path);
      if (!await source.exists()) {
        throw StateError('Capture file missing');
      }
      final targetName =
          'abianzo_look_${DateTime.now().millisecondsSinceEpoch}.png';
      final androidDownload = Directory('/storage/emulated/0/Download');
      Directory targetDir = Directory.systemTemp;
      if (Platform.isAndroid && await androidDownload.exists()) {
        targetDir = androidDownload;
      }
      final target = File(
        '${targetDir.path}${Platform.pathSeparator}$targetName',
      );
      await source.copy(target.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded to ${target.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<File> _createWatermarkedShareFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final frame = img.decodeImage(bytes);
    if (frame == null) {
      return File(path);
    }
    final portrait = _toSocialPortrait(frame);
    final bannerHeight = math.max(42, portrait.height ~/ 11);
    img.fillRect(
      portrait,
      x1: 0,
      y1: portrait.height - bannerHeight,
      x2: portrait.width,
      y2: portrait.height,
      color: img.ColorRgba8(12, 12, 12, 165),
    );
    img.drawString(
      portrait,
      'ABZORA Try-On',
      font: img.arial24,
      x: 12,
      y: portrait.height - bannerHeight + 8,
      color: img.ColorRgba8(255, 255, 255, 240),
    );
    img.drawString(
      portrait,
      'Luxury Fit Preview',
      font: img.arial24,
      x: math.max(12, portrait.width - 220),
      y: 10,
      color: img.ColorRgba8(230, 196, 132, 200),
    );
    final encoded = img.encodeJpg(portrait, quality: 94);
    final target = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}abianzo_share_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await target.writeAsBytes(encoded, flush: true);
    return target;
  }

  Future<void> _showTrustFeedbackSheet({required String source}) async {
    if (!mounted) return;
    String? selection;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121317),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'How did this fit feel?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _feedbackChip('Accurate fit', () {
                      selection = 'fit_agree';
                      Navigator.of(context).pop();
                    }),
                    _feedbackChip('Needs adjustment', () {
                      selection = 'fit_disagree';
                      Navigator.of(context).pop();
                    }),
                    _feedbackChip('Stylist was useful', () {
                      selection = 'stylist_useful';
                      Navigator.of(context).pop();
                    }),
                    _feedbackChip('Great capture', () {
                      selection = 'capture_satisfied';
                      Navigator.of(context).pop();
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selection == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (selection == 'fit_agree') _fitTrustAgreeCount += 1;
      if (selection == 'fit_disagree') _fitTrustDisagreeCount += 1;
      if (selection == 'stylist_useful') _stylistUsefulCount += 1;
      if (selection == 'capture_satisfied') _captureSatisfactionCount += 1;
    });
    debugPrint('[Abianzo AR] trust-feedback: $selection via $source');
  }

  Widget _feedbackChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C21),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  img.Image _toSocialPortrait(img.Image source) {
    const targetRatio = 4 / 5; // social portrait
    final currentRatio = source.width / source.height;
    if ((currentRatio - targetRatio).abs() < 0.01) {
      return source;
    }
    if (currentRatio > targetRatio) {
      final cropWidth = (source.height * targetRatio).round();
      final x = ((source.width - cropWidth) / 2).round().clamp(0, source.width);
      return img.copyCrop(
        source,
        x: x,
        y: 0,
        width: cropWidth,
        height: source.height,
      );
    }
    final cropHeight = (source.width / targetRatio).round();
    final y = ((source.height - cropHeight) / 2).round().clamp(
      0,
      source.height,
    );
    return img.copyCrop(
      source,
      x: 0,
      y: y,
      width: source.width,
      height: cropHeight,
    );
  }

  Future<void> _handleExitFlow() async {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Loved your fit?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                _sheetAction(label: 'Buy Now', value: 'buy', isPrimary: true),
                const SizedBox(height: 8),
                _sheetAction(label: 'Try at Home', value: 'try'),
                const SizedBox(height: 8),
                _sheetAction(label: 'Save for Later', value: 'save'),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'save') {
      final path = _lastCapturePath;
      if (path.isNotEmpty) {
        await _showCaptureActions(path);
      } else {
        await _captureLook();
      }
      return;
    }
    Navigator.of(context).pop(action);
  }

  Widget _sheetAction({
    required String label,
    required String value,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? FilledButton(
              onPressed: () => Navigator.of(context).pop(value),
              style: FilledButton.styleFrom(
                backgroundColor: ArVisualTuning.fitAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: () => Navigator.of(context).pop(value),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.white,
              ),
              child: Text(label),
            ),
    );
  }

  Future<void> _selectSize(String size) async {
    if (_selectedSize == size) return;
    HapticFeedback.selectionClick();
    final recommended = _fitResult?.recommendedSize ?? _selectedSize;
    setState(() => _selectedSize = size);
    _fitAnalyticsService.recordInteraction(
      action: 'size_selected',
      selectedSize: size,
      recommendedSize: recommended,
    );
    final measurements = <String, double>{..._runtimePayload.measurements};
    final baseChest = measurements['chestCm'] ?? 96;
    final multiplier = size == 'S' ? 0.95 : (size == 'L' ? 1.06 : 1.0);
    measurements['chestCm'] = baseChest * multiplier;
    final fitPreset = size == 'S'
        ? 'slim'
        : (size == 'L' ? 'relaxed' : 'regular');
    final garment = <String, dynamic>{..._runtimePayload.garmentConfig};
    garment['fit'] = fitPreset;
    garment['fitPreset'] = fitPreset;
    _runtimePayload = _runtimePayload.copyWith(
      measurements: measurements,
      garmentConfig: garment,
    );
    _refreshStylistLayer();
    await _bridge.updateGarmentConfig(_runtimePayload);
    _entryController.forward(from: 0.2);
  }

  Future<void> _selectColor(int index) async {
    if (_selectedColorIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedColorIndex = index);
    final garment = <String, dynamic>{..._runtimePayload.garmentConfig};
    final colorHex =
        '#${_colors[index].toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    garment['color'] = colorHex;
    garment['colorHex'] = colorHex;
    _runtimePayload = _runtimePayload.copyWith(garmentConfig: garment);
    await _bridge.updateGarmentConfig(_runtimePayload);
    _entryController.forward(from: 0.2);
  }

  bool get _alignmentReady => _bodyDetected && _bodyConfidence >= 0.54;

  Widget _buildLoadingCurtain() {
    return AnimatedOpacity(
      opacity: _cameraRevealed ? 0 : 1,
      duration: const Duration(milliseconds: 220),
      child: ColoredBox(
        color: ArVisualTuning.loadingOverlayColor,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 66,
                height: 66,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  color: ArVisualTuning.fitAccent,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Preparing your live fitting room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text('Step into frame', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyGuide() {
    if (_isLoading || _fallbackActive) {
      return const SizedBox.shrink();
    }
    final outlineColor = _alignmentReady
        ? const Color(0xFF63E18B)
        : (_bodyDetected ? const Color(0xFFE2C283) : const Color(0xA3FFFFFF));
    final guideOpacity = _alignmentReady ? 0.02 : (_bodyDetected ? 0.10 : 0.38);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          opacity: guideOpacity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: 220,
              height: 430,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: outlineColor.withValues(
                      alpha: _alignmentReady ? 0.06 : 0.10,
                    ),
                    blurRadius: _alignmentReady ? 14 : 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _BodyOutlinePainter(
                  color: outlineColor,
                  glow: _alignmentReady,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureRail() {
    if (_sustainedLiteMode) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 16,
      right: 16,
      bottom: 210,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _capturedLooks.isEmpty
            ? const SizedBox.shrink()
            : DecoratedBox(
                key: const ValueKey<String>('captureRail'),
                decoration: BoxDecoration(
                  color: const Color(0xCC14151A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: SizedBox(
                  height: 82,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedLooks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = _capturedLooks[index];
                      final isSelected = path == _lastCapturePath;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _lastCapturePath = path);
                          _showCaptureActions(path);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? ArVisualTuning.fitAccent
                                  : Colors.white24,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(
                                  color: Color(0x33222222),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  bool get _trackingLocked =>
      _alignmentReady &&
      (_trackingState == 'tracking' || _trackingState.isEmpty);

  bool get _liteUiMode =>
      _sustainedLiteMode ||
      _trackingState == 'limited' ||
      _bodyConfidence < 0.4;

  String get _trackingLabel {
    if (_trackingState == 'unsupported') {
      return 'Unsupported Device';
    }
    if (_trackingConfidenceState == TrackingConfidenceState.weak) {
      return 'Recovering Pose';
    }
    if (_trackingConfidenceState == TrackingConfidenceState.recovering) {
      return 'Stabilizing Motion';
    }
    if (_segmentationReliability < 0.4) {
      return 'Refining Mask';
    }
    if (_trackingLocked) {
      return 'Tracking Locked';
    }
    if (_bodyDetected) {
      return 'Stabilizing';
    }
    return 'Aligning';
  }

  String get _fitToneLabel {
    final score = _fitResult?.fitScore ?? 0;
    if (score >= 90) {
      return 'Tailored to your frame';
    }
    if (score >= 78) {
      return 'Balanced drape';
    }
    return 'Needs quick realignment';
  }

  String get _fitPerceptionLabel {
    final confidence = _fitResult?.confidence ?? 0;
    final reliability =
        (_trackingReliability * 0.6) + (_segmentationReliability * 0.4);
    if (confidence >= 0.86 && reliability >= 0.8) {
      return 'Runway Lock';
    }
    if (confidence >= 0.72 && reliability >= 0.64) {
      return 'Tailored Match';
    }
    if (confidence >= 0.58 && reliability >= 0.52) {
      return 'Refining Drape';
    }
    return 'Aligning Fit';
  }

  String get _fitPerceptionCue {
    if (_trackingConfidenceState == TrackingConfidenceState.weak) {
      return 'Hold still for shoulder and chest lock';
    }
    if (_segmentationReliability < 0.45) {
      return 'Raise ambient light to refine silhouette edges';
    }
    if (_trackingLocked) {
      return 'Body lock stable. Garment is adapting to your silhouette';
    }
    return 'Center shoulders to tighten body-contour alignment';
  }

  String _trustCalibrationLine(double confidence) {
    if (confidence >= 0.88) {
      return 'High confidence: body mapping is stable and fit guidance is reliable.';
    }
    if (confidence >= 0.74) {
      return 'Balanced confidence: recommendation is strong, with minor movement sensitivity.';
    }
    if (confidence >= 0.58) {
      return 'Developing confidence: hold steady briefly to refine shoulder and torso fit.';
    }
    return 'Limited confidence: re-align in frame for a more accurate recommendation.';
  }

  Future<void> _handleCheckoutFlow() async {
    if (!mounted) {
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).pop('buy');
  }

  Future<void> _openActionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121317),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: const Color(0xFF1A1C21),
                  leading: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Stylist Controls',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openExperienceSheet();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: const Color(0xFF1A1C21),
                  leading: const Icon(
                    Icons.cameraswitch_rounded,
                    color: Colors.white70,
                  ),
                  title: Text(
                    _useFrontCamera
                        ? 'Switch To Back Camera'
                        : 'Switch To Front Camera',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _switchCameraFacing();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: const Color(0xFF1A1C21),
                  leading: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Reset Tracking',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendFallbackPoseFrameOnce();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExperienceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111216),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.34,
          minChildSize: 0.2,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _fitToneLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recommended: ${_fitResult?.recommendedSize ?? _selectedSize} | Fit confidence ${((_fitResult?.confidence ?? 0) * 100).round()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_trustCalibrationLine(_fitResult?.confidence ?? 0)} $_fitPerceptionCue.',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                if (_styleProfile != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17191F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${_styleProfile!.primaryStyle} | ${_styleProfile!.occasion}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stylist confidence ${(100 * _styleProfile!.confidence).round()}% | ${_styleProfile!.fitPreference}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                if (_stylistSuggestions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  ..._stylistSuggestions.take(2).map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17191F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              suggestion.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion.subtitle,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion.reasoning,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Size',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _sizes
                      .map(
                        (size) => ArChoicePill(
                          label: size,
                          selected: _selectedSize == size,
                          onTap: () => _selectSize(size),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Color',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: List<Widget>.generate(_colors.length, (index) {
                    return ArColorSwatchButton(
                      color: _colors[index],
                      selected: _selectedColorIndex == index,
                      onTap: () => _selectColor(index),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                if (_outfits.isNotEmpty) ...<Widget>[
                  const Text(
                    'Complete Looks',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _outfits.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final outfit = _outfits[index];
                        return OutlinedButton(
                          onPressed: () => _applyOutfit(outfit),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            outfit.title.isEmpty
                                ? 'Look ${index + 1}'
                                : outfit.title,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _handleCheckoutFlow();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ArVisualTuning.fitAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Shop This Fit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyOutfit(OutfitRecommendation outfit) async {
    final target = outfit.items.isNotEmpty ? outfit.items.first : null;
    if (target == null || target.id.isEmpty) {
      return;
    }
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      final metadata = await _backendCommerce.getTryOnProductMetadata(
        target.id,
      );
      final nextPayload = MediaPipeTryOnPayload(
        productId: metadata.id,
        name: metadata.name,
        category: metadata.category,
        templateId: metadata.templateId,
        template: metadata.templateData,
        garmentConfig: metadata.garmentConfig,
        alignmentConfig: metadata.alignmentConfig,
        model3dUrl: metadata.model3dUrl,
        assetBundleUrl: metadata.assetBundleUrl,
        rigProfile: metadata.rigProfile,
        materialProfile: metadata.materialProfile,
        overlayAssetUrl: metadata.overlayAssetUrl,
        measurements: _runtimePayload.measurements,
        enableStaticPreviewFallback:
            _runtimePayload.enableStaticPreviewFallback,
      );
      _runtimePayload = nextPayload;
      final cert = _garmentCertificationService.certify(nextPayload);
      final lod = _garmentLodValidator.validate(
        garmentConfig: nextPayload.garmentConfig,
        modelUrl: nextPayload.model3dUrl,
      );
      _garmentQualityScore = cert.qualityScore;
      _garmentLodScore = lod.score;
      _outfitSwitchCount += 1;
      HapticFeedback.selectionClick();
      await _bridge.initializeTryOn(nextPayload);
      await _nativeRenderer.initializePayload(
        payload: nextPayload,
        preferBackCamera: !_useFrontCamera,
        enableOcclusion: _qualityProfile.occlusionEnabled,
        segmentationQuality: _qualityProfile.segmentationQuality,
        segmentationEdgeSmoothing: _qualityProfile.segmentationEdgeSmoothing,
        segmentationInferenceStride:
            _qualityProfile.segmentationInferenceStride,
        occlusionDetail: _qualityProfile.occlusionDetail,
      );
      _refreshStylistLayer();
      if (mounted) {
        setState(() => _isLoading = false);
        _entryController.forward(from: 0.15);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Keep current garment if switch fails.
    }
  }

  Future<void> _switchCameraFacing() async {
    final previousFront = _useFrontCamera;
    final nextFront = !previousFront;
    setState(() {
      _useFrontCamera = nextFront;
      _cameraSwitchEpoch += 1;
      _trackingState = nextFront ? 'front camera' : 'back camera';
    });
    try {
      if (_poseStreamActive) {
        await _stopPoseStream();
      }
      await _disposePoseCamera();
      await Future<void>.delayed(const Duration(milliseconds: 220));
      _availableCameras = await availableCameras();
      await _initializePoseCamera();
      await _startPosePipeline();
      await _nativeRenderer.setCameraFacing(front: nextFront);
      if (mounted) {
        setState(() => _cameraSwitchEpoch += 1);
      }
      HapticFeedback.selectionClick();
    } catch (error) {
      if (mounted) {
        setState(() {
          _useFrontCamera = previousFront;
          _cameraSwitchEpoch += 1;
        });
      } else {
        _useFrontCamera = previousFront;
      }
      debugPrint('[Abianzo AR] Camera switch failed: $error');
      widget.onError?.call('Unable to switch camera right now.');
    }
  }

  Future<void> _persistTryOnSession() async {
    if (!_backendCommerce.isConfigured || _frameStats.isEmpty) {
      return;
    }
    final avgFps =
        _frameStats.fold<double>(0, (sum, stat) => sum + stat.fps) /
        _frameStats.length;
    final avgPose =
        _frameStats.fold<double>(0, (sum, stat) => sum + stat.poseConfidence) /
        _frameStats.length;
    final peakFps = _frameStats.fold<double>(
      0,
      (max, stat) => math.max(max, stat.fps),
    );
    final payload = ArTryOnSessionPayload(
      productId: _runtimePayload.productId,
      sessionId: _sessionId,
      platform: Platform.operatingSystem,
      deviceModel: Platform.operatingSystemVersion,
      cameraFacing: 'front',
      mode: 'cv_live',
      captureCount: _captureCount,
      outfitSwitchCount: _outfitSwitchCount,
      averageFps: avgFps,
      peakFps: peakFps,
      averagePoseConfidence: avgPose,
      bodyProfileSnapshot: _runtimePayload.measurements,
      measurements: _runtimePayload.measurements,
      renderStats: <String, dynamic>{
        'trackingState': _trackingState,
        'trackingConfidenceState': _trackingConfidenceState.name,
        'lowLightRisk': _lowLightRisk,
        'fastMotionRisk': _fastMotionRisk,
        'partialBodyRisk': _partialBodyRisk,
        'bodyDetected': _bodyDetected,
        'trackingReliability': _trackingReliability,
        'motionQuality': _motionQuality,
        'segmentationConfidence': _segmentationConfidence,
        'thermalLoad': _thermalLoad,
        'sessionQuality': _sessionQuality,
        'occlusionEnabled': _occlusionEnabled,
        'deviceTier': _qualityProfile.deviceTier.name,
        'qualityProfile': _qualityProfile.toMap(),
        'garmentQualityScore': _garmentQualityScore,
        'garmentLodScore': _garmentLodScore,
        'trackingAnalytics': _trackingAnalyticsService.summarize(),
        'fitAnalytics': _fitAnalyticsService.summarize(),
        'trustValidation': <String, dynamic>{
          'fitAgreeCount': _fitTrustAgreeCount,
          'fitDisagreeCount': _fitTrustDisagreeCount,
          'stylistUsefulCount': _stylistUsefulCount,
          'captureSatisfactionCount': _captureSatisfactionCount,
        },
      },
      events: List<ArTryOnFrameStat>.from(_frameStats),
      previewImageUrl: _lastCapturePath,
    );
    try {
      final runtimeSummary = _runtimeTelemetryEngine.summarize();
      final trackingSummary = _trackingAnalyticsService.summarize();
      final fitSummary = _fitAnalyticsService.summarize();
      await _backendCommerce.saveTryOnSession(payload);
      await _backendCommerce.saveTryOnTelemetry(
        sessionId: _sessionId,
        productId: _runtimePayload.productId,
        telemetry: <String, dynamic>{
          'trackingReliability': _trackingReliability,
          'trackingConfidenceState': _trackingConfidenceState.name,
          'lowLightRisk': _lowLightRisk,
          'fastMotionRisk': _fastMotionRisk,
          'partialBodyRisk': _partialBodyRisk,
          'motionQuality': _motionQuality,
          'segmentationConfidence': _segmentationConfidence,
          'segmentationReliability': _segmentationReliability,
          'armOverlapConfidence': _armOverlapConfidence,
          'torsoMaskConfidence': _torsoMaskConfidence,
          'edgeSmoothing': _edgeSmoothing,
          'edgeStability': _edgeStability,
          'maskAlpha': _maskAlpha,
          'occlusionBlend': _occlusionBlend,
          'thermalLoad': _thermalLoad,
          'sessionQuality': _sessionQuality,
          'deviceTier': _qualityProfile.deviceTier.name,
          'qualityProfile': _qualityProfile.toMap(),
          'garmentQualityScore': _garmentQualityScore,
          'garmentLodScore': _garmentLodScore,
          'trackingAnalytics': trackingSummary,
          'fitAnalytics': fitSummary,
          'trustValidation': <String, dynamic>{
            'fitAgreeCount': _fitTrustAgreeCount,
            'fitDisagreeCount': _fitTrustDisagreeCount,
            'stylistUsefulCount': _stylistUsefulCount,
            'captureSatisfactionCount': _captureSatisfactionCount,
            'recommendationAcceptanceSignal':
                (_fitTrustAgreeCount + _fitTrustDisagreeCount) == 0
                ? 0.0
                : _fitTrustAgreeCount /
                      (_fitTrustAgreeCount + _fitTrustDisagreeCount),
          },
          'bodyProfile': <String, dynamic>{
            'shapeClass': _bodyProfile?.shapeClass.name ?? '',
            'fitPreferenceHint': _bodyProfile?.fitPreferenceHint.name ?? '',
            'postureTendency': _bodyProfile?.posture.tendency.name ?? '',
            'confidence': _bodyProfile?.confidence.overall ?? 0.0,
          },
          'runtimeTelemetry': runtimeSummary,
          'dashboard': <String, dynamic>{
            'qualityBand': _qualityBand(_sessionQuality),
            'thermalBand': _thermalBand(_thermalLoad),
            'trackingBand': _qualityBand(_trackingReliability),
            'segmentationBand': _qualityBand(_segmentationConfidence),
            'flags': <String, dynamic>{
              'sustainedLiteMode': _sustainedLiteMode,
              'thermalRisk': _thermalLoad >= 0.72,
              'trackingRisk': _trackingReliability < 0.42,
              'segmentationRisk': _segmentationConfidence < 0.45,
              'occlusionRisk': _segmentationReliability < 0.45,
              'poseLatencyRisk': _poseAvgLatencyMs >= 80,
              'poseErrorRisk': _poseErrorRate >= 0.15,
            },
            'trends': <String, dynamic>{
              'reliabilityTrend': runtimeSummary['reliabilityTrend'] ?? 0.0,
              'fpsTrend': runtimeSummary['fpsTrend'] ?? 0.0,
              'avgThermalLoad':
                  runtimeSummary['avgThermalLoad'] ?? _thermalLoad,
              'avgSessionQuality':
                  trackingSummary['avgSessionQuality'] ?? _sessionQuality,
            },
            'deviceTier': _qualityProfile.deviceTier.name,
          },
        },
      );
    } catch (_) {
      // Analytics should not block teardown.
    }
  }

  Widget _buildCinematicTopBar() {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 10,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _sustainedLiteMode ? 0.84 : 1.0,
        child: Row(
          children: <Widget>[
            ArRailButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: _handleExitFlow,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ABZORA Try-On',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _trackingLabel,
                    style: TextStyle(
                      color: _trackingLocked
                          ? const Color(0xFF7FD69A)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ArRailButton(
              icon: Icons.more_horiz_rounded,
              onTap: _openActionSheet,
            ),
          ],
        ),
      ),
    );
  }

  String _qualityBand(double value) {
    if (value >= 0.8) return 'excellent';
    if (value >= 0.62) return 'good';
    if (value >= 0.42) return 'fair';
    return 'weak';
  }

  String _thermalBand(double value) {
    if (value < 0.35) return 'cool';
    if (value < 0.58) return 'warm';
    if (value < 0.75) return 'hot';
    return 'critical';
  }

  String _normalizeCloudinaryModelUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final lower = trimmed.toLowerCase();
    final isModel = lower.endsWith('.glb') || lower.endsWith('.gltf');
    if (!isModel) {
      return trimmed;
    }
    if (lower.contains('/raw/upload/')) {
      return trimmed;
    }
    if (lower.contains('/image/upload/')) {
      return trimmed.replaceFirst('/image/upload/', '/raw/upload/');
    }
    if (lower.contains('res.cloudinary.com') && !lower.startsWith('http')) {
      return 'https://$trimmed'.replaceFirst('/image/upload/', '/raw/upload/');
    }
    return trimmed;
  }

  Widget _buildTrackingHud() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }
    final alpha = _trackingLocked ? 0.0 : (_liteUiMode ? 0.7 : 1.0);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 66,
      left: 12,
      right: 12,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: alpha,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chipWidth = math.max(118.0, (constraints.maxWidth - 8) / 2);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: chipWidth),
                      child: ArStatusChip(label: _trackingLabel),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: chipWidth),
                      child: ArStatusChip(
                        label: _bodyDetected
                            ? '${(_bodyConfidence * 100).round()}% body confidence'
                            : 'Finding silhouette',
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: chipWidth),
                      child: ArStatusChip(
                        label:
                            'Mask ${(_segmentationReliability * 100).round()}% | Edge ${(_edgeStability * 100).round()}%',
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: chipWidth),
                      child: ArStatusChip(label: _fitPerceptionLabel),
                    ),
                  ],
                ),
                if (_coachPrompt.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: ArStatusChip(label: _coachPrompt),
                  ),
                ],
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: ArStatusChip(label: _fitPerceptionCue),
                ),
                if (_stylistSuggestions.isNotEmpty &&
                    !_trackingLocked) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xB814151A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      _stylistSuggestions.first.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingRail() {
    final hideControls =
        _captureInProgress || (_trackingLocked && !_liteUiMode);
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: hideControls ? 0.78 : 1,
        child: Row(
          children: <Widget>[
            ArRailButton(
              icon: Icons.checkroom_outlined,
              onTap: _openExperienceSheet,
            ),
            const SizedBox(width: 10),
            ArRailButton(
              icon: Icons.cameraswitch_rounded,
              onTap: _switchCameraFacing,
            ),
            const Spacer(),
            GestureDetector(
              onTap: _captureInProgress ? null : _captureLook,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2C283), width: 2),
                  color: const Color(0xCC0F1013),
                ),
                child: Center(
                  child: Container(
                    width: _captureInProgress ? 30 : 40,
                    height: _captureInProgress ? 30 : 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE2C283),
                    ),
                    child: Icon(
                      _captureInProgress
                          ? Icons.hourglass_top_rounded
                          : Icons.camera_alt_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            ArRailButton(
              icon: Icons.auto_awesome_outlined,
              onTap: _openExperienceSheet,
            ),
            const SizedBox(width: 10),
            ArRailButton(
              icon: Icons.bookmark_add_outlined,
              onTap: _savingLook
                  ? null
                  : () async {
                      final path = _lastCapturePath;
                      if (path.isNotEmpty) {
                        await _saveLookToProfile(path);
                      } else {
                        await _captureLook();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugHud() {
    if (!_showDebugHud) {
      return const SizedBox.shrink();
    }
    final avgFps = 7.0; // Placeholder for actual average

    return Stack(
      children: [
        Positioned(
          top: MediaQuery.of(context).padding.top + 100,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // Existing debug text
              Text(
                'Cam: ${_poseCameraController?.description.sensorOrientation ?? '??'}°',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'FPS: ${avgFps.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (_debugJpegBytes != null)
          Positioned(
            bottom: 120,
            left: 16,
            width: 120,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Image.memory(
                _debugJpegBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExitFlow();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildRenderSurface()),
            Positioned.fill(child: _buildNativeGarmentLayer()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.30),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.26),
                      ],
                      stops: const <double>[0, 0.22, 1],
                    ),
                  ),
                ),
              ),
            ),
            _buildBodyGuide(),
            _buildLoadingCurtain(),
            _buildCinematicTopBar(),
            _buildTrackingHud(),
            _buildDebugHud(),
            _buildCaptureRail(),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _captureFlashController,
                  builder: (context, _) {
                    final value = _captureFlashController.value;
                    if (value <= 0) {
                      return const SizedBox.shrink();
                    }
                    final opacity = (1 - value) * 0.34;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: opacity),
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildFloatingRail(),
          ],
        ),
      ),
    );
  }
}

class _BodyOutlinePainter extends CustomPainter {
  const _BodyOutlinePainter({required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final headRadius = size.width * 0.13;

    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow ? 3.4 : 2.6;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: glow ? 0.20 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow ? 8 : 5;

    final torsoPath = Path()
      ..moveTo(centerX, headRadius * 2.2)
      ..quadraticBezierTo(
        centerX - size.width * 0.22,
        size.height * 0.26,
        centerX - size.width * 0.20,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        centerX - size.width * 0.17,
        size.height * 0.70,
        centerX - size.width * 0.08,
        size.height * 0.90,
      )
      ..moveTo(centerX, headRadius * 2.2)
      ..quadraticBezierTo(
        centerX + size.width * 0.22,
        size.height * 0.26,
        centerX + size.width * 0.20,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        centerX + size.width * 0.17,
        size.height * 0.70,
        centerX + size.width * 0.08,
        size.height * 0.90,
      );

    final armsPath = Path()
      ..moveTo(centerX - size.width * 0.18, size.height * 0.34)
      ..quadraticBezierTo(
        centerX - size.width * 0.32,
        size.height * 0.44,
        centerX - size.width * 0.28,
        size.height * 0.60,
      )
      ..moveTo(centerX + size.width * 0.18, size.height * 0.34)
      ..quadraticBezierTo(
        centerX + size.width * 0.32,
        size.height * 0.44,
        centerX + size.width * 0.28,
        size.height * 0.60,
      );

    canvas.drawCircle(Offset(centerX, headRadius * 1.1), headRadius, glowPaint);
    canvas.drawCircle(
      Offset(centerX, headRadius * 1.1),
      headRadius,
      outlinePaint,
    );
    canvas.drawPath(torsoPath, glowPaint);
    canvas.drawPath(armsPath, glowPaint);
    canvas.drawPath(torsoPath, outlinePaint);
    canvas.drawPath(armsPath, outlinePaint);

    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1.3;

    canvas.drawLine(
      Offset(centerX - size.width * 0.26, size.height * 0.28),
      Offset(centerX - size.width * 0.35, size.height * 0.28),
      markerPaint,
    );
    canvas.drawLine(
      Offset(centerX + size.width * 0.26, size.height * 0.28),
      Offset(centerX + size.width * 0.35, size.height * 0.28),
      markerPaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height * 0.95),
      Offset(centerX, size.height),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BodyOutlinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glow != glow;
  }
}
