import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/auth_session_service.dart';
import '../services/backend_api_client.dart';
import '../services/backend_commerce_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/app_navigation_service.dart';
import '../services/storage_service.dart';
import '../utils/app_mode_routes.dart';
import '../app_shell.dart';
import 'auth_session_recovery_policy.dart';

class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final AuthSessionService _sessionService = AuthSessionService.instance;
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final DatabaseService _db = DatabaseService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  StreamSubscription<AppUser?>? _userSubscription;
  StreamSubscription<AppUser?>? _liveProfileSubscription;
  AppUser? _user;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  bool _isInitialized = false;
  bool _isRestoringSession = false;
  bool _isLoggingOut = false;
  bool _isRefreshingAuthToken = false;
  DateTime? _lastSignInAt;
  DateTime? _lastTokenRefreshAt;
  DateTime? _lastUnauthorizedRecoveryAttemptAt;
  String? _pendingPhoneNumber;
  String? _lastBackendProfileSyncKey;
  AbzioAppMode mode = AbzioAppMode.customer;

  bool _profileLoaded = false;
  bool _vendorPermissionsResolved = false;
  // True while _restoreSession() is in progress. Route guards must
  // treat this like !isInitialized and show a loading state.
  bool get isSessionRestoring => _isRestoringSession;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get profileLoaded => _profileLoaded;
  bool get vendorProfileLoaded => _profileLoaded;
  bool get vendorPermissionsResolved => _vendorPermissionsResolved;
  bool get isSuperAdmin =>
      hasAdminAccess(_user);
  bool get isVendor => hasVendorOperationsAccess(_user);
  bool get isRider => hasRiderOperationsAccess(_user);
  bool get isUser => _user?.role == 'user' || _user?.role == 'customer';
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  int get profileCompletion {
    final current = _user;
    if (current == null) {
      return 20;
    }
    var score = 35;
    if (current.name.trim().isNotEmpty) score += 20;
    if ((current.phone ?? '').trim().isNotEmpty) score += 15;
    if ((current.address ?? '').trim().isNotEmpty) score += 20;
    if ((current.city ?? '').trim().isNotEmpty) score += 10;
    return score.clamp(20, 100);
  }

  bool get profileVerified => profileCompletion >= 100;

  bool get requiresProfileSetup {
    final current = _user;
    if (current == null) {
      return false;
    }
    if (profileCompletion >= 100) {
      return false;
    }
    return current.name.trim().isEmpty ||
        (current.address ?? '').trim().isEmpty;
  }

  AuthProvider() {
    debugPrint('=== AUTH INIT START ===');
    BackendApiClient.registerUnauthorizedHandler(_handleUnauthorizedSession);
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
    _userSubscription = _authService.user.listen((user) {
      // IMPORTANT: Do NOT update auth state or set _isInitialized while
      // _restoreSession() is in progress. The restore sequence is the
      // authoritative startup path; the Firebase listener is only for
      // live session changes AFTER startup completes. Setting
      // _isInitialized = true here before restore finishes causes
      // route guards to fire prematurely with a null user and redirect
      // to /admin-login even when valid tokens exist.
      if (_isRestoringSession) {
        debugPrint('[AUTH] authStateChanges fired during restore – deferring.');
        return;
      }
      _bindLiveProfile(user);
      _profileLoaded = true;
      _vendorPermissionsResolved = true;
      _isInitialized = true;
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResumed());
    }
  }

  void _bindLiveProfile(AppUser? user) {
    final previousProfileSubscription = _liveProfileSubscription;
    _liveProfileSubscription = null;
    unawaited(previousProfileSubscription?.cancel() ?? Future<void>.value());
    AppUser? mappedUser = user;
    if (mappedUser != null) {
      final role = mode == AbzioAppMode.vendor ? 'vendor' : mode == AbzioAppMode.rider ? 'rider' : 'customer';
      mappedUser = mappedUser.copyWith(activeRole: role, accountType: role);
    }
    _user = mappedUser;
    _isAuthenticated = mappedUser != null;
    debugPrint(
      'AuthProvider: auth state changed -> ${mappedUser == null ? 'signed_out' : 'signed_in:${mappedUser.id}'}',
    );
    if (mappedUser != null) {
      debugPrint('=== PERMISSION RESOLUTION START ===');
      debugPrint('=== PERMISSION RESOLUTION COMPLETE ===');
    }
    if (mappedUser == null) {
      _token = null;
      _lastBackendProfileSyncKey = null;
      unawaited(_sessionService.saveUserSnapshot(null));
      return;
    }
    unawaited(_sessionService.saveUserSnapshot(mappedUser));
    unawaited(_refreshAuthToken());
    unawaited(_syncNotificationChannels(mappedUser));
    _maybeSyncBackendProfile(mappedUser);
    _liveProfileSubscription = _db.watchUser(mappedUser.id).listen((liveUser) {
      AppUser? nextUser = liveUser ?? mappedUser;
      if (nextUser != null) {
        final role = mode == AbzioAppMode.vendor ? 'vendor' : mode == AbzioAppMode.rider ? 'rider' : 'customer';
        nextUser = nextUser.copyWith(activeRole: role, accountType: role);
      }
      if (_isSameUserSnapshot(_user, nextUser)) {
        return;
      }
      _user = nextUser;
      _isAuthenticated = _user != null;
      if (_user != null) {
        _maybeSyncBackendProfile(_user!);
        unawaited(_syncNotificationChannels(_user!));
      }
      unawaited(_refreshAuthToken());
      notifyListeners();
    });
  }

  bool _isSameUserSnapshot(AppUser? left, AppUser? right) {
    if (identical(left, right)) {
      return true;
    }
    if (left == null || right == null) {
      return left == right;
    }
    return left.id == right.id &&
        left.name == right.name &&
        left.email == right.email &&
        left.profileImageUrl == right.profileImageUrl &&
        left.phone == right.phone &&
        left.address == right.address &&
        left.area == right.area &&
        left.city == right.city &&
        left.latitude == right.latitude &&
        left.longitude == right.longitude &&
        left.deliveryRadiusKm == right.deliveryRadiusKm &&
        left.locationUpdatedAt == right.locationUpdatedAt &&
        left.createdAt == right.createdAt &&
        left.role == right.role &&
        left.isActive == right.isActive &&
        left.storeId == right.storeId &&
        left.walletBalance == right.walletBalance &&
        mapEquals(left.roles, right.roles) &&
        left.riderApprovalStatus == right.riderApprovalStatus &&
        left.riderVehicleType == right.riderVehicleType &&
        left.riderLicenseNumber == right.riderLicenseNumber &&
        left.riderCity == right.riderCity &&
        left.referralCode == right.referralCode &&
        left.referredBy == right.referredBy;
  }

  Future<void> _syncNotificationChannels(AppUser user) async {
    final notifications = NotificationService();
    final initialized = await notifications.initNotifications();
    if (!initialized) {
      return;
    }
    await notifications.syncToken(user);
  }

  Future<void> _refreshAuthToken({bool forceRefresh = false}) async {
    if (_isRefreshingAuthToken) {
      return;
    }
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastTokenRefreshAt != null &&
        now.difference(_lastTokenRefreshAt!).inSeconds < 30) {
      return;
    }
    _isRefreshingAuthToken = true;
    try {
      final token = await _sessionService.authorizationToken(
        forceRefresh: forceRefresh,
      );
      if (token == null || token.isEmpty) {
        _lastTokenRefreshAt = DateTime.now();
        return;
      }
      _lastTokenRefreshAt = DateTime.now();
      if (token != _token) {
        _token = token;
        _isAuthenticated = _user != null;
        if (_user != null) {
          _maybeSyncBackendProfile(_user!);
        }
        notifyListeners();
      }
    } catch (error) {
      debugPrint('AuthProvider: token refresh failed: $error');
      _lastTokenRefreshAt = DateTime.now();
      // Keep existing session state on transient token refresh failures.
    } finally {
      _isRefreshingAuthToken = false;
    }
  }

  void _maybeSyncBackendProfile(AppUser user) {
    if (!_backendCommerce.isConfigured ||
        (_token?.isNotEmpty ?? false) == false) {
      return;
    }
    final syncKey = [
      user.id,
      user.name,
      user.email,
      user.phone ?? '',
      user.role,
      user.activeRole,
      user.accountType,
      user.isActive,
      user.storeId ?? '',
      user.roles.toString(),
      user.riderApprovalStatus,
      user.riderVehicleType ?? '',
      user.riderLicenseNumber ?? '',
      user.riderCity ?? '',
    ].join('|');
    if (_lastBackendProfileSyncKey == syncKey) {
      return;
    }
    _lastBackendProfileSyncKey = syncKey;
    unawaited(_syncBackendProfile(user));
  }

  Future<void> _syncBackendProfile(AppUser user) async {
    try {
      await _backendCommerce.syncUserProfile(user);
    } catch (_) {
      // Firebase remains the source of truth while backend sync is best-effort.
    }
  }

  String? _restoreError;
  String? get restoreError => _restoreError;

  Future<void>? _sessionRestoreFuture;

  Future<void> _restoreSession() async {
    if (_sessionRestoreFuture != null) {
      debugPrint('[AUTH] Session restore already in progress');
      return await _sessionRestoreFuture!;
    }
    _sessionRestoreFuture = _executeRestoreSession();
    try {
      await _sessionRestoreFuture!;
    } finally {
      _sessionRestoreFuture = null;
    }
  }

  Future<void> _executeRestoreSession() async {
    _isRestoringSession = true;
    debugPrint('[BOOT] 4 Auth restore start');
    debugPrint('=== PROFILE LOAD START ===');
    debugPrint('=== VENDOR LOAD START ===');
    try {
      debugPrint('[AUTH] Session validation started');
      debugPrint('[BOOT] 4.1 sessionService.initialize');
      await _sessionService.initialize();
      if (_sessionService.hasBackendSession ||
          _sessionService.sessionId != null) {
        debugPrint('[AUTH] Token restored');
      }

      debugPrint('[BOOT] 4.2 auth currentUser snapshot');
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        debugPrint('[AUTH] Firebase user present during restore');
      }

      debugPrint('[BOOT] 4.3 sessionService.refreshIfNeeded');
      await _sessionService.refreshIfNeeded();

      debugPrint('[BOOT] 4.4 getCurrentAppUser');
      AppUser? existingUser;
      try {
        existingUser = await _authService.getCurrentAppUser();
      } on BackendApiException catch (e) {
        // 5xx and 429 are transient: fall back to snapshot.
        // 401 means tokens are genuinely invalid: existingUser stays null.
        if (e.statusCode != 401) {
          debugPrint(
            '[AUTH] getCurrentAppUser transient error (${e.statusCode}) – falling back to snapshot.',
          );
        } else {
          debugPrint('[AUTH] getCurrentAppUser 401 – session is invalid.');
        }
      } catch (e) {
        // Network error, timeout, etc. – fall back to snapshot.
        debugPrint(
          '[AUTH] getCurrentAppUser failed with non-api error – falling back to snapshot: $e',
        );
      }

      if (existingUser == null && _sessionService.userSnapshot != null) {
        // Restore the last-known user from the persisted snapshot so the
        // admin stays on the dashboard even if /me is temporarily unavailable.
        final snapshot = _sessionService.userSnapshot!;
        debugPrint(
          '[AUTH] Using persisted userSnapshot as fallback (role=${snapshot['role']}).',
        );
        existingUser = AppUser.fromMap({
          ...snapshot,
          'name': snapshot['name'] ?? '',
          'email': snapshot['email'] ?? '',
          'address': '',
          'area': '',
          'city': '',
          'isActive': true,
          'walletBalance': 0,
          'roles': {},
          'riderApprovalStatus': '',
        });
      }

      if (existingUser != null) {
        _bindLiveProfile(existingUser);
        await _sessionService.saveUserSnapshot(existingUser);
        await _refreshAuthToken(forceRefresh: false);
      }
      debugPrint('[BOOT] 4 Auth restore done');
      debugPrint(
        '[AUTH] Session restored successfully (user=${existingUser?.id ?? "none"})',
      );
    } catch (e, st) {
      // Only set _restoreError for genuine, unexpected programming errors.
      // Transient network/API errors are handled inside the try block above.
      _restoreError = '$e\n$st';
      debugPrint('[BOOT ERROR] Auth restore (unexpected): $_restoreError');
    } finally {
      debugPrint('AuthProvider: session restore complete (user=${_user?.id}).');
      debugPrint('=== VENDOR LOAD COMPLETE ===');
      debugPrint('=== PROFILE LOAD COMPLETE ===');
      debugPrint('=== AUTH INIT COMPLETE ===');
      _isRestoringSession = false;
      _profileLoaded = true;
      _vendorPermissionsResolved = true;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.requestOtp(phoneNumber);
      _pendingPhoneNumber = phoneNumber;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AppUser?> verifyOtp(String otp) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('=== PROFILE LOAD START ===');
      debugPrint('=== VENDOR LOAD START ===');
      final result = await _authService.verifyOtp(otp);
      _lastSignInAt = DateTime.now();
      _bindLiveProfile(result);
      _profileLoaded = true;
      _vendorPermissionsResolved = true;
      debugPrint('=== VENDOR LOAD COMPLETE ===');
      debugPrint('=== PROFILE LOAD COMPLETE ===');
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AppUser?> refreshProfileFromBackendIfPossible() async {
    if (!_backendCommerce.isConfigured) {
      return _user;
    }
    try {
      debugPrint('=== PROFILE LOAD START ===');
      debugPrint('=== VENDOR LOAD START ===');
      final backendUser = await _backendCommerce.getCurrentUserProfile();
      _user = backendUser;
      _isAuthenticated = _user != null;
      _profileLoaded = true;
      _vendorPermissionsResolved = true;
      debugPrint('=== VENDOR LOAD COMPLETE ===');
      debugPrint('=== PROFILE LOAD COMPLETE ===');
      _maybeSyncBackendProfile(backendUser);
      unawaited(_syncNotificationChannels(backendUser));
      unawaited(_db.saveUser(backendUser));
      await _sessionService.saveUserSnapshot(backendUser);
      notifyListeners();
      return backendUser;
    } catch (_) {
      return _user;
    }
  }

  Future<AppUser?> signInWithGoogleAdmin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogleAdmin();
      _lastSignInAt = DateTime.now();
      _bindLiveProfile(result);
      _profileLoaded = true;
      _vendorPermissionsResolved = true;
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogleUser();
      _lastSignInAt = DateTime.now();
      _bindLiveProfile(result);
      _profileLoaded = true;
      _vendorPermissionsResolved = true;
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout({
    bool resetNavigation = false,
    bool showSuccessMessage = false,
    String successMessage = 'Logged out successfully',
  }) async {
    if (_isLoggingOut) {
      return;
    }
    _isLoggingOut = true;
    final currentUserId = _user?.id;
    debugPrint(
      'AuthProvider: logout requested (userId: ${currentUserId ?? 'none'}).',
    );
    try {
      await _authService.signOut();
    } finally {
      await _liveProfileSubscription?.cancel();
      await _sessionService.revokeCurrentSession(reason: 'logout');
      await _clearLocalUserCache(currentUserId);
      _clearMemoryState();
      notifyListeners();
      _isLoggingOut = false;
    }

    if (resetNavigation) {
      await AppNavigationService.resetToHome(
        message: showSuccessMessage ? successMessage : null,
      );
    }
  }

  Future<void> _handleUnauthorizedSession() async {
    if (!_isAuthenticated || _isLoggingOut || _isRestoringSession) {
      return;
    }
    final signedInJustNow =
        _lastSignInAt != null &&
        DateTime.now().difference(_lastSignInAt!).inSeconds < 30;
    if (signedInJustNow) {
      return;
    }
    final now = DateTime.now();
    if (_lastUnauthorizedRecoveryAttemptAt != null &&
        now.difference(_lastUnauthorizedRecoveryAttemptAt!).inSeconds < 30) {
      return;
    }
    _lastUnauthorizedRecoveryAttemptAt = now;
    debugPrint(
      'AuthProvider: unauthorized session detected, attempting silent recovery.',
    );

    final recovery = await _sessionService.attemptSilentRecovery(
      reason: 'auth_provider',
    );
    if (recovery == SessionRecoveryStatus.offline) {
      debugPrint(
        'AuthProvider: recovery deferred because the device is offline.',
      );
      return;
    }
    if (recovery == SessionRecoveryStatus.recovered) {
      await _refreshAuthToken(forceRefresh: true);
      if (_token != null && _token!.isNotEmpty) {
        return;
      }
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        debugPrint(
          'AuthProvider: backend recovery succeeded but token refresh was empty; keeping Firebase session alive.',
        );
        return;
      }
      return;
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      debugPrint(
        'AuthProvider: backend recovery failed, but Firebase session is still present; keeping user signed in until explicit logout.',
      );
      await _refreshAuthToken(forceRefresh: true);
      return;
    }
    if (!shouldForceLogoutAfterUnauthorizedRecovery(
      isRestoringSession: _isRestoringSession,
      firebaseUserPresent: firebaseUser != null,
      localUserPresent: _user != null,
    )) {
      debugPrint(
        'AuthProvider: backend recovery failed, but a live session source is still present; keeping the user signed in.',
      );
      return;
    }
    await logout();
    await AppNavigationService.resetToHome(
      message: 'Your session could not be restored. Please sign in again.',
    );
  }

  Future<void> _handleAppResumed() async {
    if (!_isAuthenticated || _isLoggingOut) {
      return;
    }
    debugPrint('AuthProvider: app resumed, validating session silently.');
    final refreshed = await _sessionService.refreshIfNeeded();
    if (!refreshed) {
      return;
    }
    await _refreshAuthToken(forceRefresh: false);
  }

  Future<void> _clearLocalUserCache(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        final isSessionScoped =
            key == 'abianzo_local_cart_v1' || key.startsWith('payment_pref_');
        final isUserScoped =
            userId != null && userId.isNotEmpty && key.contains(userId);
        if (isSessionScoped || isUserScoped) {
          await prefs.remove(key);
        }
      }
    } catch (_) {
      // Keep logout resilient even if cache cleanup fails.
    }
  }

  void _clearMemoryState() {
    _user = null;
    _token = null;
    _isAuthenticated = false;
    _pendingPhoneNumber = null;
    _lastBackendProfileSyncKey = null;
    _lastSignInAt = null;
    _lastTokenRefreshAt = null;
    _lastUnauthorizedRecoveryAttemptAt = null;
  }

  void setUser(AppUser user) {
    _bindLiveProfile(user);
    notifyListeners();
  }

  Future<void> switchRole(String role) async {
    if (_user != null) {
      final normalizedRole = role.trim().toLowerCase();
      if (normalizedRole.isEmpty) {
        return;
      }
      final updatedRoles = Map<String, bool>.from(_user!.roles);
      updatedRoles[normalizedRole] = true;
      final optimisticUser = _user!.copyWith(
        activeRole: normalizedRole,
        accountType: normalizedRole,
        roles: updatedRoles,
      );
      _user = optimisticUser;
      _lastBackendProfileSyncKey = null;
      unawaited(_db.saveUser(optimisticUser));
      unawaited(_sessionService.saveUserSnapshot(optimisticUser));
      notifyListeners();
      try {
        final backendUser = await _backendCommerce.switchActiveRole(
          user: optimisticUser,
          activeRole: normalizedRole,
        );
        if (backendUser != null) {
          _bindLiveProfile(backendUser);
          _lastBackendProfileSyncKey = null;
          unawaited(_db.saveUser(backendUser));
          await _sessionService.saveUserSnapshot(backendUser);
          notifyListeners();
          return;
        }
      } catch (error) {
        debugPrint('AuthProvider: backend role switch failed: $error');
      }
      _maybeSyncBackendProfile(optimisticUser);
    }
  }

  void setRole(String role) {
    unawaited(switchRole(role));
  }

  Future<void> refreshCurrentUser() async {
    final current = await _authService.getCurrentAppUser();
    if (current != null) {
      _bindLiveProfile(current);
      await _sessionService.saveUserSnapshot(current);
      unawaited(_refreshAuthToken());
      notifyListeners();
    }
  }

  Future<void> saveProfile({
    required String name,
    required String address,
    String? area,
    String? city,
    double? latitude,
    double? longitude,
    double? deliveryRadiusKm,
  }) async {
    final current = _user;
    if (current == null) {
      return;
    }
    _isUpdatingProfile = true;
    notifyListeners();
    try {
      final updated = current.copyWith(
        name: name.trim(),
        address: address.trim(),
        area: area ?? current.area,
        city: city ?? current.city,
        latitude: latitude ?? current.latitude,
        longitude: longitude ?? current.longitude,
        deliveryRadiusKm: deliveryRadiusKm ?? current.deliveryRadiusKm,
        locationUpdatedAt: (latitude != null || longitude != null)
            ? DateTime.now().toIso8601String()
            : current.locationUpdatedAt,
        createdAt: current.createdAt ?? DateTime.now().toIso8601String(),
      );
      await _db.saveUser(updated, bestEffort: true);
      _user = updated;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  Future<void> fillAddressFromGps({String? fallbackName}) async {
    final current = _user;
    if (current == null) {
      return;
    }
    _isUpdatingProfile = true;
    notifyListeners();
    try {
      final location = await _locationService.getCurrentLocation(
        forceRefresh: true,
      );
      if (location.status != LocationStatus.success ||
          location.position == null) {
        throw StateError('Unable to detect location');
      }
      final position = location.position!;
      final resolvedAddress =
          location.address ??
          await _locationService.reverseGeocode(
            position.latitude,
            position.longitude,
          );
      final updated = current.copyWith(
        name: (fallbackName ?? current.name).trim(),
        address: resolvedAddress.address,
        area: resolvedAddress.area,
        city: resolvedAddress.city,
        latitude: position.latitude,
        longitude: position.longitude,
        locationUpdatedAt: DateTime.now().toIso8601String(),
        createdAt: current.createdAt ?? DateTime.now().toIso8601String(),
      );
      await _db.saveUser(updated, bestEffort: true);
      _user = updated;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  Future<void> updateProfileImage(XFile file) async {
    final current = _user;
    if (current == null) {
      return;
    }
    _isUpdatingProfile = true;
    notifyListeners();
    try {
      final uploadedUrl = await _storageService.uploadPickedImage(
        file: file,
        folder: 'user_profiles',
        ownerId: current.id,
        fileName: 'profile',
      );
      await _db.updateUserProfile(
        userId: current.id,
        profileImageUrl: uploadedUrl,
      );
      _user = current.copyWith(profileImageUrl: uploadedUrl);
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BackendApiClient.registerUnauthorizedHandler(null);
    unawaited(_userSubscription?.cancel() ?? Future<void>.value());
    unawaited(_liveProfileSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
