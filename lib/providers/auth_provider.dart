import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/backend_api_client.dart';
import '../services/backend_commerce_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/app_navigation_service.dart';
import '../services/storage_service.dart';
import '../utils/app_mode_routes.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
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
  bool _isLoggingOut = false;
  bool _isRefreshingAuthToken = false;
  DateTime? _lastSignInAt;
  DateTime? _lastTokenRefreshAt;
  DateTime? _lastUnauthorizedSignalAt;
  DateTime? _lastUnauthorizedRecoveryAttemptAt;
  int _consecutiveUnauthorizedSignals = 0;
  String? _pendingPhoneNumber;
  String? _lastBackendProfileSyncKey;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isSuperAdmin =>
      _user?.role == 'super_admin' || _user?.role == 'admin';
  bool get isVendor => hasVendorOperationsAccess(_user);
  bool get isRider => hasRiderOperationsAccess(_user);
  bool get isUser => _user?.role == 'user' || _user?.role == 'customer';
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  bool get requiresProfileSetup {
    final current = _user;
    if (current == null) {
      return false;
    }
    return current.name.trim().isEmpty ||
        (current.address ?? '').trim().isEmpty;
  }

  AuthProvider() {
    BackendApiClient.registerUnauthorizedHandler(_handleUnauthorizedSession);
    _restoreSession();
    _userSubscription = _authService.user.listen((user) {
      _bindLiveProfile(user);
      _isInitialized = true;
      notifyListeners();
    });
  }

  void _bindLiveProfile(AppUser? user) {
    _liveProfileSubscription?.cancel();
    _user = user;
    _isAuthenticated = user != null && (_token?.isNotEmpty ?? false);
    if (user == null) {
      _token = null;
      _lastBackendProfileSyncKey = null;
      return;
    }
    unawaited(_refreshAuthToken());
    unawaited(_syncNotificationChannels(user));
    _maybeSyncBackendProfile(user);
    _liveProfileSubscription = _db.watchUser(user.id).listen((liveUser) {
      _user = liveUser ?? user;
      _isAuthenticated = _user != null && (_token?.isNotEmpty ?? false);
      if (_user != null) {
        _maybeSyncBackendProfile(_user!);
        unawaited(_syncNotificationChannels(_user!));
      }
      unawaited(_refreshAuthToken());
      notifyListeners();
    });
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
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _token = null;
        _isAuthenticated = false;
        notifyListeners();
        return;
      }
      var idToken = await firebaseUser.getIdToken(forceRefresh);
      if (idToken == null || idToken.isEmpty) {
        idToken = await firebaseUser.getIdToken(true);
      }
      if (idToken == null || idToken.isEmpty) {
        _lastTokenRefreshAt = DateTime.now();
        return;
      }
      _lastTokenRefreshAt = DateTime.now();
      if (idToken != _token) {
        _token = idToken;
        _isAuthenticated = _user != null && (_token?.isNotEmpty ?? false);
        if (_user != null) {
          _maybeSyncBackendProfile(_user!);
        }
        notifyListeners();
      }
    } catch (_) {
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

  Future<void> _restoreSession() async {
    try {
      final existingUser = await _authService.getCurrentAppUser();
      if (existingUser != null) {
        _bindLiveProfile(existingUser);
      }
    } finally {
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
      final result = await _authService.verifyOtp(otp);
      _lastSignInAt = DateTime.now();
      _user = result;
      _isAuthenticated = result != null && (_token?.isNotEmpty ?? false);
      unawaited(_refreshAuthToken());
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
      final backendUser = await _backendCommerce.getCurrentUserProfile();
      _user = backendUser;
      _isAuthenticated = _user != null && (_token?.isNotEmpty ?? false);
      _maybeSyncBackendProfile(backendUser);
      unawaited(_syncNotificationChannels(backendUser));
      unawaited(_db.saveUser(backendUser));
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
      _user = result;
      _isAuthenticated = result != null && (_token?.isNotEmpty ?? false);
      unawaited(_refreshAuthToken());
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
      _user = result;
      _isAuthenticated = result != null && (_token?.isNotEmpty ?? false);
      unawaited(_refreshAuthToken());
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
    try {
      await _authService.signOut();
    } finally {
      await _liveProfileSubscription?.cancel();
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
    if (!_isAuthenticated || _isLoggingOut) {
      return;
    }
    final signedInJustNow = _lastSignInAt != null &&
        DateTime.now().difference(_lastSignInAt!).inSeconds < 30;
    if (signedInJustNow) {
      return;
    }
    final now = DateTime.now();
    if (_lastUnauthorizedRecoveryAttemptAt != null &&
        now.difference(_lastUnauthorizedRecoveryAttemptAt!).inSeconds < 30) {
      return;
    }
    if (_lastUnauthorizedSignalAt == null ||
        now.difference(_lastUnauthorizedSignalAt!).inMinutes >= 2) {
      _consecutiveUnauthorizedSignals = 1;
    } else {
      _consecutiveUnauthorizedSignals += 1;
    }
    _lastUnauthorizedSignalAt = now;
    _lastUnauthorizedRecoveryAttemptAt = now;

    await _refreshAuthToken(forceRefresh: true);
    if (_token != null && _token!.isNotEmpty && _consecutiveUnauthorizedSignals < 2) {
      return;
    }
    await logout();
    await AppNavigationService.resetToHome(
      message: 'Session expired. Please sign in again.',
    );
  }

  Future<void> _clearLocalUserCache(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        final isSessionScoped =
            key == 'abzora_local_cart_v1' || key.startsWith('payment_pref_');
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
    _lastUnauthorizedSignalAt = null;
    _lastUnauthorizedRecoveryAttemptAt = null;
    _consecutiveUnauthorizedSignals = 0;
  }

  void setUser(AppUser user) {
    _bindLiveProfile(user);
    notifyListeners();
  }

  void setRole(String role) {
    if (_user != null) {
      _user = _user!.copyWith(role: role);
      notifyListeners();
    }
  }

  Future<void> refreshCurrentUser() async {
    final current = await _authService.getCurrentAppUser();
    if (current != null) {
      _bindLiveProfile(current);
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
    BackendApiClient.registerUnauthorizedHandler(null);
    _userSubscription?.cancel();
    _liveProfileSubscription?.cancel();
    super.dispose();
  }
}
