class CmsEntryModel {
  const CmsEntryModel({
    required this.id,
    required this.type,
    required this.title,
    required this.slug,
    required this.category,
    required this.summary,
    required this.content,
    required this.image,
    required this.linkUrl,
    required this.linkLabel,
    required this.section,
    required this.sortOrder,
    required this.isFeatured,
    required this.isActive,
    required this.seoTitle,
    required this.seoDescription,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String title;
  final String slug;
  final String category;
  final String summary;
  final String content;
  final String image;
  final String linkUrl;
  final String linkLabel;
  final String section;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;
  final String seoTitle;
  final String seoDescription;
  final String publishedAt;
  final String createdAt;
  final String updatedAt;

  bool get isPublished => publishedAt.isNotEmpty;

  factory CmsEntryModel.fromMap(Map<String, dynamic> map) {
    return CmsEntryModel(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'page',
      title: map['title']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
      linkUrl: map['linkUrl']?.toString() ?? '',
      linkLabel: map['linkLabel']?.toString() ?? '',
      section: map['section']?.toString() ?? '',
      sortOrder: int.tryParse(map['sortOrder']?.toString() ?? '') ?? 0,
      isFeatured: map['isFeatured'] == true,
      isActive: map['isActive'] != false,
      seoTitle: map['seoTitle']?.toString() ?? '',
      seoDescription: map['seoDescription']?.toString() ?? '',
      publishedAt: map['publishedAt']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'slug': slug,
      'category': category,
      'summary': summary,
      'content': content,
      'image': image,
      'imageUrl': image,
      'linkUrl': linkUrl,
      'linkLabel': linkLabel,
      'section': section,
      'sortOrder': sortOrder,
      'isFeatured': isFeatured,
      'isActive': isActive,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
      'publishedAt': publishedAt,
    };
  }

  CmsEntryModel copyWith({
    String? id,
    String? type,
    String? title,
    String? slug,
    String? category,
    String? summary,
    String? content,
    String? image,
    String? linkUrl,
    String? linkLabel,
    String? section,
    int? sortOrder,
    bool? isFeatured,
    bool? isActive,
    String? seoTitle,
    String? seoDescription,
    String? publishedAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return CmsEntryModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      image: image ?? this.image,
      linkUrl: linkUrl ?? this.linkUrl,
      linkLabel: linkLabel ?? this.linkLabel,
      section: section ?? this.section,
      sortOrder: sortOrder ?? this.sortOrder,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      seoTitle: seoTitle ?? this.seoTitle,
      seoDescription: seoDescription ?? this.seoDescription,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CmsEntryPage {
  const CmsEntryPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
  });

  final List<CmsEntryModel> items;
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  factory CmsEntryPage.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['data'] as List? ?? const []);
    final meta = map['meta'] is Map
        ? Map<String, dynamic>.from(map['meta'] as Map)
        : const <String, dynamic>{};
    return CmsEntryPage(
      items: rawItems
          .whereType<Map>()
          .map((item) => CmsEntryModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      page: int.tryParse((meta['page'] ?? map['page'])?.toString() ?? '') ?? 1,
      limit:
          int.tryParse((meta['limit'] ?? map['limit'])?.toString() ?? '') ?? 20,
      totalCount:
          int.tryParse(
            (meta['totalCount'] ?? map['totalCount'])?.toString() ?? '',
          ) ??
          rawItems.length,
      totalPages:
          int.tryParse(
            (meta['totalPages'] ?? map['totalPages'])?.toString() ?? '',
          ) ??
          1,
    );
  }
}
