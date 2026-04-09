import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ar_try_on_models.dart';

class ArNativeTryOnView extends StatelessWidget {
  const ArNativeTryOnView({
    super.key,
    required this.metadata,
  });

  final ArTryOnProductMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'productId': metadata.id,
      'overlayAssetUrl': metadata.overlayAssetUrl,
      'transparentAssetUrl': metadata.transparentAssetUrl,
      'model3dUrl': metadata.model3dUrl,
      'alignmentConfig': metadata.alignmentConfig,
      'arAsset': metadata.arAsset,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: 'abzora/native_ar_try_on_view',
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: 'abzora/native_ar_try_on_view',
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
              'Native AR preview is available on Android and iOS only.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }
}
