import 'dart:ui';

import '../models/models.dart';
import 'pose_measurement_service.dart';

enum ArGarmentType {
  shirt,
  jacket,
  dress,
  top,
  pants,
  footwear,
  accessory,
}

class ArGarmentMetadata {
  const ArGarmentMetadata({
    required this.type,
    required this.anchorPoints,
    required this.fit,
    required this.widthMultiplier,
    required this.heightMultiplier,
    required this.verticalBias,
    required this.assetUrl,
    required this.prefersTransparentAsset,
  });

  final ArGarmentType type;
  final List<String> anchorPoints;
  final String fit;
  final double widthMultiplier;
  final double heightMultiplier;
  final double verticalBias;
  final String assetUrl;
  final bool prefersTransparentAsset;
}

class ArOverlayLayout {
  const ArOverlayLayout({
    required this.center,
    required this.size,
    required this.rotationRadians,
    required this.opacity,
    required this.usingFallbackArt,
  });

  final Offset center;
  final Size size;
  final double rotationRadians;
  final double opacity;
  final bool usingFallbackArt;

  static ArOverlayLayout lerp(
    ArOverlayLayout? previous,
    ArOverlayLayout next, {
    double t = 0.22,
  }) {
    if (previous == null) {
      return next;
    }
    return ArOverlayLayout(
      center: Offset.lerp(previous.center, next.center, t) ?? next.center,
      size: Size.lerp(previous.size, next.size, t) ?? next.size,
      rotationRadians: lerpDouble(
            previous.rotationRadians,
            next.rotationRadians,
            t,
          ) ??
          next.rotationRadians,
      opacity: lerpDouble(previous.opacity, next.opacity, t) ?? next.opacity,
      usingFallbackArt: next.usingFallbackArt,
    );
  }
}

class ArTryOnService {
  const ArTryOnService();

  ArGarmentMetadata metadataFor(Product product) {
    final descriptor =
        '${product.category} ${product.name} ${product.outfitType ?? ''}'
            .toLowerCase();
    final assetUrl = product.images.isNotEmpty ? product.images.first : '';
    if (descriptor.contains('jacket') ||
        descriptor.contains('hoodie') ||
        descriptor.contains('blazer')) {
      return ArGarmentMetadata(
        type: ArGarmentType.jacket,
        anchorPoints: const ['shoulder', 'waist'],
        fit: _fitFor(product),
        widthMultiplier: 1.48,
        heightMultiplier: 1.82,
        verticalBias: 0.1,
        assetUrl: assetUrl,
        prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
      );
    }
    if (descriptor.contains('dress') || descriptor.contains('kurta')) {
      return ArGarmentMetadata(
        type: ArGarmentType.dress,
        anchorPoints: const ['shoulder', 'hip'],
        fit: _fitFor(product),
        widthMultiplier: 1.5,
        heightMultiplier: 2.12,
        verticalBias: 0.18,
        assetUrl: assetUrl,
        prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
      );
    }
    if (descriptor.contains('jean') ||
        descriptor.contains('pant') ||
        descriptor.contains('trouser') ||
        descriptor.contains('chino') ||
        descriptor.contains('jogger') ||
        descriptor.contains('skirt')) {
      return ArGarmentMetadata(
        type: ArGarmentType.pants,
        anchorPoints: const ['hip', 'ankle'],
        fit: _fitFor(product),
        widthMultiplier: 1.2,
        heightMultiplier: 1.72,
        verticalBias: 0.72,
        assetUrl: assetUrl,
        prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
      );
    }
    if (descriptor.contains('shoe') ||
        descriptor.contains('sneaker') ||
        descriptor.contains('heel') ||
        descriptor.contains('loafer') ||
        descriptor.contains('sandal')) {
      return ArGarmentMetadata(
        type: ArGarmentType.footwear,
        anchorPoints: const ['ankle'],
        fit: _fitFor(product),
        widthMultiplier: 0.72,
        heightMultiplier: 0.4,
        verticalBias: 1.18,
        assetUrl: assetUrl,
        prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
      );
    }
    if (descriptor.contains('watch') ||
        descriptor.contains('belt') ||
        descriptor.contains('bag') ||
        descriptor.contains('cap')) {
      return ArGarmentMetadata(
        type: ArGarmentType.accessory,
        anchorPoints: const ['shoulder'],
        fit: _fitFor(product),
        widthMultiplier: 0.44,
        heightMultiplier: 0.34,
        verticalBias: 0.18,
        assetUrl: assetUrl,
        prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
      );
    }
    if (descriptor.contains('top') || descriptor.contains('blouse')) {
      return ArGarmentMetadata(
        type: ArGarmentType.top,
        anchorPoints: const ['shoulder', 'waist'],
        fit: _fitFor(product),
        widthMultiplier: 1.34,
        heightMultiplier: 1.56,
        verticalBias: 0.06,
        assetUrl: assetUrl,
        prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
      );
    }
    return ArGarmentMetadata(
      type: ArGarmentType.shirt,
      anchorPoints: const ['shoulder', 'waist'],
      fit: _fitFor(product),
      widthMultiplier: 1.4,
      heightMultiplier: 1.68,
      verticalBias: 0.08,
      assetUrl: assetUrl,
      prefersTransparentAsset: assetUrl.toLowerCase().endsWith('.png'),
    );
  }

  ArOverlayLayout buildLayout({
    required Size canvasSize,
    required Rect guideRect,
    required TryOnPoseFrame? frame,
    required ArGarmentMetadata metadata,
    required double fitAdjustment,
    ArOverlayLayout? previous,
  }) {
    if (frame == null) {
      final fallbackCenter = Offset(
        guideRect.center.dx,
        guideRect.top + (guideRect.height * 0.34),
      );
      final fallback = ArOverlayLayout(
        center: fallbackCenter,
        size: Size(guideRect.width * 0.56, guideRect.height * 0.46),
        rotationRadians: 0,
        opacity: 0.54,
        usingFallbackArt: true,
      );
      return ArOverlayLayout.lerp(previous, fallback, t: 0.18);
    }

    final shoulderCenter = Offset(
      guideRect.left + (guideRect.width * frame.shoulderCenter.x),
      guideRect.top + (guideRect.height * frame.shoulderCenter.y),
    );
    final hipCenter = Offset(
      guideRect.left + (guideRect.width * frame.hipCenter.x),
      guideRect.top + (guideRect.height * frame.hipCenter.y),
    );
    final torsoMidpoint = Offset.lerp(
          shoulderCenter,
          hipCenter,
          0.5,
        ) ??
        guideRect.center;
    final anchorCenter = switch (metadata.type) {
      ArGarmentType.pants => hipCenter,
      ArGarmentType.footwear => hipCenter,
      ArGarmentType.accessory => shoulderCenter,
      _ => shoulderCenter,
    };
    final center = Offset.lerp(
          anchorCenter,
          torsoMidpoint,
          (0.16 + metadata.verticalBias).clamp(0.0, 0.9),
        ) ??
        anchorCenter;
    final fitScale = 1 + fitAdjustment;
    final width = (guideRect.width *
            frame.shoulderWidth *
            metadata.widthMultiplier *
            fitScale)
        .clamp(guideRect.width * 0.24, guideRect.width * 0.92);
    final height = (guideRect.height *
            frame.torsoHeight *
            metadata.heightMultiplier *
            fitScale)
        .clamp(guideRect.height * 0.2, guideRect.height * 0.9);
    final next = ArOverlayLayout(
      center: center,
      size: Size(width, height),
      rotationRadians: frame.rotationRadians,
      opacity: frame.feedback.isAligned ? 0.92 : 0.78,
      usingFallbackArt: !metadata.prefersTransparentAsset,
    );
    return ArOverlayLayout.lerp(previous, next);
  }

  String _fitFor(Product product) {
    final descriptor =
        '${product.name} ${product.description} ${product.outfitType ?? ''}'
            .toLowerCase();
    if (descriptor.contains('oversized')) {
      return 'oversized';
    }
    if (descriptor.contains('slim')) {
      return 'slim';
    }
    return 'regular';
  }
}
