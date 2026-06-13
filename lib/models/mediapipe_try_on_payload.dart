import 'dart:convert';

class MediaPipeTryOnPayload {
  const MediaPipeTryOnPayload({
    required this.productId,
    required this.name,
    required this.category,
    required this.templateId,
    required this.template,
    required this.garmentConfig,
    required this.alignmentConfig,
    this.model3dUrl = '',
    this.assetBundleUrl = '',
    this.rigProfile = '',
    this.materialProfile = '',
    this.overlayAssetUrl = '',
    this.measurements = const <String, double>{},
    this.enableStaticPreviewFallback = false,
  });

  final String productId;
  final String name;
  final String category;
  final String templateId;
  final Map<String, dynamic> template;
  final Map<String, dynamic> garmentConfig;
  final Map<String, dynamic> alignmentConfig;
  final String model3dUrl;
  final String assetBundleUrl;
  final String rigProfile;
  final String materialProfile;
  final String overlayAssetUrl;
  final Map<String, double> measurements;
  final bool enableStaticPreviewFallback;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'productId': productId,
    'name': name,
    'category': category,
    'templateId': templateId,
    'template': template,
    'garmentConfig': garmentConfig,
    'alignmentConfig': alignmentConfig,
    'model3dUrl': model3dUrl,
    'assetBundleUrl': assetBundleUrl,
    'rigProfile': rigProfile,
    'materialProfile': materialProfile,
    'overlayAssetUrl': overlayAssetUrl,
    'measurements': measurements,
    'enableStaticPreviewFallback': enableStaticPreviewFallback,
  };

  String toJson() => jsonEncode(toMap());

  MediaPipeTryOnPayload copyWith({
    String? productId,
    String? name,
    String? category,
    String? templateId,
    Map<String, dynamic>? template,
    Map<String, dynamic>? garmentConfig,
    Map<String, dynamic>? alignmentConfig,
    String? model3dUrl,
    String? assetBundleUrl,
    String? rigProfile,
    String? materialProfile,
    String? overlayAssetUrl,
    Map<String, double>? measurements,
    bool? enableStaticPreviewFallback,
  }) {
    return MediaPipeTryOnPayload(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      category: category ?? this.category,
      templateId: templateId ?? this.templateId,
      template: template ?? this.template,
      garmentConfig: garmentConfig ?? this.garmentConfig,
      alignmentConfig: alignmentConfig ?? this.alignmentConfig,
      model3dUrl: model3dUrl ?? this.model3dUrl,
      assetBundleUrl: assetBundleUrl ?? this.assetBundleUrl,
      rigProfile: rigProfile ?? this.rigProfile,
      materialProfile: materialProfile ?? this.materialProfile,
      overlayAssetUrl: overlayAssetUrl ?? this.overlayAssetUrl,
      measurements: measurements ?? this.measurements,
      enableStaticPreviewFallback:
          enableStaticPreviewFallback ?? this.enableStaticPreviewFallback,
    );
  }
}

class MediaPipeFitResult {
  const MediaPipeFitResult({
    required this.recommendedSize,
    required this.fitScore,
    required this.confidence,
    required this.fitLabel,
    this.templateId = '',
    this.productId = '',
  });

  final String recommendedSize;
  final int fitScore;
  final double confidence;
  final String fitLabel;
  final String templateId;
  final String productId;

  factory MediaPipeFitResult.fromMap(Map<String, dynamic> map) {
    return MediaPipeFitResult(
      recommendedSize: map['recommendedSize']?.toString() ?? 'M',
      fitScore: (map['fitScore'] as num?)?.toInt() ?? 0,
      confidence: ((map['confidence'] as num?) ?? 0).toDouble(),
      fitLabel: map['fitLabel']?.toString() ?? '',
      templateId: map['templateId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
    );
  }
}
