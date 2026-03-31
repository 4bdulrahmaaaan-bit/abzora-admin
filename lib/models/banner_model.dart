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
