import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'app_config.dart';
import 'secure_session_storage.dart';

enum SessionRecoveryStatus { recovered, offline, failed, rateLimited, unprovisioned }

class _RefreshOperationState {
  _RefreshOperationState({
    required this.operationName,
    required this.attemptSerial,
  });

  final String operationName;
  final int attemptSerial;
  final Completer<SessionRecoveryStatus> completer =
      Completer<SessionRecoveryStatus>();
  Timer? timeoutTimer;
  int waiterCount = 0;

  Future<SessionRecoveryStatus> get future => completer.future;
}

class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();
  static const Duration _refreshTimeout = Duration(seconds: 12);
  static const Duration _bootstrapTimeout = Duration(seconds: 15);

  static final _secureStorage = createSecureSessionStorage();
  static const String _kAccessToken = 'auth_access_token_v2';
  static const String _kRefreshToken = 'auth_refresh_token_v2';
  static const String _kAccessTokenExpiresAt =
      'auth_access_token_expires_at_v2';
  static const String _kRefreshTokenExpiresAt =
      'auth_refresh_token_expires_at_v2';
  static const String _kSessionId = 'auth_session_id_v2';
  static const String _kDeviceId = 'auth_device_id_v2';
  static const String _kUserSnapshot = 'auth_user_snapshot_v2';

  final Random _random = Random.secure();
  bool _initialized = false;
  _RefreshOperationState? _refreshOperation;
  int _sessionGeneration = 0;
  int _refreshAttemptSerial = 0;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiresAt;
  DateTime? _refreshTokenExpiresAt;
  String? _sessionId;
  String? _deviceId;
  Map<String, dynamic>? _userSnapshot;
  DateTime? _rateLimitUntil;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _restoreFromStorage();
    _initialized = true;
  }

  bool get hasBackendSession => (_refreshToken ?? '').isNotEmpty;

  String? get sessionId => _sessionId;

  String? get deviceId => _deviceId;

  Future<String> ensureDeviceId() async {
    await initialize();
    if ((_deviceId ?? '').isNotEmpty) {
      return _deviceId!;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kDeviceId);
    if (stored != null && stored.trim().isNotEmpty) {
      _deviceId = stored.trim();
      return _deviceId!;
    }
    final generated = _generateId(prefix: 'device');
    _deviceId = generated;
    await prefs.setString(_kDeviceId, generated);
    return generated;
  }

  Future<String?> authorizationToken({bool forceRefresh = false}) async {
    await initialize();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (forceRefresh) {
        await clearSession(reason: 'firebase_user_missing');
      }
      return null;
    }

    final shouldRefresh = forceRefresh || _shouldProactivelyRefreshToken();
    if (!shouldRefresh && _isAccessTokenValid()) {
      return _accessToken;
    }

    final refreshed = await _ensureBackendSession(
      reason: forceRefresh
          ? 'authorization_token_force'
          : 'authorization_token',
      forceIdTokenRefresh: forceRefresh,
      allowFirebaseBootstrap: true,
      preferFirebaseBootstrap: false,
    );
    if (refreshed == SessionRecoveryStatus.recovered) {
      return _accessToken;
    }

    if (_isAccessTokenValid()) {
      return _accessToken;
    }

    if (refreshed == SessionRecoveryStatus.unprovisioned) {
      throw StateError('Your account could not be provisioned. Please contact support if this persists.');
    }

    if (refreshed == SessionRecoveryStatus.rateLimited) {
      throw StateError('Too many requests. Please wait a moment and try again.');
    }

    try {
      final fallbackToken = await firebaseUser
          .getIdToken(forceRefresh)
          .timeout(const Duration(seconds: 15));
      if (fallbackToken != null && fallbackToken.isNotEmpty) {
        debugPrint('AuthSessionService: falling back to Firebase ID token.');
        return fallbackToken;
      }
    } on TimeoutException {
      debugPrint('AuthSessionService: firebaseUser.getIdToken timed out.');
    } catch (e) {
      debugPrint('AuthSessionService: firebaseUser.getIdToken failed: $e');
    }
    return null;
  }

  Future<Map<String, String>?> authorizationHeaders({
    bool forceRefresh = false,
    bool includeJson = true,
  }) async {
    final token = await authorizationToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      return null;
    }
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<String> requiredAuthorizationToken({
    bool forceRefresh = false,
    String failureMessage = 'Please sign in again to continue.',
  }) async {
    final token = await authorizationToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError(failureMessage);
    }
    return token;
  }

  Future<Map<String, String>> requiredAuthorizationHeaders({
    bool forceRefresh = false,
    bool includeJson = true,
    String failureMessage = 'Please sign in again to continue.',
  }) async {
    final token = await requiredAuthorizationToken(
      forceRefresh: forceRefresh,
      failureMessage: failureMessage,
    );
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<bool> ensureSessionForCurrentUser({
    bool forceRefreshIdToken = false,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return false;
    }
    return (await _bootstrapFromFirebase(
          firebaseUser,
          forceRefreshIdToken: forceRefreshIdToken,
        )) ==
        SessionRecoveryStatus.recovered;
  }

  Future<bool> refreshIfNeeded() async {
    await initialize();
    if (_isAccessTokenValid() && !_shouldProactivelyRefreshToken()) {
      return true;
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return false;
    }
    final refreshed = await _ensureBackendSession(
      reason: 'refresh_if_needed',
      forceIdTokenRefresh: false,
      allowFirebaseBootstrap: true,
      preferFirebaseBootstrap: false,
    );
    if (refreshed == SessionRecoveryStatus.recovered) {
      return true;
    }
    if (_isAccessTokenValid()) {
      return true;
    }
    return false;
  }

  Future<SessionRecoveryStatus> attemptSilentRecovery({
    String reason = 'unauthorized',
  }) async {
    debugPrint('AuthSessionService: silent recovery requested ($reason).');
    return _ensureBackendSession(
      reason: reason,
      forceIdTokenRefresh: true,
      allowFirebaseBootstrap: true,
      preferFirebaseBootstrap: false,
    );
  }

  Future<void> saveUserSnapshot(AppUser? user) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      _userSnapshot = null;
      await prefs.remove(_kUserSnapshot);
      return;
    }
    final snapshot = {
      'id': user.id,
      'role': user.role,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'storeId': user.storeId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _userSnapshot = snapshot;
    await prefs.setString(_kUserSnapshot, jsonEncode(snapshot));
  }

  Map<String, dynamic>? get userSnapshot => _userSnapshot;

  Future<void> clearSession({String reason = 'logout'}) async {
    debugPrint('AuthSessionService: clearing session ($reason).');
    _sessionGeneration += 1;
    _cancelActiveRefresh(reason: 'clear_session');
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiresAt = null;
    _refreshTokenExpiresAt = null;
    _sessionId = null;
    _userSnapshot = null;
    final prefs = await SharedPreferences.getInstance();
    final storageClears = <Future<void>>[
      _secureStorage.delete(key: _kAccessToken),
      _secureStorage.delete(key: _kRefreshToken),
      _secureStorage.delete(key: _kAccessTokenExpiresAt),
      _secureStorage.delete(key: _kRefreshTokenExpiresAt),
      _secureStorage.delete(key: _kSessionId),
      prefs.remove(_kUserSnapshot),
    ];
    await Future.wait(storageClears);
  }

  Future<void> revokeCurrentSession({String reason = 'logout'}) async {
    _cancelActiveRefresh(reason: 'revoke_current_session');
    final refreshToken = _refreshToken;
    final sessionId = _sessionId;
    if (AppConfig.hasBackendBaseUrl &&
        ((refreshToken != null && refreshToken.isNotEmpty) ||
            (sessionId != null && sessionId.isNotEmpty))) {
      try {
        debugPrint('AuthSessionService: revoking backend session ($reason).');
        await http
            .post(
              Uri.parse('${AppConfig.backendBaseUrl}/auth/session/logout'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                if (refreshToken != null && refreshToken.isNotEmpty)
                  'refreshToken': refreshToken,
                if (sessionId != null && sessionId.isNotEmpty)
                  'sessionId': sessionId,
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (error) {
        debugPrint(
          'AuthSessionService: backend session revoke skipped: $error',
        );
      }
    }
    await clearSession(reason: reason);
  }

  Future<void> persistSession({
    required String accessToken,
    required String refreshToken,
    required String sessionId,
    required DateTime accessTokenExpiresAt,
    required DateTime refreshTokenExpiresAt,
    Map<String, dynamic>? userSnapshot,
    int? generation,
  }) async {
    await initialize();
    if (generation != null && generation != _sessionGeneration) {
      debugPrint('AuthSessionService: skipped persisting stale session state.');
      return;
    }
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _sessionId = sessionId;
    _accessTokenExpiresAt = accessTokenExpiresAt;
    _refreshTokenExpiresAt = refreshTokenExpiresAt;
    if (userSnapshot != null) {
      _userSnapshot = userSnapshot;
    }
    final values = <String, String>{
      _kAccessToken: accessToken,
      _kRefreshToken: refreshToken,
      _kAccessTokenExpiresAt: accessTokenExpiresAt.toIso8601String(),
      _kRefreshTokenExpiresAt: refreshTokenExpiresAt.toIso8601String(),
      _kSessionId: sessionId,
    };
    await Future.wait(
      values.entries.map(
        (entry) => _secureStorage.write(key: entry.key, value: entry.value),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    if (userSnapshot != null) {
      await prefs.setString(_kUserSnapshot, jsonEncode(userSnapshot));
    }
  }

  void _cancelActiveRefresh({required String reason}) {
    final refreshOperation = _refreshOperation;
    if (refreshOperation != null && !refreshOperation.completer.isCompleted) {
      debugPrint('AuthSessionService: refresh cancelled ($reason).');
      refreshOperation.completer.complete(SessionRecoveryStatus.failed);
    }
    refreshOperation?.timeoutTimer?.cancel();
    _refreshOperation = null;
    _refreshAttemptSerial += 1;
  }

  Future<SessionRecoveryStatus> _bootstrapFromFirebase(
    User firebaseUser, {
    bool forceRefreshIdToken = false,
  }) async {
    if (!AppConfig.hasBackendBaseUrl) {
      return SessionRecoveryStatus.failed;
    }
    if (_refreshOperation != null) {
      return _awaitRefreshOperation();
    }
    final generation = _sessionGeneration;
    final attemptSerial = ++_refreshAttemptSerial;

    return _runRefreshOperation(
      operationName: 'bootstrap',
      timeout: _bootstrapTimeout,
      attemptSerial: attemptSerial,
      action: () => _bootstrapSession(
        firebaseUser: firebaseUser,
        forceRefreshIdToken: forceRefreshIdToken,
        generation: generation,
        attemptSerial: attemptSerial,
      ),
    );
  }

  Future<SessionRecoveryStatus> _refreshBackendSession({
    bool force = false,
  }) async {
    if (_refreshOperation != null) {
      return _awaitRefreshOperation();
    }
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return SessionRecoveryStatus.failed;
    }
    if (!force && _isAccessTokenValid()) {
      return SessionRecoveryStatus.recovered;
    }

    if (_refreshTokenExpiresAt != null &&
        _refreshTokenExpiresAt!.isBefore(DateTime.now())) {
      debugPrint('AuthSessionService: refresh token expired.');
      return SessionRecoveryStatus.failed;
    }
    final generation = _sessionGeneration;
    final attemptSerial = ++_refreshAttemptSerial;
    return _runRefreshOperation(
      operationName: 'refresh',
      timeout: _refreshTimeout,
      attemptSerial: attemptSerial,
      action: () => _refreshSession(
        refreshToken: refreshToken,
        generation: generation,
        attemptSerial: attemptSerial,
      ),
    );
  }

  Future<SessionRecoveryStatus> _bootstrapSession({
    required User firebaseUser,
    required bool forceRefreshIdToken,
    required int generation,
    required int attemptSerial,
  }) async {
    final deviceId = await ensureDeviceId();
    String? idToken;
    try {
      idToken = await firebaseUser
          .getIdToken(forceRefreshIdToken)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
        'AuthSessionService: firebaseUser.getIdToken failed during bootstrap: $e',
      );
    }

    if (idToken == null || idToken.isEmpty) {
      debugPrint(
        'AuthSessionService: firebase ID token missing during bootstrap.',
      );
      return SessionRecoveryStatus.failed;
    }

    debugPrint(
      'AuthSessionService: bootstrapping backend session for ${firebaseUser.uid}.',
    );
    final response = await http
        .post(
          Uri.parse('${AppConfig.backendBaseUrl}/auth/session'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'deviceId': deviceId,
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'sessionSource': 'firebase',
          }),
        )
        .timeout(_bootstrapTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'AuthSessionService: session bootstrap failed (${response.statusCode}).',
      );
      if (response.statusCode == 429) {
        return SessionRecoveryStatus.rateLimited;
      }
      if (response.statusCode == 403) {
        return SessionRecoveryStatus.unprovisioned;
      }
      return SessionRecoveryStatus.failed;
    }

    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    return await _applySessionResponse(
          data,
          generation: generation,
          attemptSerial: attemptSerial,
        )
        ? SessionRecoveryStatus.recovered
        : SessionRecoveryStatus.failed;
  }

  Future<SessionRecoveryStatus> _refreshSession({
    required String refreshToken,
    required int generation,
    required int attemptSerial,
  }) async {
    debugPrint('AuthSessionService: refreshing backend session.');
    final response = await http
        .post(
          Uri.parse('${AppConfig.backendBaseUrl}/auth/session/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_refreshTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'AuthSessionService: refresh failed (${response.statusCode}).',
      );
      if (response.statusCode == 429) {
        return SessionRecoveryStatus.rateLimited;
      }
      return _isTransientNetworkResponse(response)
          ? SessionRecoveryStatus.offline
          : SessionRecoveryStatus.failed;
    }

    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    return await _applySessionResponse(
          data,
          generation: generation,
          attemptSerial: attemptSerial,
        )
        ? SessionRecoveryStatus.recovered
        : SessionRecoveryStatus.failed;
  }

  Future<bool> _applySessionResponse(
    Map<String, dynamic> data, {
    required int generation,
    required int attemptSerial,
  }) async {
    if (_refreshAttemptSerial != attemptSerial ||
        generation != _sessionGeneration) {
      debugPrint('AuthSessionService: stale refresh ignored.');
      return false;
    }
    final accessToken = data['accessToken']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';
    final sessionId = data['sessionId']?.toString() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty || sessionId.isEmpty) {
      debugPrint(
        'AuthSessionService: session payload is missing required fields.',
      );
      return false;
    }

    final accessExpiry =
        _tokenExpiryFromJwt(accessToken) ??
        DateTime.now().add(
          Duration(
            seconds:
                int.tryParse(data['accessTokenExpiresIn']?.toString() ?? '') ??
                15 * 60,
          ),
        );
    final refreshExpiryValue = data['refreshTokenExpiresAt']?.toString() ?? '';
    final refreshExpiry =
        DateTime.tryParse(refreshExpiryValue) ??
        DateTime.now().add(
          Duration(
            seconds:
                int.tryParse(data['refreshTokenExpiresIn']?.toString() ?? '') ??
                30 * 24 * 60 * 60,
          ),
        );
    final snapshot = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : null;

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _sessionId = sessionId;
    _accessTokenExpiresAt = accessExpiry;
    _refreshTokenExpiresAt = refreshExpiry;
    _userSnapshot = snapshot ?? _userSnapshot;
    await persistSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionId: sessionId,
      accessTokenExpiresAt: accessExpiry,
      refreshTokenExpiresAt: refreshExpiry,
      userSnapshot: snapshot,
      generation: generation,
    );
    debugPrint(
      'AuthSessionService: session updated, access expires at ${accessExpiry.toIso8601String()}.',
    );
    return true;
  }

  bool _isAccessTokenValid() {
    if ((_accessToken ?? '').isEmpty) {
      return false;
    }
    final expiresAt =
        _accessTokenExpiresAt ?? _tokenExpiryFromJwt(_accessToken!);
    if (expiresAt == null) {
      return false;
    }
    return expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 60)));
  }

  bool _shouldProactivelyRefreshToken() {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return false;
    }
    final expiresAt = _accessTokenExpiresAt ?? _tokenExpiryFromJwt(token);
    if (expiresAt == null) {
      return true;
    }
    return expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 2)));
  }

  Future<void> _restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kDeviceId)?.trim();
    _accessToken = await _secureStorage.read(key: _kAccessToken);
    _refreshToken = await _secureStorage.read(key: _kRefreshToken);
    _sessionId = await _secureStorage.read(key: _kSessionId);
    _accessTokenExpiresAt = _parseDate(
      await _secureStorage.read(key: _kAccessTokenExpiresAt),
    );
    _refreshTokenExpiresAt = _parseDate(
      await _secureStorage.read(key: _kRefreshTokenExpiresAt),
    );
    final snapshotJson = prefs.getString(_kUserSnapshot);
    if (snapshotJson != null && snapshotJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(snapshotJson);
        if (decoded is Map<String, dynamic>) {
          _userSnapshot = decoded;
        } else if (decoded is Map) {
          _userSnapshot = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        _userSnapshot = null;
      }
    }
  }

  Future<SessionRecoveryStatus> _ensureBackendSession({
    required String reason,
    required bool forceIdTokenRefresh,
    required bool allowFirebaseBootstrap,
    required bool preferFirebaseBootstrap,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      debugPrint('AuthSessionService: no Firebase user available for $reason.');
      return SessionRecoveryStatus.failed;
    }

    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      debugPrint('AuthSessionService: backend session bootstrap deferred due to rate limiting.');
      return SessionRecoveryStatus.rateLimited;
    }

    final accessStatus = await _refreshBackendSession(
      force: forceIdTokenRefresh,
    );
    if (accessStatus == SessionRecoveryStatus.recovered) {
      debugPrint('AuthSessionService: backend session refreshed ($reason).');
      return SessionRecoveryStatus.recovered;
    }
    if (accessStatus == SessionRecoveryStatus.offline) {
      debugPrint(
        'AuthSessionService: backend refresh deferred by offline state ($reason).',
      );
      return SessionRecoveryStatus.offline;
    }

    if (!allowFirebaseBootstrap) {
      return SessionRecoveryStatus.failed;
    }

    final bootstrapStatus = await _bootstrapFromFirebase(
      firebaseUser,
      forceRefreshIdToken: preferFirebaseBootstrap || forceIdTokenRefresh,
    );
    if (bootstrapStatus == SessionRecoveryStatus.recovered) {
      debugPrint('AuthSessionService: backend session bootstrapped ($reason).');
      return SessionRecoveryStatus.recovered;
    }
    return bootstrapStatus;
  }

  Future<SessionRecoveryStatus> _runRefreshOperation({
    required String operationName,
    required Duration timeout,
    required int attemptSerial,
    required Future<SessionRecoveryStatus> Function() action,
  }) async {
    final existingOperation = _refreshOperation;
    if (existingOperation != null) {
      existingOperation.waiterCount += 1;
      debugPrint(
        'AuthSessionService: waiting for in-flight $operationName (queued=${existingOperation.waiterCount}).',
      );
      return existingOperation.future;
    }
    final operation = _RefreshOperationState(
      operationName: operationName,
      attemptSerial: attemptSerial,
    );
    _refreshOperation = operation;
    debugPrint(
      'AuthSessionService: $operationName started (attempt=$attemptSerial).',
    );

    operation.timeoutTimer = Timer(timeout, () {
      _finishRefreshOperation(
        operation,
        SessionRecoveryStatus.offline,
        reason: '$operationName timeout after ${timeout.inSeconds}s',
      );
    });

    unawaited(_performRefreshOperation(operation, action));
    return operation.future;
  }

  Future<SessionRecoveryStatus> _awaitRefreshOperation() async {
    final operation = _refreshOperation;
    if (operation == null) {
      return SessionRecoveryStatus.failed;
    }
    operation.waiterCount += 1;
    debugPrint(
      'AuthSessionService: waiting for existing refresh operation (queued=${operation.waiterCount}).',
    );
    try {
      return await operation.future;
    } finally {
      operation.waiterCount = max(0, operation.waiterCount - 1);
    }
  }

  Future<void> _performRefreshOperation(
    _RefreshOperationState operation,
    Future<SessionRecoveryStatus> Function() action,
  ) async {
    try {
      final result = await action();
      _finishRefreshOperation(
        operation,
        result,
        reason: '${operation.operationName} completed',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AuthSessionService: ${operation.operationName} failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      final result = _isTransientNetworkError(error)
          ? SessionRecoveryStatus.offline
          : SessionRecoveryStatus.failed;
      _finishRefreshOperation(
        operation,
        result,
        reason: '${operation.operationName} failed',
      );
    }
  }

  void _finishRefreshOperation(
    _RefreshOperationState operation,
    SessionRecoveryStatus result, {
    required String reason,
  }) {
    if (!identical(_refreshOperation, operation)) {
      debugPrint(
        'AuthSessionService: stale ${operation.operationName} response ignored (attempt=${operation.attemptSerial}).',
      );
      return;
    }
    operation.timeoutTimer?.cancel();
    operation.timeoutTimer = null;
    if (!operation.completer.isCompleted) {
      operation.completer.complete(result);
    }
    final queued = operation.waiterCount;
    debugPrint(
      'AuthSessionService: ${operation.operationName} finished with ${result.name} (attempt=${operation.attemptSerial}, queued=$queued).',
    );
    if (result == SessionRecoveryStatus.recovered) {
      debugPrint(
        'AuthSessionService: queued requests replayed for ${operation.operationName} (count=$queued).',
      );
    } else {
      if (result == SessionRecoveryStatus.rateLimited) {
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 45));
        debugPrint('AuthSessionService: Backoff activated for 45 seconds due to 429 Rate Limit.');
      }
      debugPrint(
        'AuthSessionService: queued requests rejected for ${operation.operationName} (count=$queued, result=${result.name}).',
      );
    }
    _refreshOperation = null;
  }

  bool _isTransientNetworkResponse(http.Response response) {
    return response.statusCode >= 500 || response.statusCode == 429;
  }

  bool _isTransientNetworkError(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      return message.contains('socketexception') ||
          message.contains('handshakeexception') ||
          message.contains('failed host lookup') ||
          message.contains('connection closed') ||
          message.contains('software caused connection abort');
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('handshakeexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('software caused connection abort');
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  DateTime? _tokenExpiryFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is Map && payload['exp'] != null) {
        final expSeconds = int.tryParse(payload['exp'].toString());
        if (expSeconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _generateId({required String prefix}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBits = List<int>.generate(8, (_) => _random.nextInt(256));
    final randomHex = randomBits
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$prefix-$timestamp-$randomHex';
  }
}
