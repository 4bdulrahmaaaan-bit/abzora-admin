class BannerModel {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String ctaText;
  final String redirectType;
  final String redirectId;
  final int order;
  final bool isActive;

  const BannerModel({
    this.id = '',
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.redirectType,
    required this.redirectId,
    this.order = 0,
    this.isActive = true,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
      imageUrl: map['image']?.toString() ?? map['imageUrl']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      ctaText: map['ctaText']?.toString() ?? 'View Stores',
      redirectType: map['redirectType']?.toString() ?? 'store',
      redirectId: map['redirectId']?.toString() ?? '',
      order: int.tryParse(map['order']?.toString() ?? '') ?? 0,
      isActive: map['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'imageUrl': imageUrl,
      'image': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'ctaText': ctaText,
      'redirectType': redirectType,
      'redirectId': redirectId,
      'order': order,
      'isActive': isActive,
    };
  }

  BannerModel copyWith({
    String? id,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? ctaText,
    String? redirectType,
    String? redirectId,
    int? order,
    bool? isActive,
  }) {
    return BannerModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ctaText: ctaText ?? this.ctaText,
      redirectType: redirectType ?? this.redirectType,
      redirectId: redirectId ?? this.redirectId,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }
}

class HomeCategoryVisualModel {
  final String id;
  final String tab;
  final String label;
  final String imageUrl;
  final String icon;
  final int sortOrder;
  final bool isActive;

  const HomeCategoryVisualModel({
    this.id = '',
    this.tab = 'All',
    this.label = '',
    this.imageUrl = '',
    this.icon = 'category',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory HomeCategoryVisualModel.fromMap(Map<String, dynamic> map) {
    return HomeCategoryVisualModel(
      id: map['id']?.toString() ?? '',
      tab: map['tab']?.toString() ?? 'All',
      label: map['label']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      icon: map['icon']?.toString() ?? 'category',
      sortOrder: int.tryParse(map['sortOrder']?.toString() ?? '') ?? 0,
      isActive: map['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tab': tab,
      'label': label,
      'imageUrl': imageUrl,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  HomeCategoryVisualModel copyWith({
    String? id,
    String? tab,
    String? label,
    String? imageUrl,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) {
    return HomeCategoryVisualModel(
      id: id ?? this.id,
      tab: tab ?? this.tab,
      label: label ?? this.label,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}

class HomePromoBlockModel {
  final String id;
  final int slot;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaText;
  final String imageUrl;
  final String redirectType;
  final String redirectId;
  final int sortOrder;
  final bool isActive;

  const HomePromoBlockModel({
    this.id = '',
    this.slot = 1,
    this.eyebrow = '',
    this.title = '',
    this.subtitle = '',
    this.ctaText = 'Explore',
    this.imageUrl = '',
    this.redirectType = 'category',
    this.redirectId = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory HomePromoBlockModel.fromMap(Map<String, dynamic> map) {
    return HomePromoBlockModel(
      id: map['id']?.toString() ?? '',
      slot: int.tryParse(map['slot']?.toString() ?? '') ?? 1,
      eyebrow: map['eyebrow']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      ctaText: map['ctaText']?.toString() ?? 'Explore',
      imageUrl: map['imageUrl']?.toString() ?? '',
      redirectType: map['redirectType']?.toString() ?? 'category',
      redirectId: map['redirectId']?.toString() ?? '',
      sortOrder: int.tryParse(map['sortOrder']?.toString() ?? '') ?? 0,
      isActive: map['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slot': slot,
      'eyebrow': eyebrow,
      'title': title,
      'subtitle': subtitle,
      'ctaText': ctaText,
      'imageUrl': imageUrl,
      'redirectType': redirectType,
      'redirectId': redirectId,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  HomePromoBlockModel copyWith({
    String? id,
    int? slot,
    String? eyebrow,
    String? title,
    String? subtitle,
    String? ctaText,
    String? imageUrl,
    String? redirectType,
    String? redirectId,
    int? sortOrder,
    bool? isActive,
  }) {
    return HomePromoBlockModel(
      id: id ?? this.id,
      slot: slot ?? this.slot,
      eyebrow: eyebrow ?? this.eyebrow,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ctaText: ctaText ?? this.ctaText,
      imageUrl: imageUrl ?? this.imageUrl,
      redirectType: redirectType ?? this.redirectType,
      redirectId: redirectId ?? this.redirectId,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}

class HomeVisualConfigModel {
  final List<HomeCategoryVisualModel> categoryVisuals;
  final List<HomePromoBlockModel> promoBlocks;
  final String updatedAt;

  const HomeVisualConfigModel({
    this.categoryVisuals = const [],
    this.promoBlocks = const [],
    this.updatedAt = '',
  });

  factory HomeVisualConfigModel.fromMap(Map<String, dynamic> map) {
    return HomeVisualConfigModel(
      categoryVisuals: (map['categoryVisuals'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => HomeCategoryVisualModel.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder)),
      promoBlocks: (map['promoBlocks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => HomePromoBlockModel.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder)),
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryVisuals': categoryVisuals.map((item) => item.toMap()).toList(),
      'promoBlocks': promoBlocks.map((item) => item.toMap()).toList(),
    };
  }

  HomeVisualConfigModel copyWith({
    List<HomeCategoryVisualModel>? categoryVisuals,
    List<HomePromoBlockModel>? promoBlocks,
    String? updatedAt,
  }) {
    return HomeVisualConfigModel(
      categoryVisuals: categoryVisuals ?? this.categoryVisuals,
      promoBlocks: promoBlocks ?? this.promoBlocks,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
