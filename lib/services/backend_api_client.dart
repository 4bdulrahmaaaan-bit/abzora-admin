import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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

  Future<Map<String, String>> _headers({
    bool includeJson = true,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (authenticated) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null || token.isEmpty) {
        throw StateError('Please sign in again to continue.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = AppConfig.backendBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath').replace(queryParameters: queryParameters);
  }

  dynamic _extractPayload(http.Response response) {
    if (response.body.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiException(
          decoded['message']?.toString() ?? 'Request failed.',
          statusCode: response.statusCode,
        );
      }
      return decoded.containsKey('data') ? decoded['data'] : decoded;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        'Request failed.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<dynamic> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? queryParameters,
  }) async {
    final response = await http
        .get(
          _uri(path, queryParameters),
          headers: await _headers(authenticated: authenticated),
        )
        .timeout(const Duration(seconds: 20));
    return _extractPayload(response);
  }

  Future<dynamic> post(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    final response = await http
        .post(
          _uri(path),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    return _extractPayload(response);
  }

  Future<dynamic> put(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    final response = await http
        .put(
          _uri(path),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    return _extractPayload(response);
  }

  Future<dynamic> patch(
    String path, {
    bool authenticated = false,
    Map<String, dynamic> body = const {},
  }) async {
    final response = await http
        .patch(
          _uri(path),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    return _extractPayload(response);
  }

  Future<dynamic> delete(
    String path, {
    bool authenticated = false,
  }) async {
    final response = await http
        .delete(
          _uri(path),
          headers: await _headers(authenticated: authenticated),
        )
        .timeout(const Duration(seconds: 20));
    return _extractPayload(response);
  }

  Future<dynamic> multipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    bool authenticated = true,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final headers = await _headers(includeJson: false, authenticated: authenticated);
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
      ),
    );
    final response = await request.send().timeout(const Duration(seconds: 30));
    final body = await response.stream.bytesToString();
    final wrapped = http.Response(body, response.statusCode, headers: response.headers);
    return _extractPayload(wrapped);
  }
}
