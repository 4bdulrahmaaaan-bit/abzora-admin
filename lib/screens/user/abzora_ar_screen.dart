import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/ar_visual_tuning.dart';
import '../../models/abzora_unity_try_on_payload.dart';
import '../../services/abzora_unity_bridge_service.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/camera_frame_encoder.dart';
import '../../services/mediapipe_pose_bridge.dart';
import '../../services/pose_measurement_service.dart';

class AbzoraArScreen extends StatefulWidget {
  const AbzoraArScreen({
    super.key,
    required this.payload,
    this.onFitCalculated,
    this.onError,
  });

  final AbzoraUnityTryOnPayload payload;
  final ValueChanged<AbzoraUnityFitResult>? onFitCalculated;
  final ValueChanged<String>? onError;

  @override
  State<AbzoraArScreen> createState() => _AbzoraArScreenState();
}

class _AbzoraArScreenState extends State<AbzoraArScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const bool _useFlutterPosePipeline = false;
  final AbzoraUnityBridgeService _bridge = AbzoraUnityBridgeService.instance;
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final PoseMeasurementService _poseMeasurementService =
      const PoseMeasurementService();
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;
  late AbzoraUnityTryOnPayload _runtimePayload;
  CameraController? _poseCameraController;
  List<CameraDescription> _availableCameras = const <CameraDescription>[];

  bool _isLoading = true;
  bool _cameraPermissionReady = false;
  bool _cameraPermissionDenied = false;
  bool _cameraRevealed = false;
  bool _bodyDetected = false;
  double _bodyConfidence = 0;
  AbzoraUnityFitResult? _fitResult;
  Timer? _stylistTimer;
  Timer? _initTimeoutTimer;
  bool _stylistShown = false;
  bool _captureInProgress = false;
  bool _posePipelineReady = false;
  bool _poseStreamActive = false;
  bool _isProcessingPoseFrame = false;
  bool _fallbackPoseSent = false;
  String _selectedSize = 'M';
  int _selectedColorIndex = 0;
  double _rotateY = 0;
  double _zoom = 1;
  String _lastCapturePath = '';
  bool _savingLook = false;
  final bool _fallbackActive = false;
  final List<String> _capturedLooks = <String>[];
  late final AnimationController _captureFlashController;
  late final AnimationController _entryController;
  late final Key _unityInstanceKey;
  DateTime _lastPoseSentAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    _unityInstanceKey = UniqueKey();
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
    _eventsSubscription = _bridge.events.listen(_handleUnityEvent);
    _prepareCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPoseStream();
      _bridge.pause();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (!_cameraPermissionReady) {
        _prepareCameraPermission();
      }
      _startPosePipeline();
      _bridge.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stylistTimer?.cancel();
    _initTimeoutTimer?.cancel();
    _eventsSubscription?.cancel();
    _captureFlashController.dispose();
    _entryController.dispose();
    _stopPoseStream();
    _disposePoseCamera();
    _bridge.disposeSession();
    super.dispose();
  }

  void _handleUnityEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (type == 'onLoaded') {
      _initTimeoutTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
        _entryController.forward(from: 0);
        Future<void>.delayed(ArVisualTuning.cameraRevealDelay, () {
          if (!mounted) return;
          setState(() => _cameraRevealed = true);
        });
        _scheduleStylistSuggestion();
      }
      return;
    }
    if (type == 'onFitCalculated') {
      final fit = AbzoraUnityFitResult.fromMap(event);
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
        });
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
    if (type == 'capture_complete') {
      final path = event['path']?.toString() ?? '';
      if (path.isNotEmpty) {
        HapticFeedback.mediumImpact();
        _capturedLooks.insert(0, path);
        if (_capturedLooks.length > 8) {
          _capturedLooks.removeRange(8, _capturedLooks.length);
        }
        _lastCapturePath = path;
        if (mounted) {
          setState(() {});
        }
        _showCaptureActions(path);
      }
      return;
    }
    if (type == 'onError' || type == 'unity_error') {
      final code = event['code']?.toString() ?? 'unity_error';
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

  void _startInitTimeout() {
    _initTimeoutTimer?.cancel();
    _initTimeoutTimer = Timer(ArVisualTuning.initializationTimeout, () {
      if (!mounted || !_isLoading) return;
      if (_bodyDetected) {
        // Unity may delay onLoaded on some devices while still providing
        // a valid body signal and camera feed. Do not force visual fallback.
        setState(() => _isLoading = false);
        _entryController.forward(from: 0);
        return;
      }
      _activateSmartPreviewFallback();
      widget.onError?.call('Getting your perfect fit ready.');
    });
  }

  void _activateSmartPreviewFallback() {
    // Temporarily disabled to isolate yellow-screen source.
    // If yellow remains, it is coming from Unity render path, not Flutter UI.
    debugPrint('[Abianzo AR] Smart preview fallback suppressed (diagnostic mode).');
    if (!mounted) return;
    _initTimeoutTimer?.cancel();
    setState(() {
      _isLoading = false;
      _cameraRevealed = true;
    });
    _entryController.forward(from: 0);
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
    }
  }

  Future<void> _onUnityCreated(UnityWidgetController controller) async {
    _bridge.attachController(controller);
    _startInitTimeout();
    await _bridge.initializeTryOn(_runtimePayload);
    if (_useFlutterPosePipeline) {
      await _startPosePipeline();
    } else {
      await _sendFallbackPoseFrameOnce();
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
      debugPrint('[Abianzo AR] Camera permission check failed: ${error.code} ${error.description}');
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
      debugPrint('[Abianzo AR] Pose stream started.');
    } catch (error) {
      debugPrint('[Abianzo AR] Failed to start pose stream: $error');
      await _sendFallbackPoseFrameOnce();
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

  Future<void> _processPoseFrame(CameraImage image) async {
    if (_isProcessingPoseFrame || !_cameraPermissionReady) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastPoseSentAt) < const Duration(milliseconds: 140)) {
      return;
    }

    final jpegBytes = CameraFrameEncoder.encodeJpeg(image);
    if (jpegBytes == null) {
      return;
    }

    _isProcessingPoseFrame = true;
    try {
      final poseFrame = await _poseMeasurementService.analyzeTryOnLiveInputImage(
        MediaPipePoseFrameInput(
          jpegBytes: jpegBytes,
          width: image.width,
          height: image.height,
          rotation: _poseCameraController?.description.sensorOrientation ?? 0,
          timestampMs: now.millisecondsSinceEpoch,
        ),
      );

      if (poseFrame == null) {
        return;
      }

      _lastPoseSentAt = now;
      await _bridge.updatePose(_buildUnityPoseFrameMap(poseFrame));
    } catch (error) {
      debugPrint('[Abianzo AR] Pose frame processing failed: $error');
    } finally {
      _isProcessingPoseFrame = false;
    }
  }

  Map<String, dynamic> _buildUnityPoseFrameMap(TryOnPoseFrame frame) {
    Map<String, double> point(NormalizedLandmarkPoint value) =>
        <String, double>{'x': value.x, 'y': value.y};

    final spineCenter = NormalizedLandmarkPoint(
      (frame.shoulderCenter.x + frame.hipCenter.x) / 2,
      (frame.shoulderCenter.y + frame.hipCenter.y) / 2,
    );

    return <String, dynamic>{
      'leftShoulder': point(frame.leftShoulder),
      'rightShoulder': point(frame.rightShoulder),
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
    HapticFeedback.lightImpact();
    setState(() => _captureInProgress = true);
    try {
      _captureFlashController.forward(from: 0);
      await _bridge.capture();
    } finally {
      if (mounted) setState(() => _captureInProgress = false);
    }
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
                    await Share.share('Trying this on Abianzo. Send to 3 friends.');
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
      final targetName = 'abzora_look_${DateTime.now().millisecondsSinceEpoch}.png';
      final androidDownload = Directory('/storage/emulated/0/Download');
      Directory targetDir = Directory.systemTemp;
      if (Platform.isAndroid && await androidDownload.exists()) {
        targetDir = androidDownload;
      }
      final target = File('${targetDir.path}${Platform.pathSeparator}$targetName');
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
    final bannerHeight = math.max(38, frame.height ~/ 10);
    img.fillRect(
      frame,
      x1: 0,
      y1: frame.height - bannerHeight,
      x2: frame.width,
      y2: frame.height,
      color: img.ColorRgba8(12, 12, 12, 165),
    );
    img.drawString(
      frame,
      'Trying this on Abianzo',
      font: img.arial24,
      x: 12,
      y: frame.height - bannerHeight + 8,
      color: img.ColorRgba8(255, 255, 255, 240),
    );
    img.drawString(
      frame,
      'Abianzo',
      font: img.arial24,
      x: frame.width - 120,
      y: 10,
      color: img.ColorRgba8(230, 196, 132, 200),
    );
    final encoded = img.encodePng(frame);
    final target = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}abzora_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await target.writeAsBytes(encoded, flush: true);
    return target;
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
                _sheetAction(
                  label: 'Buy Now',
                  value: 'buy',
                  isPrimary: true,
                ),
                const SizedBox(height: 8),
                _sheetAction(
                  label: 'Try at Home',
                  value: 'try',
                ),
                const SizedBox(height: 8),
                _sheetAction(
                  label: 'Save for Later',
                  value: 'save',
                ),
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
    setState(() => _selectedSize = size);
    final measurements = <String, double>{..._runtimePayload.measurements};
    final baseChest = measurements['chestCm'] ?? 96;
    final multiplier = size == 'S' ? 0.95 : (size == 'L' ? 1.06 : 1.0);
    measurements['chestCm'] = baseChest * multiplier;
    final fitPreset = size == 'S' ? 'slim' : (size == 'L' ? 'relaxed' : 'regular');
    final garment = <String, dynamic>{..._runtimePayload.garmentConfig};
    garment['fit'] = fitPreset;
    garment['fitPreset'] = fitPreset;
    _runtimePayload = _runtimePayload.copyWith(
      measurements: measurements,
      garmentConfig: garment,
    );
    await _bridge.updateGarmentConfig(_runtimePayload);
    _entryController.forward(from: 0.2);
  }

  Future<void> _selectColor(int index) async {
    if (_selectedColorIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedColorIndex = index);
    final garment = <String, dynamic>{..._runtimePayload.garmentConfig};
    final colorHex = '#${_colors[index].toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    garment['color'] = colorHex;
    garment['colorHex'] = colorHex;
    _runtimePayload = _runtimePayload.copyWith(garmentConfig: garment);
    await _bridge.updateGarmentConfig(_runtimePayload);
    _entryController.forward(from: 0.2);
  }

  Future<void> _updateView({
    double? rotateY,
    double? zoom,
  }) async {
    if (rotateY != null) {
      _rotateY = rotateY;
    }
    if (zoom != null) {
      _zoom = zoom;
    }
    await _bridge.setViewTransform(rotateY: _rotateY, zoom: _zoom);
    if (mounted) setState(() {});
  }

  bool get _alignmentReady => _bodyDetected && _bodyConfidence >= 0.72;

  String get _statusLabel {
    if (_isLoading) {
      return 'Preparing';
    }
    if (_alignmentReady) {
      return 'Ready';
    }
    if (_bodyDetected) {
      return 'Refining';
    }
    return 'Aligning';
  }

  String get _statusMessage {
    if (_isLoading) {
      return 'Getting your perfect fit ready';
    }
    if (_alignmentReady) {
      return 'Perfect fit ready';
    }
    if (_bodyDetected) {
      return 'Hold steady for the final drape';
    }
    return 'Step into the frame';
  }

  Future<void> _nudgeRotate(double delta) async {
    HapticFeedback.selectionClick();
    final next = (_rotateY + delta).clamp(-35.0, 35.0);
    await _updateView(rotateY: next);
  }

  Future<void> _nudgeZoom(double delta) async {
    HapticFeedback.selectionClick();
    final next = (_zoom + delta).clamp(0.8, 1.35);
    await _updateView(zoom: next);
  }

  Widget _buildSceneAtmosphere() {
    if (_fallbackActive) {
      return const SizedBox.shrink();
    }
    if (!_isLoading) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: _ArGridPainter()),
          ),
          const Positioned(
            top: -80,
            right: -30,
            child: _LightBloom(size: 220, color: Color(0x55FFE2A8)),
          ),
          const Positioned(
            top: 160,
            left: -20,
            child: _LightBloom(size: 180, color: Color(0x334AA3FF)),
          ),
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, 0.78),
              child: Container(
                width: 220,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 44,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCurtain() {
    return AnimatedOpacity(
      opacity: _cameraRevealed ? 0 : 1,
      duration: const Duration(milliseconds: 220),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 7, end: _cameraRevealed ? 0 : 7),
        duration: ArVisualTuning.cameraFadeDuration,
        builder: (context, sigma, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child!,
          );
        },
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
                  'Getting your perfect fit ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Step into the frame',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final statusColor = _alignmentReady
        ? const Color(0xFF6BE28B)
        : (_bodyDetected ? const Color(0xFFE3C071) : Colors.white);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 14,
      right: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x40111418),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: _handleExitFlow,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Try Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.55),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
    return Positioned.fill(
      child: IgnorePointer(
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
                    alpha: _alignmentReady ? 0.26 : 0.14,
                  ),
                  blurRadius: _alignmentReady ? 30 : 18,
                  spreadRadius: _alignmentReady ? 3 : 0,
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
    );
  }

  Widget _buildFitCard(int fitScore, int confidencePercent) {
    if (_fitResult == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 92,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entryController,
          curve: const Interval(0.1, 0.85, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.14),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _entryController,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x66111318),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Tailored to you',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${_fitResult?.recommendedSize ?? _selectedSize} fit',
                            style: const TextStyle(
                              color: ArVisualTuning.fitAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$confidencePercent% confidence in this drape',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0, end: fitScore / 100.0),
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                ArVisualTuning.fitAccent,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureRail() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 210,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _capturedLooks.isEmpty
            ? const SizedBox.shrink()
            : ClipRRect(
                key: const ValueKey<String>('captureRail'),
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x3810141A),
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
                                  child: Icon(Icons.image_not_supported_outlined),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.18, 1.0, curve: Curves.easeOut),
    );
    final entryPosition = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: FadeTransition(
        opacity: entryOpacity,
        child: SlideTransition(
          position: entryPosition,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x4210151C),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            'Size',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          ..._sizes.map(
                            (size) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _ChoicePill(
                                label: size,
                                selected: _selectedSize == size,
                                onTap: () => _selectSize(size),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Text(
                            'Color',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          ...List<Widget>.generate(_colors.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _ColorSwatchButton(
                                color: _colors[index],
                                selected: _selectedColorIndex == index,
                                onTap: () => _selectColor(index),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          _GlassIconButton(
                            icon: Icons.rotate_left_rounded,
                            onTap: () => _nudgeRotate(-8),
                          ),
                          const SizedBox(width: 10),
                          _GlassIconButton(
                            icon: Icons.rotate_right_rounded,
                            onTap: () => _nudgeRotate(8),
                          ),
                          const SizedBox(width: 10),
                          _GlassIconButton(
                            icon: Icons.remove_rounded,
                            onTap: () => _nudgeZoom(-0.08),
                          ),
                          const SizedBox(width: 10),
                          _GlassIconButton(
                            icon: Icons.add_rounded,
                            onTap: () => _nudgeZoom(0.08),
                          ),
                          const Spacer(),
                          _GlassIconButton(
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
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _captureInProgress ? null : _captureLook,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    Color(0xFFFFF4DC),
                                    Color(0xFFE2C283),
                                  ],
                                ),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x55E2C283),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: _captureInProgress ? 34 : 40,
                                  height: _captureInProgress ? 34 : 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0D0F14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _captureInProgress
                                        ? Icons.hourglass_top_rounded
                                        : Icons.camera_alt_rounded,
                                    color: Colors.white,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fitScore = (_fitResult?.fitScore ?? 0).clamp(0, 100).round();
    final confidencePercent = ((_fitResult?.confidence ?? 0) * 100).round();
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
            Positioned.fill(
              child: _cameraPermissionReady
                  ? UnityWidget(
                      key: _unityInstanceKey,
                      onUnityCreated: _onUnityCreated,
                      onUnityMessage: _bridge.onUnityMessage,
                      useAndroidViewSurface: true,
                      unloadOnDispose: true,
                    )
                  : _buildCameraPermissionGate(),
            ),
            _buildSceneAtmosphere(),
            _buildBodyGuide(),
            _buildLoadingCurtain(),
            _buildTopBar(),
            _buildFitCard(fitScore, confidencePercent),
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
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: opacity)),
                    );
                  },
                ),
              ),
            ),
            _buildBottomControls(),
            if (_fallbackActive)
              Positioned(
                left: 18,
                right: 18,
                bottom: 194,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x3810151C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Getting your perfect fit ready',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap == null ? 0.05 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? ArVisualTuning.fitAccent
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: selected ? 32 : 28,
        height: selected ? 32 : 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 2.4 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _LightBloom extends StatelessWidget {
  const _LightBloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

class _ArGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;

    const spacing = 28.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

    canvas.drawCircle(
      Offset(centerX, headRadius * 1.1),
      headRadius,
      glowPaint,
    );
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
