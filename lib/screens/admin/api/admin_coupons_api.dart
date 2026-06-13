import '../../../services/backend_api_client.dart';

class AdminCouponsApi {
  static Future<Map<String, dynamic>> fetchCouponsDashboard() async {
    final payload = await const BackendApiClient().get('/admin/coupons/dashboard', authenticated: true);
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchCoupons({
    int page = 1,
    int limit = 25,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get('/admin/coupons?$queryStr', authenticated: true);
    final map = Map<String, dynamic>.from(payload as Map);

    final coupons = (map['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return {
      'coupons': coupons,
      'meta': map['meta'] ?? {},
    };
  }

  static Future<Map<String, dynamic>> createCoupon(Map<String, dynamic> data) async {
    final payload = await const BackendApiClient().post('/admin/coupons', authenticated: true, body: data);
    return Map<String, dynamic>.from(payload['data']);
  }

  static Future<Map<String, dynamic>> updateCoupon(String id, Map<String, dynamic> data) async {
    final payload = await const BackendApiClient().patch('/admin/coupons/$id', authenticated: true, body: data);
    return Map<String, dynamic>.from(payload['data']);
  }
}
