
enum DeliveryMode {
  tryAtHome,
  localDelivery,
  courierDelivery,
  unavailable,
}

class ProductServiceability {
  const ProductServiceability({
    required this.supportsTryAtHome,
    required this.supportsInstantDelivery,
    required this.supportsCourierDelivery,
    required this.isDeliverable,
    required this.estimatedDeliveryDate,
    required this.estimatedInstantDeliveryTime,
    required this.shippingCharge,
    required this.deliveryPartner,
    required this.deliveryProvider,
    required this.deliveryMode,
    required this.serviceZoneId,
    required this.zoneId,
    required this.city,
    required this.pincode,
    required this.etaLabel,
    required this.etaMinutes,
    required this.distanceKm,
    required this.reason,
  });

  final bool supportsTryAtHome;
  final bool supportsInstantDelivery;
  final bool supportsCourierDelivery;
  final bool isDeliverable;
  final String estimatedDeliveryDate;
  final String estimatedInstantDeliveryTime;
  final double shippingCharge;
  final String deliveryPartner;
  final String deliveryProvider;
  final DeliveryMode deliveryMode;
  final String serviceZoneId;
  final String zoneId;
  final String city;
  final String pincode;
  final String etaLabel;
  final int etaMinutes;
  final double? distanceKm;
  final String reason;

  bool get canTryAtHome => supportsTryAtHome && isDeliverable;
  bool get canGetItToday => supportsInstantDelivery && isDeliverable;
  bool get canCourier => supportsCourierDelivery && isDeliverable;

  factory ProductServiceability.fromMap(Map<String, dynamic> map) {
    DeliveryMode parseMode(String value) {
      switch (value.trim().toUpperCase()) {
        case 'TRY_AT_HOME':
          return DeliveryMode.tryAtHome;
        case 'LOCAL_DELIVERY':
          return DeliveryMode.localDelivery;
        case 'COURIER_DELIVERY':
          return DeliveryMode.courierDelivery;
        default:
          return DeliveryMode.unavailable;
      }
    }

    return ProductServiceability(
      supportsTryAtHome: map['supportsTryAtHome'] == true,
      supportsInstantDelivery: map['supportsInstantDelivery'] == true,
      supportsCourierDelivery: map['supportsCourierDelivery'] == true,
      isDeliverable: map['isDeliverable'] == true || map['available'] == true,
      estimatedDeliveryDate: map['estimatedDeliveryDate']?.toString() ?? '',
      estimatedInstantDeliveryTime:
          map['estimatedInstantDeliveryTime']?.toString() ?? '',
      shippingCharge: (map['shippingCharge'] as num?)?.toDouble() ?? 0,
      deliveryPartner: map['deliveryPartner']?.toString() ?? '',
      deliveryProvider: map['deliveryProvider']?.toString() ?? '',
      deliveryMode: parseMode(map['deliveryMode']?.toString() ?? ''),
      serviceZoneId: map['serviceZoneId']?.toString() ?? '',
      zoneId: map['zoneId']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      etaLabel: map['eta']?.toString() ?? '',
      etaMinutes: (map['eta_minutes'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      reason: map['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'supportsTryAtHome': supportsTryAtHome,
        'supportsInstantDelivery': supportsInstantDelivery,
        'supportsCourierDelivery': supportsCourierDelivery,
        'isDeliverable': isDeliverable,
        'estimatedDeliveryDate': estimatedDeliveryDate,
        'estimatedInstantDeliveryTime': estimatedInstantDeliveryTime,
        'shippingCharge': shippingCharge,
        'deliveryPartner': deliveryPartner,
        'deliveryProvider': deliveryProvider,
        'deliveryMode': deliveryMode.name.toUpperCase(),
        'serviceZoneId': serviceZoneId,
        'zoneId': zoneId,
        'city': city,
        'pincode': pincode,
        'eta': etaLabel,
        'eta_minutes': etaMinutes,
        'distance_km': distanceKm,
        'reason': reason,
      };
}
