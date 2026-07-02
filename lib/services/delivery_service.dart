import '../models/models.dart';
import '../models/delivery_serviceability.dart';
import 'backend_commerce_service.dart';

class DeliveryService {
  DeliveryService({BackendCommerceService? backendCommerceService})
    : _backend = backendCommerceService ?? BackendCommerceService();

  final BackendCommerceService _backend;
  static final Map<String, Future<ProductServiceability>> _futureCache = {};

  String _cacheKey({required Product product, required UserAddress address}) {
    final lat = address.latitude?.toStringAsFixed(5) ?? 'na';
    final lng = address.longitude?.toStringAsFixed(5) ?? 'na';
    return [
      product.id,
      product.colorVariants.isNotEmpty ? product.colorVariants.first.variantId : '',
      lat,
      lng,
      address.pincode.trim(),
    ].join('|');
  }

  Future<ProductServiceability> getServiceability({
    required Product product,
    required UserAddress address,
  }) {
    final key = _cacheKey(product: product, address: address);
    return _futureCache.putIfAbsent(
      key,
      () => _resolveServiceability(product: product, address: address),
    );
  }

  void invalidateForProduct(String productId) {
    _futureCache.removeWhere((key, _) => key.startsWith('$productId|'));
  }

  Future<ProductServiceability> _resolveServiceability({
    required Product product,
    required UserAddress address,
  }) async {
    try {
      if (_backend.isConfigured &&
          address.latitude != null &&
          address.longitude != null) {
        final payload = await _backend.getProductServiceability(
          productId: product.id,
          latitude: address.latitude!,
          longitude: address.longitude!,
          pincode: address.pincode,
        );
        return ProductServiceability.fromMap(payload);
      }
    } catch (_) {
      // Keep serviceability deterministic: never guess from product flags.
    }

    return ProductServiceability(
      supportsTryAtHome: false,
      supportsInstantDelivery: false,
      supportsCourierDelivery: false,
      isDeliverable: false,
      estimatedDeliveryDate: '',
      estimatedInstantDeliveryTime: '',
      shippingCharge: 0,
      deliveryPartner: '',
      deliveryProvider: '',
      deliveryMode: DeliveryMode.unavailable,
      serviceZoneId: '',
      zoneId: '',
      city: '',
      pincode: address.pincode,
      etaLabel: '',
      etaMinutes: 0,
      distanceKm: null,
      reason: 'Unable to determine delivery availability.',
    );
  }
}
