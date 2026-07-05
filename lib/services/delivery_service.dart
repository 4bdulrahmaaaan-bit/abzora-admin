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

  Future<ProductServiceability> _resolveServiceability({
    required Product product,
    required UserAddress address,
  }) async {
    final resolvedCity = _resolveCity(address);
    try {
      if (_backend.isConfigured &&
          (address.latitude != null ||
              address.longitude != null ||
              address.pincode.trim().isNotEmpty ||
              resolvedCity.isNotEmpty)) {
        final payload = await _backend.getProductServiceability(
          productId: product.id,
          latitude: address.latitude,
          longitude: address.longitude,
          pincode: address.pincode,
          city: resolvedCity,
          state: address.state,
        );
        return ProductServiceability.fromMap(payload);
      }
    } catch (_) {
      // Fall back to a deterministic local decision so the PDP never gets
      // stuck on Retry for a serviceable saved address.
    }

    final hasAddressSignal =
        address.latitude != null ||
        address.longitude != null ||
        address.pincode.trim().isNotEmpty ||
        resolvedCity.isNotEmpty ||
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
          : supportsCourierDelivery
          ? 'Shiprocket'
          : '',
      deliveryProvider: supportsTryAtHome || supportsInstantDelivery
          ? 'Local Rider'
          : supportsCourierDelivery
          ? 'Shiprocket'
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
