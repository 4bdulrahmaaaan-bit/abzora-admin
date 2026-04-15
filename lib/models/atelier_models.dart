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
  });

  final String id;
  final String title;
  final String subtitle;
}

class FabricOption {
  const FabricOption({
    required this.id,
    required this.name,
    required this.tags,
    required this.description,
    required this.priceDelta,
  });

  final String id;
  final String name;
  final List<String> tags;
  final String description;
  final int priceDelta;
}

class DesignOptionGroup {
  const DesignOptionGroup({
    required this.id,
    required this.title,
    required this.options,
  });

  final String id;
  final String title;
  final List<DesignOption> options;
}

class DesignOption {
  const DesignOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.priceDelta,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final int priceDelta;
}

class MeasurementData {
  const MeasurementData({
    this.chest = '',
    this.waist = '',
    this.hips = '',
    this.shoulder = '',
    this.height = '',
  });

  final String chest;
  final String waist;
  final String hips;
  final String shoulder;
  final String height;

  MeasurementData copyWith({
    String? chest,
    String? waist,
    String? hips,
    String? shoulder,
    String? height,
  }) {
    return MeasurementData(
      chest: chest ?? this.chest,
      waist: waist ?? this.waist,
      hips: hips ?? this.hips,
      shoulder: shoulder ?? this.shoulder,
      height: height ?? this.height,
    );
  }
}
