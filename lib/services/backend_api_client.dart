import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'auth_session_service.dart';

enum BackendFailureKind {
  noInternet,
  dnsLookup,
  timeout,
  backendUnavailable,
  clientError,
  serverError,
  tlsFailure,
  unknown,
}

class BackendApiException implements Exception {
  const BackendApiException(
    this.message, {
    required this.statusCode,
    required this.failureKind,
    this.endpoint = '',
    this.method = '',
    this.exceptionType = '',
    this.timeoutDuration,
  });

  final String message;
  final int statusCode;
  final BackendFailureKind failureKind;
  final String endpoint;
  final String method;
  final String exceptionType;
  final Duration? timeoutDuration;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isTimeout => failureKind == BackendFailureKind.timeout;
  bool get isDnsLookupFailure => failureKind == BackendFailureKind.dnsLookup;
  bool get isNoInternetConnection =>
      failureKind == BackendFailureKind.noInternet;
  bool get isBackendUnavailable =>
      failureKind == BackendFailureKind.backendUnavailable;
  bool get isServerError => failureKind == BackendFailureKind.serverError;
  bool get isClientError => failureKind == BackendFailureKind.clientError;
  bool get isTlsFailure => failureKind == BackendFailureKind.tlsFailure;
  bool get isNetworkIssue =>
      isNoInternetConnection ||
      isDnsLookupFailure ||
      isTimeout ||
      isBackendUnavailable ||
      isTlsFailure;

  @override
  String toString() => message;
}

class BackendApiClient {
  const BackendApiClient();

  bool get isConfigured => AppConfig.hasBackendBaseUrl;
  static String? _preferredBaseUrl;
  static Future<void> Function()? _unauthorizedHandler;
  static bool _isHandlingUnauthorized = false;
  static int _consecutiveBackendFailures = 0;
  static DateTime? _lastBackendFailureAt;
  static const int _backendFailureThreshold = 2;
  static const Duration _backendFailureWindow = Duration(seconds: 45);

  static final ValueNotifier<BackendAvailability> backendAvailability =
      ValueNotifier(const BackendAvailability.available());

  static void registerUnauthorizedHandler(Future<void> Function()? handler) {
    _unauthorizedHandler = handler;
  }

  Future<void> _notifyUnauthorized() async {
    if (_isHandlingUnauthorized) {
      return;
    }
    final handler = _unauthorizedHandler;
    if (handler == null) {
      return;
    }
    _isHandlingUnauthorized = true;
    try {
      await handler();
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  static void clearBackendAvailability() {
    _consecutiveBackendFailures = 0;
    _lastBackendFailureAt = null;
    backendAvailability.value = const BackendAvailability.available();
  }

  void _markBackendDown(String message) {
    final now = DateTime.now();
    final lastFailure = _lastBackendFailureAt;
    if (lastFailure == null ||
        now.difference(lastFailure) > _backendFailureWindow) {
      _consecutiveBackendFailures = 1;
    } else {
      _consecutiveBackendFailures += 1;
    }
    _lastBackendFailureAt = now;

    if (_consecutiveBackendFailures < _backendFailureThreshold) {
      return;
    }
    backendAvailability.value = BackendAvailability.unavailable(message);
  }

  void _markBackendOk() {
    _consecutiveBackendFailures = 0;
    _lastBackendFailureAt = null;
    if (!backendAvailability.value.isAvailable) {
      backendAvailability.value = const BackendAvailability.available();
    }
  }

  void _logFailure({
    required String method,
    required String path,
    required int statusCode,
    required String exceptionType,
    Duration? timeoutDuration,
    String? message,
  }) {
    final timeoutLabel = timeoutDuration == null
        ? 'n/a'
        : '${timeoutDuration.inSeconds}s';
    debugPrint(
      'BackendApiClient failure: endpoint=$method $path, statusCode=$statusCode, '
      'exceptionType=$exceptionType, timeout=$timeoutLabel${message == null ? '' : ', message=$message'}',
    );
  }

  bool _isNoInternetError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('network is unreachable') ||
        text.contains('no route to host') ||
        text.contains('host is down') ||
        text.contains('there was no internet connection') ||
        text.contains('internet connection') ||
        text.contains('network unreachable');
  }

  bool _isDnsLookupError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('name or service not known') ||
        text.contains('temporary failure in name resolution');
  }

  bool _isBackendUnavailableError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('software caused connection abort') ||
        text.contains('broken pipe') ||
        text.contains('connection aborted');
  }

  bool _isTlsFailure(Object error) {
    final text = error.toString().toLowerCase();
    return error is HandshakeException ||
        text.contains('handshakeexception') ||
        text.contains('certificate') ||
        text.contains('ssl');
  }

  BackendFailureKind _classifyTransportFailure(Object error) {
    if (error is TimeoutException) {
      return BackendFailureKind.timeout;
    }
    if (error is SocketException) {
      if (_isDnsLookupError(error)) {
        return BackendFailureKind.dnsLookup;
      }
      if (_isNoInternetError(error)) {
        return BackendFailureKind.noInternet;
      }
      if (_isBackendUnavailableError(error)) {
        return BackendFailureKind.backendUnavailable;
      }
    }
    if (error is http.ClientException) {
      if (_isDnsLookupError(error)) {
        return BackendFailureKind.dnsLookup;
      }
      if (_isNoInternetError(error)) {
        return BackendFailureKind.noInternet;
      }
      if (_isBackendUnavailableError(error)) {
        return BackendFailureKind.backendUnavailable;
      }
    }
    if (_isTlsFailure(error)) {
      return BackendFailureKind.tlsFailure;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') &&
        text.contains('failed host lookup')) {
      return BackendFailureKind.dnsLookup;
    }
    if (text.contains('socketexception')) {
      return BackendFailureKind.backendUnavailable;
    }
    return BackendFailureKind.unknown;
  }

  String _transportMessage(BackendFailureKind kind, Duration timeoutDuration) {
    switch (kind) {
      case BackendFailureKind.noInternet:
        return 'No internet connection. Check your network and try again.';
      case BackendFailureKind.dnsLookup:
        return 'DNS lookup failed. Please check the backend domain and try again.';
      case BackendFailureKind.timeout:
        return 'Request timed out after ${timeoutDuration.inSeconds}s. Please try again.';
      case BackendFailureKind.backendUnavailable:
        return 'Backend unreachable. Please try again in a moment.';
      case BackendFailureKind.clientError:
        return 'Network request failed. Please try again.';
      case BackendFailureKind.serverError:
        return 'Server error. Please try again in a moment.';
      case BackendFailureKind.tlsFailure:
        return 'Secure connection to the backend failed. Please try again.';
      case BackendFailureKind.unknown:
        return 'Network request failed. Please try again.';
    }
  }

  BackendApiException _transportException({
    required String method,
    required String path,
    required Object error,
    required Duration timeoutDuration,
  }) {
    final kind = _classifyTransportFailure(error);
    final statusCode = switch (kind) {
      BackendFailureKind.timeout => 408,
      BackendFailureKind.backendUnavailable => 503,
      BackendFailureKind.serverError => 500,
      BackendFailureKind.clientError => 400,
      BackendFailureKind.dnsLookup => 0,
      BackendFailureKind.noInternet => 0,
      BackendFailureKind.tlsFailure => 525,
      BackendFailureKind.unknown => 0,
    };
    final message = _transportMessage(kind, timeoutDuration);
    _logFailure(
      method: method,
      path: path,
      statusCode: statusCode,
      exceptionType: error.runtimeType.toString(),
      timeoutDuration: timeoutDuration,
      message: message,
    );
    if (kind == BackendFailureKind.backendUnavailable ||
        kind == BackendFailureKind.timeout ||
        kind == BackendFailureKind.tlsFailure ||
        kind == BackendFailureKind.serverError) {
      _markBackendDown(message);
    }
    return BackendApiException(
      message,
      statusCode: statusCode,
      failureKind: kind,
      endpoint: '$method $path',
      method: method,
      exceptionType: error.runtimeType.toString(),
      timeoutDuration: timeoutDuration,
    );
  }

  Future<Map<String, String>> _headers({
    bool includeJson = true,
    bool authenticated = false,
    bool forceRefreshToken = false,
  }) async {
    final headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (authenticated) {
      final token = await AuthSessionService.instance
          .requiredAuthorizationToken(
            forceRefresh: forceRefreshToken,
            failureMessage: 'Please sign in again to continue.',
          );
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _sendWithUnauthorizedRetry({
    required bool authenticated,
    required bool includeJson,
    required Future<http.Response> Function(Map<String, String> headers) send,
  }) async {
    var headers = await _headers(
      includeJson: includeJson,
      authenticated: authenticated,
    );
    var response = await send(headers);
    if (!authenticated || response.statusCode != 401) {
      return response;
    }

    debugPrint('BackendApiClient: 401 received, attempting one silent retry.');
    final recovery = await AuthSessionService.instance.attemptSilentRecovery(
      reason: 'backend_api_client',
    );
    if (recovery == SessionRecoveryStatus.offline) {
      debugPrint(
        'BackendApiClient: refresh deferred because the device is offline.',
      );
      return response;
    }
    if (recovery != SessionRecoveryStatus.recovered) {
      debugPrint('BackendApiClient: silent recovery failed.');
      await _notifyUnauthorized();
      return response;
    }

    headers = await _headers(
      includeJson: includeJson,
      authenticated: authenticated,
      forceRefreshToken: true,
    );
    response = await send(headers);
    if (response.statusCode == 401) {
      debugPrint('BackendApiClient: retry still unauthorized.');
      await _notifyUnauthorized();
    }
    return response;
  }

  Uri _uriForBase(
    String base,
    String path, [
    Map<String, String>? queryParameters,
  ]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$base$normalizedPath',
    ).replace(queryParameters: queryParameters);
  }

  List<String> _baseUrlCandidates() {
    final primary = AppConfig.backendBaseUrl.trim();
    if (primary.isEmpty) {
      return const <String>[];
    }
    final candidates = <String>[primary];
    const renderOrigin = 'https://gcp-us-west1-1.origin.onrender.com';

    // Keep a hard fallback to Render origin so app traffic survives
    // temporary DNS propagation/cache issues on custom domains.
    if (primary != renderOrigin) {
      candidates.add(renderOrigin);
    }

    if (primary.contains('abzora-backend.onrender.com')) {
      candidates.add(
        primary.replaceFirst(
          'abzora-backend.onrender.com',
          'gcp-us-west1-1.origin.onrender.com',
        ),
      );
    }
    final unique = candidates.toSet().toList();
    final preferred = _preferredBaseUrl;
    if (preferred == null || preferred.isEmpty) {
      return unique;
    }
    final preferredIndex = unique.indexOf(preferred);
    if (preferredIndex > 0) {
      final reordered = <String>[preferred];
      reordered.addAll(unique.where((item) => item != preferred));
      return reordered;
    }
    return unique;
  }

  bool _isTransientNetworkError(Object error) {
    if (error is BackendApiException) {
      return error.isNetworkIssue || error.isServerError;
    }
    if (error is TimeoutException) {
      return true;
    }
    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      if (message.contains('socketexception') ||
          message.contains('failed host lookup') ||
          message.contains('software caused connection abort') ||
          message.contains('connection closed')) {
        return true;
      }
    }
    final asText = error.toString().toLowerCase();
    return error is SocketException ||
        error is HandshakeException ||
        asText.contains('failed host lookup') ||
        asText.contains('software caused connection abort') ||
        asText.contains('connection closed');
  }

  Future<T> _executeWithDnsFallback<T>({
    required String path,
    Map<String, String>? queryParameters,
    required Future<T> Function(Uri uri, int candidateIndex) execute,
  }) async {
    final bases = _baseUrlCandidates();
    if (bases.isEmpty) {
      throw StateError('BACKEND_BASE_URL is not configured.');
    }
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var i = 0; i < bases.length; i++) {
      final uri = _uriForBase(bases[i], path, queryParameters);
      try {
        final result = await execute(uri, i);
        _preferredBaseUrl = bases[i];
        return result;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        final shouldTryNext =
            i < bases.length - 1 &&
            _isTransientNetworkError(error) &&
            _isDnsLookupError(error);
        if (!shouldTryNext) {
          rethrow;
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<T> withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 700),
  }) async {
    var attempt = 0;
    var delay = initialDelay;
    while (true) {
      attempt += 1;
      try {
        return await action();
      } catch (error) {
        if (attempt >= maxAttempts || !_isTransientNetworkError(error)) {
          rethrow;
        }
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
  }

  bool _isServiceabilityError(String message) {
    final text = message.toLowerCase();
    return text.contains('unserviceable') ||
        text.contains('not serviceable') ||
        text.contains('serviceability');
  }

  String _augmentServiceabilityMessage(
    String message, {
    required String method,
    required String path,
  }) {
    if (!_isServiceabilityError(message)) {
      return message;
    }
    final endpoint = '$method $path';
    debugPrint('Abianzo serviceability failure at $endpoint: $message');
    return '$message (endpoint: $endpoint)';
  }

  dynamic _extractPayload(
    http.Response response, {
    required String method,
    required String path,
  }) {
    final rawBody = response.body.trim();
    if (rawBody.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _markBackendOk();
      }
      return null;
    }
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final looksLikeJson =
        contentType.contains('application/json') ||
        rawBody.startsWith('{') ||
        rawBody.startsWith('[');

    if (!looksLikeJson) {
      final preview = rawBody.replaceAll(RegExp(r'\s+'), ' ');
      if (response.statusCode >= 500) {
        _markBackendDown(
          'Server error (${response.statusCode}). Please try again in a moment.',
        );
      }
      _logFailure(
        method: method,
        path: path,
        statusCode: response.statusCode,
        exceptionType: 'HttpStatusException',
        message: response.statusCode >= 500
            ? 'Server error (${response.statusCode}). Please try again in a moment.'
            : 'Backend returned a non-JSON response.',
      );
      throw BackendApiException(
        response.statusCode >= 200 && response.statusCode < 300
            ? 'Backend returned a non-JSON response. Please verify backend deployment.'
            : _statusMessageForCode(
                response.statusCode,
                backendMessage: preview,
              ),
        statusCode: response.statusCode,
        failureKind: response.statusCode >= 500
            ? BackendFailureKind.serverError
            : BackendFailureKind.clientError,
        endpoint: '$method $path',
        method: method,
        exceptionType: 'HttpStatusException',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException {
      if (response.statusCode >= 500) {
        _markBackendDown(
          'Server error (${response.statusCode}). Please try again in a moment.',
        );
      }
      _logFailure(
        method: method,
        path: path,
        statusCode: response.statusCode,
        exceptionType: 'FormatException',
      );
      throw BackendApiException(
        response.statusCode >= 500
            ? 'Server error (${response.statusCode}). Please try again in a moment.'
            : 'Backend returned invalid JSON. Please verify backend deployment.',
        statusCode: response.statusCode,
        failureKind: response.statusCode >= 500
            ? BackendFailureKind.serverError
            : BackendFailureKind.clientError,
        endpoint: '$method $path',
        method: method,
        exceptionType: 'FormatException',
      );
    }
    if (decoded is Map<String, dynamic>) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          final message = decoded['message']?.toString() ?? 'Request failed.';
          if (_shouldNotifyUnauthorizedSession(message)) {
            unawaited(_notifyUnauthorized());
          }
        }
        if (response.statusCode >= 500) {
          _markBackendDown(
            'Server error (${response.statusCode}). Please try again in a moment.',
          );
        }
        final backendMessage =
            decoded['message']?.toString() ?? 'Request failed.';
        final message = _statusMessageForCode(
          response.statusCode,
          backendMessage: backendMessage,
        );
        _logFailure(
          method: method,
          path: path,
          statusCode: response.statusCode,
          exceptionType: 'HttpStatusException',
          message: message,
        );
        throw BackendApiException(
          _augmentServiceabilityMessage(
            _normalizeErrorMessage(message, response.statusCode),
            method: method,
            path: path,
          ),
          statusCode: response.statusCode,
          failureKind: response.statusCode >= 500
              ? BackendFailureKind.serverError
              : (response.statusCode >= 400
                    ? BackendFailureKind.clientError
                    : BackendFailureKind.unknown),
          endpoint: '$method $path',
          method: method,
          exceptionType: 'HttpStatusException',
        );
      }
      _markBackendOk();
      return decoded.containsKey('data') ? decoded['data'] : decoded;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        // Non-JSON 401 payloads are ambiguous; avoid forcing logout here.
      }
      if (response.statusCode >= 500) {
        _markBackendDown(
          'Server error (${response.statusCode}). Please try again in a moment.',
        );
      }
      final message = _statusMessageForCode(response.statusCode);
      _logFailure(
        method: method,
        path: path,
        statusCode: response.statusCode,
        exceptionType: 'HttpStatusException',
        message: message,
      );
      throw BackendApiException(
        _normalizeErrorMessage(message, response.statusCode),
        statusCode: response.statusCode,
        failureKind: response.statusCode >= 500
            ? BackendFailureKind.serverError
            : BackendFailureKind.clientError,
        endpoint: '$method $path',
        method: method,
        exceptionType: 'HttpStatusException',
      );
    }
    _markBackendOk();
    return decoded;
  }

  String _normalizeErrorMessage(String message, int statusCode) {
    if (statusCode == 401 && message.trim().toLowerCase() == 'unauthorized') {
      return 'Session expired. Please sign in again.';
    }
    return message;
  }

  String _statusMessageForCode(int statusCode, {String? backendMessage}) {
    final message = backendMessage?.trim() ?? '';
    if (message.isNotEmpty &&
        message.toLowerCase() != 'request failed.' &&
        message.toLowerCase() != 'failed') {
      if (statusCode >= 500) {
        return message;
      }
      return message;
    }
    return switch (statusCode) {
      400 => 'Request was invalid. Please check your input and try again.',
      401 => 'Unauthorized. Please sign in again.',
      403 => 'Access denied. Please sign in with the correct account.',
      404 => 'The requested resource was not found.',
      408 => 'Request timed out. Please try again.',
      409 =>
        'This request conflicts with current data. Please refresh and try again.',
      422 => 'Some details need attention. Please review and try again.',
      429 => 'Too many requests. Please wait a moment and try again.',
      >= 500 => 'Server error. Please try again in a moment.',
      _ => 'Unexpected response from the backend. Please try again in a moment.',
    };
  }

  bool _shouldNotifyUnauthorizedSession(String message) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) {
      return false;
    }
    return text.contains('session expired') ||
        text.contains('sign in again') ||
        text.contains('token expired') ||
        text.contains('id token has expired') ||
        text.contains('token has expired') ||
        text.contains('token revoked') ||
        text.contains('revoked') ||
        text.contains('invalid token') ||
        text.contains('no token') ||
        text.contains('bearer token');
  }

  Future<dynamic> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? queryParameters,
  }) async {
    const timeout = Duration(seconds: 20);
    try {
      final response = await _executeWithDnsFallback(
        path: path,
        queryParameters: queryParameters,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) => http.get(uri, headers: headers).timeout(timeout),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'GET', path: path);
    } on TimeoutException catch (error) {
      throw _transportException(
        method: 'GET',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on SocketException catch (error) {
      throw _transportException(
        method: 'GET',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on http.ClientException catch (error) {
      throw _transportException(
        method: 'GET',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on HandshakeException catch (error) {
      throw _transportException(
        method: 'GET',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    }
  }

  Future<dynamic> post(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    const timeout = Duration(seconds: 25);
    try {
      final payload = jsonEncode(body);
      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) => http
                .post(uri, headers: headers, body: payload)
                .timeout(timeout),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'POST', path: path);
    } on TimeoutException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on SocketException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on http.ClientException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on HandshakeException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    }
  }

  Future<dynamic> put(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    const timeout = Duration(seconds: 25);
    try {
      final payload = jsonEncode(body);
      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) =>
                http.put(uri, headers: headers, body: payload).timeout(timeout),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'PUT', path: path);
    } on TimeoutException catch (error) {
      throw _transportException(
        method: 'PUT',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on SocketException catch (error) {
      throw _transportException(
        method: 'PUT',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on http.ClientException catch (error) {
      throw _transportException(
        method: 'PUT',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on HandshakeException catch (error) {
      throw _transportException(
        method: 'PUT',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    const timeout = Duration(seconds: 25);
    try {
      final payload = jsonEncode(body);
      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) => http
                .patch(uri, headers: headers, body: payload)
                .timeout(timeout),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'PATCH', path: path);
    } on TimeoutException catch (error) {
      throw _transportException(
        method: 'PATCH',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on SocketException catch (error) {
      throw _transportException(
        method: 'PATCH',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on http.ClientException catch (error) {
      throw _transportException(
        method: 'PATCH',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on HandshakeException catch (error) {
      throw _transportException(
        method: 'PATCH',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    }
  }

  Future<dynamic> delete(String path, {bool authenticated = false}) async {
    const timeout = Duration(seconds: 20);
    try {
      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) =>
                http.delete(uri, headers: headers).timeout(timeout),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'DELETE', path: path);
    } on TimeoutException catch (error) {
      throw _transportException(
        method: 'DELETE',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on SocketException catch (error) {
      throw _transportException(
        method: 'DELETE',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on http.ClientException catch (error) {
      throw _transportException(
        method: 'DELETE',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on HandshakeException catch (error) {
      throw _transportException(
        method: 'DELETE',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    }
  }

  Future<dynamic> multipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    MediaType? contentType,
    bool authenticated = true,
  }) async {
    const timeout = Duration(seconds: 30);
    try {
      Future<http.StreamedResponse> sendMultipart({
        required Uri uri,
        required Map<String, String> headers,
      }) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: filename,
            contentType: contentType,
          ),
        );
        return request.send().timeout(timeout);
      }

      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(() async {
          var headers = await _headers(
            includeJson: false,
            authenticated: authenticated,
          );
          var streamed = await sendMultipart(uri: uri, headers: headers);
          if (authenticated && streamed.statusCode == 401) {
            headers = await _headers(
              includeJson: false,
              authenticated: authenticated,
              forceRefreshToken: true,
            );
            streamed = await sendMultipart(uri: uri, headers: headers);
          }
          return streamed;
        }, maxAttempts: candidateIndex == 0 ? 2 : 1),
      );
      final body = await response.stream.bytesToString();
      final wrapped = http.Response(
        body,
        response.statusCode,
        headers: response.headers,
      );
      return _extractPayload(wrapped, method: 'POST', path: path);
    } on TimeoutException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on SocketException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on http.ClientException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    } on HandshakeException catch (error) {
      throw _transportException(
        method: 'POST',
        path: path,
        error: error,
        timeoutDuration: timeout,
      );
    }
  }
}

class BackendAvailability {
  final bool isAvailable;
  final String message;

  const BackendAvailability.available() : isAvailable = true, message = '';

  const BackendAvailability.unavailable(this.message) : isAvailable = false;
}
