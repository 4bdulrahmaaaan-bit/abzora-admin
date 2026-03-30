class BannerModel {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String ctaText;
  final String redirectType;
  final String redirectId;

  const BannerModel({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.redirectType,
    required this.redirectId,
  });
}
