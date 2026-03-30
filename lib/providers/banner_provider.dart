import 'package:flutter/foundation.dart';

import '../models/banner_model.dart';

class BannerProvider with ChangeNotifier {
  BannerProvider() {
    loadBanners();
  }

  static const List<BannerModel> _seedBanners = [
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=1400&q=80',
      title: 'Elevate Your Style',
      subtitle: 'Premium looks near you',
      ctaText: 'Shop Now',
      redirectType: 'category',
      redirectId: 'Men',
    ),
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=1400&q=80',
      title: 'Wedding edits worth arriving for',
      subtitle: 'Celebrate every moment in statement silhouettes',
      ctaText: 'Discover',
      redirectType: 'category',
      redirectId: 'Wedding',
    ),
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1523398002811-999ca8dec234?w=1400&q=80',
      title: 'Top-rated stores around you',
      subtitle: 'Handpicked fashion destinations from your city',
      ctaText: 'View Stores',
      redirectType: 'store',
      redirectId: '',
    ),
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=1400&q=80',
      title: 'Custom fits, made for you',
      subtitle: 'Precision tailoring with a premium finish',
      ctaText: 'Start Custom Order',
      redirectType: 'category',
      redirectId: 'Custom Clothing',
    ),
  ];

  List<BannerModel> _banners = const [];
  int _activeIndex = 0;
  bool _isLoading = true;

  List<BannerModel> get banners => _banners;
  int get activeIndex => _activeIndex;
  bool get isLoading => _isLoading;

  Future<void> loadBanners() async {
    _isLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _banners = List<BannerModel>.unmodifiable(_seedBanners);
    _activeIndex = 0;
    _isLoading = false;
    notifyListeners();
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
