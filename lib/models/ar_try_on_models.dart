class ArTryOnProductMetadata {
  const ArTryOnProductMetadata({
    required this.id,
    required this.name,
    required this.category,
    required this.images,
    required this.overlayAssetUrl,
    required this.transparentAssetUrl,
    required this.model3dUrl,
    required this.unityAssetBundleUrl,
    required this.rigProfile,
    required this.materialProfile,
    required this.alignmentConfig,
    required this.arAsset,
    this.storeName = '',
  });

  final String id;
  final String name;
  final String category;
  final List<String> images;
  final String overlayAssetUrl;
  final String transparentAssetUrl;
  final String model3dUrl;
  final String unityAssetBundleUrl;
  final String rigProfile;
  final String materialProfile;
  final Map<String, dynamic> alignmentConfig;
  final Map<String, dynamic> arAsset;
  final String storeName;

  factory ArTryOnProductMetadata.fromMap(Map<String, dynamic> map) {
    final store = Map<String, dynamic>.from(map['store'] as Map? ?? const {});
    return ArTryOnProductMetadata(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      images: List<String>.from(map['images'] as List? ?? const []),
      overlayAssetUrl: map['overlayAssetUrl']?.toString() ?? '',
      transparentAssetUrl: map['transparentAssetUrl']?.toString() ?? '',
      model3dUrl: map['model3d']?.toString() ?? '',
      unityAssetBundleUrl: map['unityAssetBundleUrl']?.toString() ?? '',
      rigProfile: map['rigProfile']?.toString() ?? '',
      materialProfile: map['materialProfile']?.toString() ?? '',
      alignmentConfig: Map<String, dynamic>.from(
        map['alignmentConfig'] as Map? ?? const {},
      ),
      arAsset: Map<String, dynamic>.from(map['arAsset'] as Map? ?? const {}),
      storeName: store['name']?.toString() ?? '',
    );
  }
}

class ArTryOnFrameStat {
  const ArTryOnFrameStat({
    required this.timestampMs,
    required this.fps,
    required this.poseConfidence,
    required this.bodyVisible,
    required this.lightingScore,
  });

  final int timestampMs;
  final double fps;
  final double poseConfidence;
  final bool bodyVisible;
  final double lightingScore;

  Map<String, dynamic> toMap() => {
    'timestampMs': timestampMs,
    'fps': fps,
    'poseConfidence': poseConfidence,
    'bodyVisible': bodyVisible,
    'lightingScore': lightingScore,
  };
}

class ArTryOnSessionPayload {
  const ArTryOnSessionPayload({
    required this.productId,
    required this.sessionId,
    required this.platform,
    required this.deviceModel,
    required this.cameraFacing,
    required this.mode,
    required this.captureCount,
    required this.outfitSwitchCount,
    required this.averageFps,
    required this.peakFps,
    required this.averagePoseConfidence,
    required this.bodyProfileSnapshot,
    required this.measurements,
    required this.renderStats,
    required this.events,
    this.previewImageUrl = '',
    this.status = 'completed',
  });

  final String productId;
  final String sessionId;
  final String platform;
  final String deviceModel;
  final String cameraFacing;
  final String mode;
  final int captureCount;
  final int outfitSwitchCount;
  final double averageFps;
  final double peakFps;
  final double averagePoseConfidence;
  final Map<String, double> bodyProfileSnapshot;
  final Map<String, double> measurements;
  final Map<String, dynamic> renderStats;
  final List<ArTryOnFrameStat> events;
  final String previewImageUrl;
  final String status;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'sessionId': sessionId,
    'platform': platform,
    'deviceModel': deviceModel,
    'cameraFacing': cameraFacing,
    'mode': mode,
    'captureCount': captureCount,
    'outfitSwitchCount': outfitSwitchCount,
    'averageFps': averageFps,
    'peakFps': peakFps,
    'averagePoseConfidence': averagePoseConfidence,
    'bodyProfileSnapshot': bodyProfileSnapshot,
    'measurements': measurements,
    'renderStats': renderStats,
    'events': events.map((event) => event.toMap()).toList(),
    'previewImageUrl': previewImageUrl,
    'status': status,
  };
}
