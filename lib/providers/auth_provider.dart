import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/backend_commerce_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final DatabaseService _db = DatabaseService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  StreamSubscription<AppUser?>? _userSubscription;
  StreamSubscription<AppUser?>? _liveProfileSubscription;
  AppUser? _user;
  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  bool _isInitialized = false;
  String? _pendingPhoneNumber;
  String? _lastBackendProfileSyncKey;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  bool get isSuperAdmin => _user?.role == 'super_admin' || _user?.role == 'admin';
  bool get isVendor => _user?.role == 'vendor';
  bool get isRider => _user?.role == 'rider';
  bool get isUser => _user?.role == 'user' || _user?.role == 'customer';
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  bool get requiresProfileSetup {
    final current = _user;
    if (current == null) {
      return false;
    }
    return current.name.trim().isEmpty || (current.address ?? '').trim().isEmpty;
  }

  AuthProvider() {
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
    if (user == null) {
      _lastBackendProfileSyncKey = null;
      return;
    }
    unawaited(NotificationService().initNotifications());
    _maybeSyncBackendProfile(user);
    _liveProfileSubscription = _db.watchUser(user.id).listen((liveUser) {
      _user = liveUser ?? user;
      if (_user != null) {
        _maybeSyncBackendProfile(_user!);
      }
      notifyListeners();
    });
  }

  void _maybeSyncBackendProfile(AppUser user) {
    if (!_backendCommerce.isConfigured) {
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
      _user = result;
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AppUser?> signInWithGoogleAdmin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogleAdmin();
      _user = result;
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
      _user = result;
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    await _liveProfileSubscription?.cancel();
    _user = null;
    _pendingPhoneNumber = null;
    _lastBackendProfileSyncKey = null;
    notifyListeners();
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
      _user = current;
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
      await _db.saveUser(updated);
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
      final location = await _locationService.getCurrentLocation(forceRefresh: true);
      if (location.status != LocationStatus.success || location.position == null) {
        throw StateError('Unable to detect location');
      }
      final position = location.position!;
      final resolvedAddress = location.address ?? await _locationService.reverseGeocode(position.latitude, position.longitude);
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
      await _db.saveUser(updated);
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
    _userSubscription?.cancel();
    _liveProfileSubscription?.cancel();
    super.dispose();
  }
}
