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
    this.templateId = '',
    this.templateData = const <String, dynamic>{},
    this.garmentConfig = const <String, dynamic>{},
    this.lodModels = const <String, dynamic>{},
    this.customizableParts = const <String, dynamic>{},
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
  final String templateId;
  final Map<String, dynamic> templateData;
  final Map<String, dynamic> garmentConfig;
  final Map<String, dynamic> lodModels;
  final Map<String, dynamic> customizableParts;
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
      templateId: map['templateId']?.toString() ?? '',
      templateData: Map<String, dynamic>.from(
        map['template'] as Map? ?? const {},
      ),
      garmentConfig: Map<String, dynamic>.from(
        map['garmentConfig'] as Map? ?? const {},
      ),
      lodModels: Map<String, dynamic>.from(
        (map['garmentConfig'] as Map?)?['lodModels'] as Map? ?? const {},
      ),
      customizableParts: Map<String, dynamic>.from(
        (map['template'] as Map?)?['customizableParts'] as Map? ?? const {},
      ),
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

class GarmentTemplateModel {
  const GarmentTemplateModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    this.modelUrls = const <String, dynamic>{},
    this.unity = const <String, dynamic>{},
    this.rigProfile = '',
    this.blendShapes = const <String, dynamic>{},
    this.customizableParts = const <String, dynamic>{},
    this.supportedFits = const <String>[],
    this.defaultMaterialProfile = '',
    this.defaultColorHex = '#C6A769',
    this.defaultFabricTextureUrl = '',
    this.cachePolicy = const <String, dynamic>{},
    this.active = true,
    this.updatedAt,
  });

  final String id;
  final String slug;
  final String name;
  final String category;
  final Map<String, dynamic> modelUrls;
  final Map<String, dynamic> unity;
  final String rigProfile;
  final Map<String, dynamic> blendShapes;
  final Map<String, dynamic> customizableParts;
  final List<String> supportedFits;
  final String defaultMaterialProfile;
  final String defaultColorHex;
  final String defaultFabricTextureUrl;
  final Map<String, dynamic> cachePolicy;
  final bool active;
  final DateTime? updatedAt;

  factory GarmentTemplateModel.fromMap(Map<String, dynamic> map) {
    return GarmentTemplateModel(
      id: map['id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      modelUrls: Map<String, dynamic>.from(map['modelUrls'] as Map? ?? const {}),
      unity: Map<String, dynamic>.from(map['unity'] as Map? ?? const {}),
      rigProfile: map['rigProfile']?.toString() ?? '',
      blendShapes: Map<String, dynamic>.from(
        map['blendShapes'] as Map? ?? const {},
      ),
      customizableParts: Map<String, dynamic>.from(
        map['customizableParts'] as Map? ?? const {},
      ),
      supportedFits: List<String>.from(map['supportedFits'] as List? ?? const []),
      defaultMaterialProfile: map['defaultMaterialProfile']?.toString() ?? '',
      defaultColorHex: map['defaultColorHex']?.toString() ?? '#C6A769',
      defaultFabricTextureUrl: map['defaultFabricTextureUrl']?.toString() ?? '',
      cachePolicy: Map<String, dynamic>.from(
        map['cachePolicy'] as Map? ?? const {},
      ),
      active: map['active'] != false,
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.tryParse(map['updatedAt'].toString()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'category': category,
    'modelUrls': modelUrls,
    'unity': unity,
    'rigProfile': rigProfile,
    'blendShapes': blendShapes,
    'customizableParts': customizableParts,
    'supportedFits': supportedFits,
    'defaultMaterialProfile': defaultMaterialProfile,
    'defaultColorHex': defaultColorHex,
    'defaultFabricTextureUrl': defaultFabricTextureUrl,
    'cachePolicy': cachePolicy,
    'active': active,
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

class ArFitAssessment {
  const ArFitAssessment({
    required this.recommendedSize,
    required this.fitScore,
    required this.fitLabel,
    required this.confidence,
    this.category = '',
    this.fitPreset = 'regular',
    this.productId = '',
    this.templateId = '',
    this.usedMeasurements = const <String>[],
    this.sizeChart = const <String, dynamic>{},
    this.template = const <String, dynamic>{},
  });

  final String recommendedSize;
  final int fitScore;
  final String fitLabel;
  final double confidence;
  final String category;
  final String fitPreset;
  final String productId;
  final String templateId;
  final List<String> usedMeasurements;
  final Map<String, dynamic> sizeChart;
  final Map<String, dynamic> template;

  factory ArFitAssessment.fromMap(Map<String, dynamic> map) {
    return ArFitAssessment(
      recommendedSize: map['recommendedSize']?.toString() ?? 'M',
      fitScore: (map['fitScore'] as num?)?.toInt() ?? 75,
      fitLabel: map['fitLabel']?.toString() ?? 'Good fit',
      confidence: ((map['confidence'] as num?) ?? 0.6).toDouble(),
      category: map['category']?.toString() ?? '',
      fitPreset: map['fitPreset']?.toString() ?? 'regular',
      productId: map['productId']?.toString() ?? '',
      templateId: map['templateId']?.toString() ?? '',
      usedMeasurements: List<String>.from(
        map['usedMeasurements'] as List? ?? const [],
      ),
      sizeChart: Map<String, dynamic>.from(map['sizeChart'] as Map? ?? const {}),
      template: Map<String, dynamic>.from(map['template'] as Map? ?? const {}),
    );
  }
}
