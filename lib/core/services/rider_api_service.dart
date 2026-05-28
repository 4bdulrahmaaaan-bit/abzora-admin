import 'package:dio/dio.dart';

import '../../services/authenticated_dio_factory.dart';

class RiderApiService {
  RiderApiService()
    : _dio = createAuthenticatedDio(
        BaseOptions(
          baseUrl: 'https://api.abzora.com',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  final Dio _dio;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateDeliveryStatus({
    required String orderId,
    required String status,
  }) {
    return post('/tracking/order-status-update', {
      'orderId': orderId,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> postLocationUpdate({
    required String orderId,
    required String riderId,
    required double latitude,
    required double longitude,
    String status = 'active',
  }) {
    return post('/tracking/location-update', {
      'orderId': orderId,
      'riderId': riderId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> completeDelivery({
    required String orderId,
    required String riderId,
  }) {
    return updateDeliveryStatus(orderId: orderId, status: 'Delivered');
  }

  Future<Map<String, dynamic>> fetchEtaByOrderId({
    required String orderId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/tracking/eta/$orderId',
    );
    return response.data ?? <String, dynamic>{};
  }
}
