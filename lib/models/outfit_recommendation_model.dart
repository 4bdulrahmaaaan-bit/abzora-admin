import 'models.dart';

class OutfitRecommendation {
  const OutfitRecommendation({
    required this.outfitId,
    required this.title,
    required this.items,
    required this.totalPrice,
    required this.matchScore,
    this.occasion = '',
    this.style = '',
    this.reasoning = '',
  });

  final String outfitId;
  final String title;
  final List<Product> items;
  final double totalPrice;
  final int matchScore;
  final String occasion;
  final String style;
  final String reasoning;

  factory OutfitRecommendation.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return OutfitRecommendation(
      outfitId: (map['outfitId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      items: rawItems
          .map(
            (item) => Product.fromMap(
              {
                'storeId': item['storeId'],
                'name': item['name'],
                'brand': item['brand'] ?? '',
                'description': item['description'] ?? '',
                'price': item['price'] ?? 0,
                'basePrice': item['basePrice'],
                'dynamicPrice': item['dynamicPrice'],
                'originalPrice': item['originalPrice'],
                'demandScore': item['demandScore'] ?? 0,
                'viewCount': item['viewCount'] ?? 0,
                'cartCount': item['cartCount'] ?? 0,
                'purchaseCount': item['purchaseCount'] ?? 0,
                'images': item['images'] ?? [item['image']].whereType<String>().toList(),
                'sizes': item['sizes'] ?? const ['S', 'M', 'L'],
                'stock': item['stock'] ?? 0,
                'category': item['category'] ?? '',
                'isActive': item['isActive'] ?? true,
                'createdAt': item['createdAt'],
                'rating': item['rating'] ?? 0,
                'reviewCount': item['reviewCount'] ?? 0,
                'outfitType': item['outfitType'],
                'fabric': item['fabric'],
              },
              (item['productId'] ?? item['id'] ?? '').toString(),
            ),
          )
          .toList(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      matchScore: (map['matchScore'] ?? 0) is num
          ? (map['matchScore'] as num).round()
          : int.tryParse((map['matchScore'] ?? '0').toString()) ?? 0,
      occasion: (map['occasion'] ?? '').toString(),
      style: (map['style'] ?? '').toString(),
      reasoning: (map['reasoning'] ?? '').toString(),
    );
  }
}
