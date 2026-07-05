import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/banner_model.dart';
import '../services/backend_commerce_service.dart';

class BannerProvider with ChangeNotifier {
  BannerProvider({BackendCommerceService? commerce})
    : _commerce = commerce ?? BackendCommerceService() {
    unawaited(loadBanners());
  }

  final BackendCommerceService _commerce;

  List<BannerModel> _banners = const [];
  List<BannerModel> _lastSuccessfulBanners = const [];
  int _activeIndex = 0;
  bool _isLoading = false;

  List<BannerModel> get banners => _banners;
  int get activeIndex => _activeIndex;
  bool get isLoading => _isLoading;

  Future<void> loadBanners({bool forceRefresh = false}) async {
    if (_isLoading) {
      return;
    }
    if (!forceRefresh && _banners.isNotEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (!_commerce.isConfigured) {
        if (_banners.isEmpty) {
          _banners = const [];
          _activeIndex = 0;
        }
        return;
      }

      final banners = await _commerce.getBanners();
      final visibleBanners = banners
          .where((banner) => banner.imageUrl.trim().isNotEmpty)
          .toList(growable: false);
      if (visibleBanners.isNotEmpty) {
        _lastSuccessfulBanners = List<BannerModel>.unmodifiable(visibleBanners);
        _banners = _lastSuccessfulBanners;
        _activeIndex = _activeIndex.clamp(0, _banners.length - 1);
      } else if (_banners.isEmpty && _lastSuccessfulBanners.isNotEmpty) {
        _banners = _lastSuccessfulBanners;
        _activeIndex = _activeIndex.clamp(0, _banners.length - 1);
      } else if (_banners.isEmpty) {
        _banners = const [];
        _activeIndex = 0;
      }
    } catch (_) {
      if (_banners.isEmpty && _lastSuccessfulBanners.isNotEmpty) {
        _banners = _lastSuccessfulBanners;
        _activeIndex = _activeIndex.clamp(0, _banners.length - 1);
      } else if (_banners.isEmpty) {
        _banners = const [];
        _activeIndex = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setActiveIndex(int index) {
    if (_banners.isEmpty) {
      return;
    }
    final normalized = index % _banners.length;
    if (_activeIndex == normalized) {
      return;
    }
    _activeIndex = normalized;
    notifyListeners();
  }
}
