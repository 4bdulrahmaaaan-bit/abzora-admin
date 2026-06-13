import 'backend_api_client.dart';

class CouponApi {
  CouponApi({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<List<Map<String, dynamic>>> getCoupons() async {
    final payload = await _backendApiClient.get(
      '/vendor/coupons',
      authenticated: true,
    );
    final coupons = payload['coupons'];
    if (coupons is List) {
      return coupons.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createCoupon(Map<String, dynamic> data) async {
    final payload = await _backendApiClient.post(
      '/vendor/coupons',
      authenticated: true,
      body: data,
    );
    return payload as Map<String, dynamic>;
  }

  Future<void> updateCouponStatus(String id, String status) async {
    await _backendApiClient.post(
      '/vendor/coupons/$id/status',
      authenticated: true,
      body: {'status': status, '_method': 'PATCH'},
    );
  }
}
