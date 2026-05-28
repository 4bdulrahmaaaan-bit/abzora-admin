import 'package:dio/dio.dart';

import 'session_auth_interceptor.dart';

Dio createAuthenticatedDio(
  BaseOptions options, {
  bool includeJson = true,
  bool addAuthorization = true,
}) {
  final dio = Dio(options);
  dio.interceptors.add(
    SessionAuthInterceptor(
      dio: dio,
      includeJson: includeJson,
      addAuthorization: addAuthorization,
    ),
  );
  return dio;
}
