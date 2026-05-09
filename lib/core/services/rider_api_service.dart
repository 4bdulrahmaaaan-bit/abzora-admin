import 'package:dio/dio.dart';

class RiderApiService {
  RiderApiService()
    : _dio = Dio(
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
}
