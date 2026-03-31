class CategoryManagementModel {
  const CategoryManagementModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.order,
    required this.isActive,
    required this.subcategories,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final int order;
  final bool isActive;
  final List<SubcategoryManagementModel> subcategories;

  factory CategoryManagementModel.fromMap(Map<String, dynamic> map) {
    final subcategories = ((map['subcategories'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => SubcategoryManagementModel.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));

    return CategoryManagementModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '',
      order: int.tryParse(map['order']?.toString() ?? '') ?? 0,
      isActive: map['isActive'] != false,
      subcategories: subcategories,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'icon': icon,
      'order': order,
      'isActive': isActive,
    };
  }

  CategoryManagementModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? icon,
    int? order,
    bool? isActive,
    List<SubcategoryManagementModel>? subcategories,
  }) {
    return CategoryManagementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      subcategories: subcategories ?? this.subcategories,
    );
  }
}

class SubcategoryManagementModel {
  const SubcategoryManagementModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.order,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final int order;
  final bool isActive;

  factory SubcategoryManagementModel.fromMap(Map<String, dynamic> map) {
    return SubcategoryManagementModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '',
      order: int.tryParse(map['order']?.toString() ?? '') ?? 0,
      isActive: map['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'icon': icon,
      'order': order,
      'isActive': isActive,
    };
  }

  SubcategoryManagementModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? icon,
    int? order,
    bool? isActive,
  }) {
    return SubcategoryManagementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }
}
