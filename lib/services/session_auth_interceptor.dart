import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_session_service.dart';

class SessionAuthInterceptor extends Interceptor {
  SessionAuthInterceptor({
    required this.dio,
    this.includeJson = true,
    this.addAuthorization = true,
  });

  final Dio dio;
  final bool includeJson;
  final bool addAuthorization;

  static const String _retryKey = '__auth_retry_attempted';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (includeJson) {
      options.headers.putIfAbsent('Content-Type', () => 'application/json');
    }
    if (addAuthorization) {
      final headers = await AuthSessionService.instance.authorizationHeaders(
        forceRefresh: false,
        includeJson: false,
      );
      final token = headers?['Authorization'];
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = token;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final requestOptions = err.requestOptions;
    final shouldRetry =
        response?.statusCode == 401 &&
        requestOptions.extra[_retryKey] != true &&
        addAuthorization;

    if (!shouldRetry) {
      handler.next(err);
      return;
    }

    requestOptions.extra[_retryKey] = true;
    debugPrint(
      'SessionAuthInterceptor: retrying ${requestOptions.method} ${requestOptions.path} after 401.',
    );

    final recovery = await AuthSessionService.instance.attemptSilentRecovery(
      reason: '${requestOptions.method} ${requestOptions.path}',
    );
    if (recovery == SessionRecoveryStatus.offline) {
      debugPrint(
        'SessionAuthInterceptor: refresh deferred because the device is offline.',
      );
      handler.next(err);
      return;
    }
    if (recovery != SessionRecoveryStatus.recovered) {
      handler.next(err);
      return;
    }

    try {
      final freshHeaders = await AuthSessionService.instance
          .authorizationHeaders(forceRefresh: false, includeJson: false);
      if (freshHeaders != null) {
        requestOptions.headers.addAll(freshHeaders);
      }
      final clone = await dio.fetch(requestOptions);
      handler.resolve(clone);
    } catch (error) {
      handler.next(err);
    }
  }
}
