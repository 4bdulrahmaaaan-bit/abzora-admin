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
    try {
      if (_backend.isConfigured &&
          (address.latitude != null ||
              address.longitude != null ||
              address.pincode.trim().isNotEmpty)) {
        final payload = await _backend.getProductServiceability(
          productId: product.id,
          latitude: address.latitude,
          longitude: address.longitude,
          pincode: address.pincode,
        );
        return ProductServiceability.fromMap(payload);
      }
    } catch (_) {
      // Surface true delivery API failures so the UI can show Retry instead
      // of incorrectly treating the product as unavailable.
      rethrow;
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
