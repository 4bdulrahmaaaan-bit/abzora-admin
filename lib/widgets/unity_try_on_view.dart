import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ar_try_on_models.dart';

class UnityTryOnView extends StatelessWidget {
  const UnityTryOnView({
    super.key,
    required this.metadata,
    this.measurements = const {},
    this.enableAvatar = true,
  });

  final ArTryOnProductMetadata metadata;
  final Map<String, double> measurements;
  final bool enableAvatar;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'productId': metadata.id,
      'name': metadata.name,
      'category': metadata.category,
      'model3dUrl': metadata.model3dUrl,
      'unityAssetBundleUrl': metadata.unityAssetBundleUrl,
      'rigProfile': metadata.rigProfile,
      'materialProfile': metadata.materialProfile,
      'overlayAssetUrl': metadata.overlayAssetUrl,
      'alignmentConfig': metadata.alignmentConfig,
      'measurements': measurements,
      'enableAvatar': enableAvatar,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: 'abzora/unity_try_on_view',
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: 'abzora/unity_try_on_view',
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      default:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Text(
              'Unity premium try-on is available on Android and iOS only.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }
}
