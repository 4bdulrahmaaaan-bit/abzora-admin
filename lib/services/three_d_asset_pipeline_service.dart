import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';
import 'local_cache_service.dart';

class ThreeDGarmentAsset {
  const ThreeDGarmentAsset({
    required this.id,
    required this.model,
    required this.category,
    required this.fit,
    required this.sizeScale,
  });

  final String id;
  final String model;
  final String category;
  final String fit;
  final Map<String, double> sizeScale;

  factory ThreeDGarmentAsset.fromMap(Map<String, dynamic> map) {
    final rawScale = Map<String, dynamic>.from(map['sizeScale'] ?? const {});
    return ThreeDGarmentAsset(
      id: map['id']?.toString().trim() ?? '',
      model: map['model']?.toString().trim() ?? '',
      category: map['category']?.toString().trim().toLowerCase() ?? '',
      fit: map['fit']?.toString().trim().toLowerCase() ?? 'regular',
      sizeScale: rawScale.map(
        (key, value) => MapEntry(
          key.toString().toUpperCase(),
          (value as num?)?.toDouble() ?? 1.0,
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'model': model,
      'category': category,
      'fit': fit,
      'sizeScale': sizeScale,
    };
  }
}

class ThreeDAssetResolution {
  const ThreeDAssetResolution({
    required this.modelUrl,
    required this.scaleForSize,
    required this.fallbackImageUrl,
    required this.source,
  });

  final String modelUrl;
  final double scaleForSize;
  final String fallbackImageUrl;
  final String source;

  bool get hasModel => modelUrl.isNotEmpty;
}

class ThreeDAssetPipelineService {
  ThreeDAssetPipelineService._();
  static final ThreeDAssetPipelineService instance =
      ThreeDAssetPipelineService._();

  static const String _manifestAssetPath = 'assets/3d/asset_manifest.json';
  static const String _manifestCacheKey = '3d_asset_manifest';

  final LocalCacheService _cache = LocalCacheService();
  final Map<String, ThreeDGarmentAsset> _assetByKey =
      <String, ThreeDGarmentAsset>{};
  bool _loaded = false;

  Future<void> warmup() async {
    if (_loaded) {
      return;
    }
    final loaded = await _loadManifestFromBundle();
    if (!loaded) {
      await _loadManifestFromCache();
    }
    _loaded = true;
  }

  Future<ThreeDAssetResolution> resolveForProduct(
    Product product, {
    String preferredSize = 'M',
  }) async {
    await warmup();
    final fallbackImage = product.images.isEmpty ? '' : product.images.first;
    final direct = (product.model3d ?? '').trim();
    if (direct.isNotEmpty) {
      final matched = _findAssetByToken(direct);
      if (matched != null) {
        return ThreeDAssetResolution(
          modelUrl: _normalizeModelPath(matched.model),
          scaleForSize: _scaleForSize(matched, preferredSize),
          fallbackImageUrl: fallbackImage,
          source: 'manifest-id',
        );
      }
      return ThreeDAssetResolution(
        modelUrl: _normalizeModelPath(direct),
        scaleForSize: 1.0,
        fallbackImageUrl: fallbackImage,
        source: 'product-model3d',
      );
    }

    final categoryKey = _normalizeCategory(product);
    final fit =
        (product.attributes['fit_type'] ??
                product.attributes['fit'] ??
                'regular')
            .trim()
            .toLowerCase();
    final byCategory = _assetByKey.values
        .where((asset) => asset.category == categoryKey)
        .toList();
    final candidate = byCategory.firstWhere(
      (asset) => asset.fit == fit,
      orElse: () => byCategory.isNotEmpty
          ? byCategory.first
          : const ThreeDGarmentAsset(
              id: '',
              model: '',
              category: '',
              fit: 'regular',
              sizeScale: <String, double>{},
            ),
    );

    if (candidate.model.isNotEmpty) {
      return ThreeDAssetResolution(
        modelUrl: _normalizeModelPath(candidate.model),
        scaleForSize: _scaleForSize(candidate, preferredSize),
        fallbackImageUrl: fallbackImage,
        source: 'category-default',
      );
    }

    return ThreeDAssetResolution(
      modelUrl: '',
      scaleForSize: 1.0,
      fallbackImageUrl: fallbackImage,
      source: 'fallback-image',
    );
  }

  Future<bool> _loadManifestFromBundle() async {
    try {
      final raw = await rootBundle.loadString(_manifestAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      _hydrate(decoded);
      await _cache.saveJson(_manifestCacheKey, decoded);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadManifestFromCache() async {
    final cached = await _cache.readJson(_manifestCacheKey);
    if (cached == null) {
      return;
    }
    _hydrate(cached);
  }

  void _hydrate(Map<String, dynamic> manifest) {
    final items = (manifest['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (entry) =>
              ThreeDGarmentAsset.fromMap(Map<String, dynamic>.from(entry)),
        )
        .where((item) => item.id.isNotEmpty && item.model.isNotEmpty)
        .toList();
    _assetByKey
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id.toLowerCase(), item)))
      ..addEntries(
        items.map((item) => MapEntry(item.model.toLowerCase(), item)),
      );
  }

  ThreeDGarmentAsset? _findAssetByToken(String token) {
    final normalized = token.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return _assetByKey[normalized];
  }

  String _normalizeModelPath(String value) {
    final model = value.trim();
    if (model.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(model);
    if (uri != null && uri.hasScheme) {
      return model;
    }
    if (model.startsWith('assets/')) {
      return model;
    }
    return 'assets/3d/$model';
  }

  String _normalizeCategory(Product product) {
    final raw =
        (product.subcategory.isNotEmpty
                ? product.subcategory
                : product.category)
            .toLowerCase();
    if (raw.contains('shoe') || raw.contains('sneaker')) {
      return 'footwear';
    }
    if (raw.contains('pant') ||
        raw.contains('trouser') ||
        raw.contains('jean')) {
      return 'bottomwear';
    }
    if (raw.contains('jacket') || raw.contains('hoodie')) {
      return 'outerwear';
    }
    if (raw.contains('shirt') ||
        raw.contains('top') ||
        raw.contains('kurta') ||
        raw.contains('dress')) {
      return 'topwear';
    }
    return 'topwear';
  }

  double _scaleForSize(ThreeDGarmentAsset asset, String preferredSize) {
    final size = preferredSize.trim().toUpperCase();
    return asset.sizeScale[size] ?? asset.sizeScale['M'] ?? 1.0;
  }
}
