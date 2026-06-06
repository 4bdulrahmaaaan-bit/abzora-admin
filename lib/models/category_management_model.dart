class CategoryManagementModel {
  const CategoryManagementModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.bannerImage,
    required this.description,
    required this.parentId,
    required this.parentName,
    required this.sortOrder,
    required this.isFeatured,
    required this.isActive,
    required this.showOnHome,
    required this.tabType,
    required this.seoTitle,
    required this.seoDescription,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.subcategories,
  });

  final String id;
  final String name;
  final String slug;
  final String image;
  final String bannerImage;
  final String description;
  final String parentId;
  final String parentName;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;
  final bool showOnHome;
  final String tabType;
  final String seoTitle;
  final String seoDescription;
  final String createdAt;
  final String updatedAt;
  final String deletedAt;
  final List<SubcategoryManagementModel> subcategories;

  bool get hasParent => parentId.trim().isNotEmpty;

  factory CategoryManagementModel.fromMap(Map<String, dynamic> map) {
    final subcategories = ((map['subcategories'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => SubcategoryManagementModel.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

    return CategoryManagementModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      image: map['image']?.toString() ?? map['icon']?.toString() ?? '',
      bannerImage: map['bannerImage']?.toString() ?? map['bannerImageUrl']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      parentId: map['parentId']?.toString() ?? map['parent_id']?.toString() ?? '',
      parentName: map['parentName']?.toString() ?? '',
      sortOrder: int.tryParse(map['sortOrder']?.toString() ?? map['order']?.toString() ?? '') ?? 0,
      isFeatured: map['isFeatured'] == true || map['featured'] == true,
      isActive: map['isActive'] != false,
      showOnHome: map['showOnHome'] == true,
      tabType: map['tabType']?.toString() ?? 'All',
      seoTitle: map['seoTitle']?.toString() ?? '',
      seoDescription: map['seoDescription']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
      deletedAt: map['deletedAt']?.toString() ?? '',
      subcategories: subcategories,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'image': image,
      'icon': image,
      'bannerImage': bannerImage,
      'bannerImageUrl': bannerImage,
      'parentId': parentId.isEmpty ? null : parentId,
      'sortOrder': sortOrder,
      'order': sortOrder,
      'isFeatured': isFeatured,
      'featured': isFeatured,
      'isActive': isActive,
      'showOnHome': showOnHome,
      'tabType': tabType,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
    }..removeWhere((key, value) => value == null);
  }

  CategoryManagementModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? image,
    String? bannerImage,
    String? description,
    String? parentId,
    String? parentName,
    int? sortOrder,
    bool? isFeatured,
    bool? isActive,
    bool? showOnHome,
    String? tabType,
    String? seoTitle,
    String? seoDescription,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    List<SubcategoryManagementModel>? subcategories,
  }) {
    return CategoryManagementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      image: image ?? this.image,
      bannerImage: bannerImage ?? this.bannerImage,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      sortOrder: sortOrder ?? this.sortOrder,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      showOnHome: showOnHome ?? this.showOnHome,
      tabType: tabType ?? this.tabType,
      seoTitle: seoTitle ?? this.seoTitle,
      seoDescription: seoDescription ?? this.seoDescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      subcategories: subcategories ?? this.subcategories,
    );
  }
}

class SubcategoryManagementModel {
  const SubcategoryManagementModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final String image;
  final int sortOrder;
  final bool isActive;

  factory SubcategoryManagementModel.fromMap(Map<String, dynamic> map) {
    return SubcategoryManagementModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      image: map['image']?.toString() ?? map['icon']?.toString() ?? '',
      sortOrder: int.tryParse(map['sortOrder']?.toString() ?? map['order']?.toString() ?? '') ?? 0,
      isActive: map['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'image': image,
      'icon': image,
      'sortOrder': sortOrder,
      'order': sortOrder,
      'isActive': isActive,
    };
  }

  SubcategoryManagementModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? image,
    int? sortOrder,
    bool? isActive,
  }) {
    return SubcategoryManagementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      image: image ?? this.image,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}

class CategoryManagementPage {
  const CategoryManagementPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
  });

  final List<CategoryManagementModel> items;
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  factory CategoryManagementPage.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['data'] as List? ?? map['items'] as List? ?? const []);
    final meta = map['meta'] is Map
        ? Map<String, dynamic>.from(map['meta'] as Map)
        : const <String, dynamic>{};
    return CategoryManagementPage(
      items: rawItems
          .whereType<Map>()
          .map((item) => CategoryManagementModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      page: int.tryParse((meta['page'] ?? map['page'])?.toString() ?? '') ?? 1,
      limit: int.tryParse((meta['limit'] ?? map['limit'])?.toString() ?? '') ?? 20,
      totalCount: int.tryParse((meta['totalCount'] ?? map['totalCount'] ?? map['total'])?.toString() ?? '') ?? rawItems.length,
      totalPages: int.tryParse((meta['totalPages'] ?? map['totalPages'])?.toString() ?? '') ?? 1,
    );
  }
}
