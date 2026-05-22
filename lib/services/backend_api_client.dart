import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';

class BackendApiException implements Exception {
  const BackendApiException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

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
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(
        forceRefreshToken,
      );
      if (token == null || token.isEmpty) {
        throw StateError('Please sign in again to continue.');
      }
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

    headers = await _headers(
      includeJson: includeJson,
      authenticated: authenticated,
      forceRefreshToken: true,
    );
    response = await send(headers);
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

  bool _isDnsLookupError(Object error) {
    final asText = error.toString().toLowerCase();
    return asText.contains('failed host lookup') ||
        asText.contains('no address associated with hostname');
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
      _markBackendDown('Backend responded with non-JSON content.');
      throw BackendApiException(
        response.statusCode >= 200 && response.statusCode < 300
            ? 'Backend returned a non-JSON response. Please verify backend URL/deployment.'
            : 'Backend request failed (${response.statusCode}). ${preview.length > 120 ? '${preview.substring(0, 120)}...' : preview}',
        statusCode: response.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException {
      _markBackendDown('Backend returned invalid JSON.');
      throw BackendApiException(
        'Backend returned invalid JSON. Please verify backend deployment.',
        statusCode: response.statusCode,
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
          _markBackendDown('Backend error (${response.statusCode}).');
        }
        final backendMessage =
            decoded['message']?.toString() ?? 'Request failed.';
        throw BackendApiException(
          _augmentServiceabilityMessage(
            _normalizeErrorMessage(backendMessage, response.statusCode),
            method: method,
            path: path,
          ),
          statusCode: response.statusCode,
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
        _markBackendDown('Backend error (${response.statusCode}).');
      }
      throw BackendApiException(
        _normalizeErrorMessage('Request failed.', response.statusCode),
        statusCode: response.statusCode,
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
    try {
      final response = await _executeWithDnsFallback(
        path: path,
        queryParameters: queryParameters,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) =>
                http.get(uri, headers: headers).timeout(const Duration(seconds: 20)),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'GET', path: path);
    } on SocketException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on http.ClientException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on HandshakeException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on TimeoutException {
      _markBackendDown('Backend timed out.');
      rethrow;
    }
  }

  Future<dynamic> post(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
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
                .timeout(const Duration(seconds: 25)),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'POST', path: path);
    } on SocketException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on http.ClientException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on HandshakeException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on TimeoutException {
      _markBackendDown('Backend timed out.');
      rethrow;
    }
  }

  Future<dynamic> put(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    try {
      final payload = jsonEncode(body);
      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) => http
                .put(uri, headers: headers, body: payload)
                .timeout(const Duration(seconds: 25)),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'PUT', path: path);
    } on SocketException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on http.ClientException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on HandshakeException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on TimeoutException {
      _markBackendDown('Backend timed out.');
      rethrow;
    }
  }

  Future<dynamic> patch(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
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
                .timeout(const Duration(seconds: 25)),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'PATCH', path: path);
    } on SocketException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on http.ClientException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on HandshakeException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on TimeoutException {
      _markBackendDown('Backend timed out.');
      rethrow;
    }
  }

  Future<dynamic> delete(String path, {bool authenticated = false}) async {
    try {
      final response = await _executeWithDnsFallback(
        path: path,
        execute: (uri, candidateIndex) => withRetry(
          () => _sendWithUnauthorizedRetry(
            authenticated: authenticated,
            includeJson: true,
            send: (headers) => http
                .delete(uri, headers: headers)
                .timeout(const Duration(seconds: 20)),
          ),
          maxAttempts: candidateIndex == 0 ? 2 : 1,
        ),
      );
      return _extractPayload(response, method: 'DELETE', path: path);
    } on SocketException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on http.ClientException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on HandshakeException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on TimeoutException {
      _markBackendDown('Backend timed out.');
      rethrow;
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
        return request.send().timeout(const Duration(seconds: 30));
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
    } on SocketException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on http.ClientException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on HandshakeException {
      _markBackendDown('Backend unreachable.');
      rethrow;
    } on TimeoutException {
      _markBackendDown('Backend timed out.');
      rethrow;
    }
  }
}

class BackendAvailability {
  final bool isAvailable;
  final String message;

  const BackendAvailability.available() : isAvailable = true, message = '';

  const BackendAvailability.unavailable(this.message) : isAvailable = false;
}
