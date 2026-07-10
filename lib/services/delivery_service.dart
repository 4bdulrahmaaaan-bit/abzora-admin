import '../models/models.dart';
import '../models/delivery_serviceability.dart';
import 'backend_commerce_service.dart';

class DeliveryService {
  DeliveryService({BackendCommerceService? backendCommerceService})
    : _backend = backendCommerceService ?? BackendCommerceService();

  final BackendCommerceService _backend;

  Future<ProductServiceability> getServiceability({
    required Product product,
    required UserAddress address,
  }) {
    return _resolveServiceability(product: product, address: address);
  }

  static String getMaxDeliveryEstimate(List<ProductServiceability> serviceabilities) {
    if (serviceabilities.isEmpty) return '';
    if (serviceabilities.any((s) => !s.isDeliverable)) return 'Not Deliverable';

    DateTime maxDate = DateTime.now();
    String? maxDateLabel;

    for (final serviceability in serviceabilities) {
      if (serviceability.estimatedDeliveryDate.isEmpty) continue;
      final parsed = DateTime.tryParse(serviceability.estimatedDeliveryDate);
      if (parsed != null && parsed.isAfter(maxDate)) {
        maxDate = parsed;
        maxDateLabel = serviceability.estimatedDeliveryDate;
      }
    }

    if (maxDateLabel != null) {
      return maxDateLabel;
    }
    
    // If we only have relative strings like '2-4 days', just use a fallback or the first non-empty.
    final firstValid = serviceabilities.firstWhere((s) => s.estimatedDeliveryDate.isNotEmpty, orElse: () => serviceabilities.first);
    return firstValid.estimatedDeliveryDate;
  }

  Future<ProductServiceability> _resolveServiceability({
    required Product product,
    required UserAddress address,
  }) async {
    final resolvedCity = _resolveCity(address);
    final resolvedLocality = address.locality.trim();
    try {
      if (_backend.isConfigured &&
          (address.latitude != null ||
              address.longitude != null ||
              address.pincode.trim().isNotEmpty ||
              resolvedCity.isNotEmpty ||
              resolvedLocality.isNotEmpty ||
              address.state.trim().isNotEmpty)) {
        final payload = await _backend.getProductServiceability(
          productId: product.id,
          latitude: address.latitude,
          longitude: address.longitude,
          pincode: address.pincode,
          locality: resolvedLocality,
          city: resolvedCity,
          state: address.state,
        );
        return ProductServiceability.fromMap(payload);
      }
    } catch (_) {
      if (_backend.isConfigured) {
        rethrow;
      }
    }

    if (_backend.isConfigured) {
      throw StateError('Delivery availability could not be resolved.');
    }

    final hasAddressSignal =
        address.latitude != null ||
        address.longitude != null ||
        address.pincode.trim().isNotEmpty ||
        resolvedCity.isNotEmpty ||
        resolvedLocality.isNotEmpty ||
        address.state.trim().isNotEmpty;
    final supportsTryAtHome = product.tryAtHomeAvailable;
    final supportsInstantDelivery = product.sameDayAvailable;
    final supportsCourierDelivery = hasAddressSignal && product.stock > 0;
    final deliverable =
        product.stock > 0 &&
        (supportsTryAtHome || supportsInstantDelivery || supportsCourierDelivery);
    final fallbackMode = supportsTryAtHome
        ? DeliveryMode.tryAtHome
        : supportsInstantDelivery
        ? DeliveryMode.localDelivery
        : supportsCourierDelivery
        ? DeliveryMode.courierDelivery
        : DeliveryMode.unavailable;
    final etaLabel = supportsTryAtHome || supportsInstantDelivery
        ? 'Today'
        : supportsCourierDelivery
        ? '2-3 days'
        : '';

    return ProductServiceability(
      supportsTryAtHome: supportsTryAtHome && deliverable,
      supportsInstantDelivery: supportsInstantDelivery && deliverable,
      supportsCourierDelivery: supportsCourierDelivery && deliverable,
      isDeliverable: deliverable,
      estimatedDeliveryDate: supportsTryAtHome || supportsInstantDelivery
          ? DateTime.now().toIso8601String().split('T').first
          : etaLabel.isNotEmpty
          ? etaLabel
          : '',
      estimatedInstantDeliveryTime:
          supportsTryAtHome || supportsInstantDelivery ? 'Today' : '',
      shippingCharge: supportsCourierDelivery ? 40 : 0,
      deliveryPartner: supportsTryAtHome || supportsInstantDelivery
          ? 'Local Rider'
          : '',
      deliveryProvider: supportsTryAtHome || supportsInstantDelivery
          ? 'Local Rider'
          : '',
      deliveryMode: fallbackMode,
      serviceZoneId: '',
      zoneId: '',
      city: resolvedCity,
      pincode: address.pincode.trim(),
      etaLabel: etaLabel,
      etaMinutes: supportsTryAtHome || supportsInstantDelivery ? 60 : 0,
      distanceKm: null,
      reason: deliverable ? '' : 'Unable to determine delivery availability.',
    );
  }

  String _resolveCity(UserAddress address) {
    final city = address.city.trim();
    if (city.isNotEmpty) {
      return city;
    }
    final locality = address.locality.trim();
    if (locality.isNotEmpty) {
      return locality;
    }
    return address.state.trim();
  }
}
