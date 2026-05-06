import 'dart:async';

import '../models/ar_realtime_try_on_result.dart';
import '../models/ar_try_on_models.dart';
import 'backend_commerce_service.dart';
import 'unity_try_on_bridge.dart';

class ArTryOnOrchestratorService {
  ArTryOnOrchestratorService({
    BackendCommerceService? backend,
    UnityTryOnBridge? unityBridge,
  }) : _backend = backend ?? BackendCommerceService(),
       _unityBridge = unityBridge ?? UnityTryOnBridge.instance;

  final BackendCommerceService _backend;
  final UnityTryOnBridge _unityBridge;
  StreamSubscription<ArRealtimeTryOnResult>? _fitSub;
  final StreamController<ArRealtimeTryOnResult> _fitController =
      StreamController<ArRealtimeTryOnResult>.broadcast();

  Stream<ArRealtimeTryOnResult> get fitResults => _fitController.stream;

  Future<ArTryOnProductMetadata> start({
    required String productId,
    required Map<String, double> measurements,
    Map<String, dynamic> userProfile = const {},
    bool enableAvatar = true,
  }) async {
    final metadata = await _backend.getTryOnProductMetadata(productId);
    await _unityBridge.initialize(
      metadata: metadata,
      measurements: measurements,
      userProfile: userProfile,
      enableAvatar: enableAvatar,
    );
    await _fitSub?.cancel();
    _fitSub = _unityBridge.fitResults.listen((event) {
      _fitController.add(event);
    });
    return metadata;
  }

  Future<void> loadGarment(String productId) async {
    final metadata = await _backend.getTryOnProductMetadata(productId);
    await _unityBridge.loadGarment(metadata);
  }

  Future<void> updatePose(Map<String, dynamic> poseFrame) =>
      _unityBridge.updatePose(poseFrame);

  Future<String?> capture() => _unityBridge.capture();

  Future<void> close() async {
    await _fitSub?.cancel();
    _fitSub = null;
    await _unityBridge.dispose();
  }

  Future<void> dispose() async {
    await close();
    await _fitController.close();
  }
}
