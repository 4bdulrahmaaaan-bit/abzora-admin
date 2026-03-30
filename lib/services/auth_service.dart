import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'backend_commerce_service.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _db = DatabaseService();
  final BackendCommerceService _backendCommerce = BackendCommerceService();

  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;
  String? _pendingPhoneNumber;

  Future<void> _savePhoneNumberToBackend(String? phoneNumber) async {
    final normalized = (phoneNumber ?? '').trim();
    if (normalized.isEmpty || !_backendCommerce.isConfigured) {
      return;
    }
    try {
      final backendUser = await _backendCommerce.saveTestUserPhone(normalized);
      debugPrint('Saved test user to backend: ${backendUser.phone}');
    } catch (error) {
      debugPrint('Failed to save test user to backend: $error');
    }
  }

  FirebaseAuth? get _authOrNull {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String _normalizePhoneNumber(String rawPhoneNumber) {
    final cleaned = rawPhoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.length == 10) {
      return '+91$cleaned';
    }
    return cleaned;
  }

  String _mapAuthError(Object error) {
    if (error is StateError) {
      final message = error.message.toString().trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'Please enter a valid phone number with country code.';
        case 'operation-not-allowed':
          return 'Phone sign-in is not enabled in Firebase Authentication yet.';
        case 'unauthorized-domain':
          return 'This web domain is not authorized for Firebase phone sign-in.';
        case 'app-not-authorized':
          return 'This app is not authorized for phone authentication yet.';
        case 'invalid-verification-code':
          return 'The OTP you entered is incorrect.';
        case 'session-expired':
          return 'This OTP has expired. Please request a new one.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'captcha-check-failed':
          return 'reCAPTCHA verification failed. Please try again.';
        case 'web-context-cancelled':
          return 'Verification was cancelled before OTP could be sent.';
        case 'web-storage-unsupported':
          return 'This browser does not support the storage needed for OTP login.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'missing-verification-code':
          return 'Please enter the OTP sent to your phone.';
        case 'invalid-app-credential':
          return 'Phone authentication is not configured correctly yet.';
        case 'internal-error':
          return error.message ??
              'Phone authentication hit an internal Firebase error. Please verify phone sign-in and authorized domains.';
      }
      return error.message ?? 'Authentication failed.';
    }
    if (error is Error || error is Exception) {
      final raw = error.toString().trim();
      if (raw.isEmpty || raw == 'Error') {
        return 'Phone sign-in could not start. Please make sure Phone Authentication is enabled and localhost is added to Firebase authorized domains.';
      }
      if (raw.startsWith('Error:')) {
        return raw.replaceFirst('Error:', '').trim();
      }
      return raw;
    }
    final fallback = error.toString().trim();
    if (fallback.isNotEmpty &&
        fallback != 'Error' &&
        !fallback.startsWith('Instance of ')) {
      return fallback;
    }
    return 'Phone sign-in could not start. Please make sure Phone Authentication is enabled and localhost is added to Firebase authorized domains.';
  }

  Future<AppUser> _ensurePhoneProfile(
    User firebaseUser, {
    String? phoneNumber,
  }) async {
    if (_backendCommerce.isConfigured) {
      try {
        final backendUser = await _backendCommerce.getCurrentUserProfile();
        final normalized = backendUser.copyWith(
          email: backendUser.email.isNotEmpty ? backendUser.email : (firebaseUser.email ?? ''),
          phone: (backendUser.phone ?? '').isNotEmpty
              ? backendUser.phone
              : (firebaseUser.phoneNumber ?? phoneNumber ?? _pendingPhoneNumber ?? ''),
        );
        unawaited(_db.saveUser(normalized));
        return normalized;
      } catch (_) {
        // Fall back to local/Firebase-backed profile creation if backend handshake fails.
      }
    }

    final existing = await _db
        .getUser(firebaseUser.uid)
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (existing != null) {
      if ((existing.phone ?? '').isNotEmpty) {
        return existing;
      }

      final patched = existing.copyWith(
        phone: firebaseUser.phoneNumber ?? phoneNumber ?? existing.phone,
      );
      unawaited(_db.saveUser(patched));
      return patched;
    }

    final appUser = AppUser(
      id: firebaseUser.uid,
      name: '',
      email: firebaseUser.email ?? '',
      phone: firebaseUser.phoneNumber ?? phoneNumber ?? _pendingPhoneNumber ?? '',
      address: '',
      area: '',
      city: '',
      latitude: null,
      longitude: null,
      deliveryRadiusKm: 10,
      locationUpdatedAt: null,
      createdAt: DateTime.now().toIso8601String(),
      role: 'user',
      isActive: true,
      walletBalance: 0,
      referralCode: null,
      referredBy: null,
    );
    unawaited(_db.saveUser(appUser));
    return appUser;
  }

  Stream<AppUser?> get user {
    final auth = _authOrNull;
    if (auth == null) {
      return const Stream<AppUser?>.empty();
    }

    return auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }

      return _ensurePhoneProfile(firebaseUser);
    });
  }

  Future<AppUser?> getCurrentAppUser() async {
    final firebaseUser = _authOrNull?.currentUser;
    if (firebaseUser == null) {
      return null;
    }
    return _ensurePhoneProfile(firebaseUser);
  }

  Future<AppUser?> signInWithGoogleAdmin() async {
    if (!kIsWeb) {
      throw StateError('Google admin sign-in is available on web only.');
    }

    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Authentication is unavailable right now.');
    }

    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters(const {'prompt': 'select_account'});
      final result = await auth.signInWithPopup(provider);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        return null;
      }

      final appUser = await _ensurePhoneProfile(firebaseUser);
      final normalizedRole = appUser.role.trim().toLowerCase();
      if (normalizedRole != 'admin' && normalizedRole != 'super_admin') {
        await signOut();
        throw StateError('Access denied. Use an approved admin Google account.');
      }

      return appUser;
    } catch (error) {
      throw StateError(_mapAuthError(error));
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Phone authentication is unavailable right now.');
    }

    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    _pendingPhoneNumber = normalizedPhone;
    _verificationId = null;
    _webConfirmationResult = null;

    try {
      if (kIsWeb) {
        try {
          await auth.initializeRecaptchaConfig();
        } catch (_) {
          // Projects without reCAPTCHA Enterprise config can still use the
          // managed fallback web verifier inside signInWithPhoneNumber.
        }
        _webConfirmationResult = await auth
            .signInWithPhoneNumber(normalizedPhone)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw StateError(
                'OTP request timed out. Please refresh the page and try again.',
              ),
            );
        return;
      }

      final completer = Completer<void>();
      await auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: (credential) async {
          try {
            final result = await auth.signInWithCredential(credential);
            final firebaseUser = result.user;
            if (firebaseUser != null) {
              await _ensurePhoneProfile(firebaseUser, phoneNumber: normalizedPhone);
              await _savePhoneNumberToBackend(
                firebaseUser.phoneNumber ?? normalizedPhone,
              );
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (error) {
            if (!completer.isCompleted) {
              completer.completeError(StateError(_mapAuthError(error)));
            }
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.completeError(StateError(_mapAuthError(error)));
          }
        },
        codeSent: (verificationId, _) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
      await completer.future;
    } catch (error) {
      throw StateError(_mapAuthError(error));
    }
  }

  Future<AppUser?> verifyOtp(String otp) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Phone authentication is unavailable right now.');
    }

    final trimmedOtp = otp.trim();
    if (trimmedOtp.isEmpty) {
      throw StateError('Please enter the OTP sent to your phone.');
    }

    try {
      UserCredential credentialResult;
      if (kIsWeb) {
        final confirmation = _webConfirmationResult;
        if (confirmation == null) {
          throw StateError('Please request a new OTP first.');
        }
        credentialResult = await confirmation
            .confirm(trimmedOtp)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw StateError(
                'OTP verification timed out. Please try again.',
              ),
            );
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) {
          throw StateError('Please request a new OTP first.');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: trimmedOtp,
        );
        credentialResult = await auth
            .signInWithCredential(credential)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw StateError(
                'OTP verification timed out. Please check your connection and try again.',
              ),
            );
      }

      final firebaseUser = credentialResult.user;
      if (firebaseUser == null) {
        return null;
      }

      final appUser = await _ensurePhoneProfile(
        firebaseUser,
        phoneNumber: firebaseUser.phoneNumber ?? _pendingPhoneNumber,
      );
      await _savePhoneNumberToBackend(
        firebaseUser.phoneNumber ?? _pendingPhoneNumber,
      );
      if (_db.isSuperAdmin(appUser)) {
        final authorized = await _db.isAdminDeviceAuthorized(user: appUser);
        if (!authorized) {
          await signOut();
          throw StateError('This device is not authorized for super admin access.');
        }
        await _db.notifyAdminLogin(user: appUser);
      }
      unawaited(_db.trackUserLogin(appUser));
      return appUser;
    } catch (error) {
      throw StateError(_mapAuthError(error));
    }
  }

  Future<void> signOut() async {
    final auth = _authOrNull;
    if (auth != null) {
      await auth.signOut();
    }
    _verificationId = null;
    _webConfirmationResult = null;
    _pendingPhoneNumber = null;
  }
}
