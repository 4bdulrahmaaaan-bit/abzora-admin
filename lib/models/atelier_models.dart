class AtelierDesigner {
  const AtelierDesigner({
    required this.id,
    required this.name,
    required this.city,
    required this.rating,
    required this.priceBand,
    required this.tags,
    required this.bannerUrl,
  });

  final String id;
  final String name;
  final String city;
  final double rating;
  final String priceBand;
  final List<String> tags;
  final String bannerUrl;
}

class AtelierCategory {
  const AtelierCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
}

class FabricOption {
  const FabricOption({
    required this.id,
    required this.name,
    required this.tags,
    required this.description,
    required this.priceDelta,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final List<String> tags;
  final String description;
  final int priceDelta;
  final String imageUrl;
}

class StyleOptionGroup {
  const StyleOptionGroup({
    required this.id,
    required this.title,
    required this.options,
  });

  final String id;
  final String title;
  final List<StyleOption> options;
}

class StyleOption {
  const StyleOption({
    required this.id,
    required this.title,
    this.priceDelta = 0,
  });

  final String id;
  final String title;
  final int priceDelta;
}

class FitOption {
  const FitOption({
    required this.id,
    required this.label,
    required this.description,
    required this.iconKey,
    this.priceDelta = 0,
  });

  final String id;
  final String label;
  final String description;
  final String iconKey;
  final int priceDelta;
}

class MeasurementOption {
  const MeasurementOption({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    this.priceDelta = 0,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final int priceDelta;
}
