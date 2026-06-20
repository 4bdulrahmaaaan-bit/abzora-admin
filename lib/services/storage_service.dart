import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'app_config.dart';
import 'backend_api_client.dart';
import 'auth_session_service.dart';
import 'image_url_service.dart';

class StorageService {
  StorageService({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient ?? const BackendApiClient();

  static const int _maxUploadBytes = 8 * 1024 * 1024;
  static const Set<String> _allowedFolders = {
    'product_images',
    'user_profiles',
    'store_logos',
    'store_banners',
    'homepage_banners',
    'category_icons',
    'vendor_kyc_owner',
    'vendor_kyc_store',
    'vendor_kyc_docs',
    'vendor_kyc_selfie',
    'rider_kyc_profile',
    'rider_kyc_docs',
    'onboarding-drafts/portfolio',
    'onboarding-drafts/kyc',
  };
  static const Set<String> _allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  };
  final BackendApiClient _backendApiClient;

  Future<String> uploadPickedImage({
    required XFile file,
    required String folder,
    required String ownerId,
    String? fileName,
  }) async {
    if (!_allowedFolders.contains(folder)) {
      throw StateError('Uploads are not allowed for folder "$folder".');
    }

    final normalizedOwnerId = _sanitizePathSegment(ownerId);
    if (normalizedOwnerId.isEmpty) {
      throw StateError('A valid owner ID is required for uploads.');
    }

    final extension = _fileExtension(file.name);
    if (!_allowedExtensions.contains(extension)) {
      throw StateError('Only JPG, PNG, WEBP, HEIC, and HEIF images are allowed.');
    }

    final fileSize = await file.length();
    if (fileSize > _maxUploadBytes) {
      throw StateError('Image must be smaller than 8 MB.');
    }

    debugPrint('[CLOUDINARY_DEBUG] uploadType=Backend_Upload endpoint=/upload folder=$folder mimeType=$extension fileName=${fileName ?? file.name}');

    if (!_backendApiClient.isConfigured) {
      debugPrint('[CLOUDINARY_FAILURE] Backend is not configured. Cannot perform upload.');
      throw StateError('Backend upload service is not configured.');
    }

    return _uploadViaBackend(file: file, folder: folder, ownerId: normalizedOwnerId);
  }

  Future<String> _uploadViaBackend({required XFile file, required String folder, required String ownerId}) async {
    final extension = _fileExtension(file.name);
    try {
      Future<String> resolveUploadToken({required bool forceRefresh}) async {
        try {
          return await AuthSessionService.instance.requiredAuthorizationToken(
            forceRefresh: forceRefresh,
            failureMessage: 'Please sign in again before uploading images.',
          );
        } on StateError catch (error) {
          final message = error.message.toString().toLowerCase();
          final canFallbackToFirebase =
              message.contains('provisioned') ||
              message.contains('sign in again') ||
              message.contains('session') ||
              message.contains('backend session');
          if (!canFallbackToFirebase) {
            rethrow;
          }
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser == null) {
            rethrow;
          }
          final firebaseToken = await firebaseUser
              .getIdToken(forceRefresh)
              .timeout(const Duration(seconds: 15));
          if (firebaseToken == null || firebaseToken.isEmpty) {
            rethrow;
          }
          debugPrint(
            '[CLOUDINARY_DEBUG] Falling back to Firebase ID token for upload provisioning.',
          );
          return firebaseToken;
        }
      }

      Future<String> sendWithToken({required bool forceRefresh}) async {
        final token = await resolveUploadToken(forceRefresh: forceRefresh);

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.backendBaseUrl}/upload'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['folder'] = '$folder/$ownerId';
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            await file.readAsBytes(),
            filename: file.name,
            contentType: _contentTypeForExtension(extension),
          ),
        );

        final response = await request.send().timeout(const Duration(seconds: 30));
        final body = await response.stream.bytesToString();
        final decoded = _decodeResponseBody(body);
        final data = decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'] as Map)
            : decoded;
        if (response.statusCode == 401 && !forceRefresh) {
          return sendWithToken(forceRefresh: true);
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final message = _responseMessage(data, fallbackStatus: response.statusCode);
          throw StateError(
            message?.isNotEmpty == true
                ? message!
                : 'Image upload failed (${response.statusCode}).',
          );
        }

        final url = data['url']?.toString() ?? '';
        if (url.isEmpty) {
          throw StateError('Backend upload did not return an image URL.');
        }
        return ImageUrlService.optimizeForDelivery(url);
      }

      try {
        return await sendWithToken(forceRefresh: false);
      } on StateError {
        rethrow;
      } catch (_) {
        return await sendWithToken(forceRefresh: true);
      }
    } on BackendApiException catch (e) {
      debugPrint('[CLOUDINARY_FAILURE] Backend upload rejected: ${e.statusCode} ${e.message}');
      throw StateError(e.message);
    } on StateError catch (e) {
      debugPrint('[CLOUDINARY_FAILURE] Backend upload failed: ${e.message}');
      throw StateError(e.message);
    } catch (e) {
      debugPrint('[CLOUDINARY_FAILURE] Backend upload failed: $e');
      throw StateError('Image upload failed. Please try again.');
    }
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Fall through to a text payload wrapper so the backend message is not lost.
    }
    return <String, dynamic>{'message': body.trim()};
  }

  String? _responseMessage(Map<String, dynamic> payload, {required int fallbackStatus}) {
    final directMessage = payload['message']?.toString().trim();
    if (directMessage?.isNotEmpty == true) {
      return directMessage;
    }
    final data = payload['data'];
    if (data is Map) {
      final nestedMessage = data['message']?.toString().trim();
      if (nestedMessage?.isNotEmpty == true) {
        return nestedMessage;
      }
    }
    if (fallbackStatus == 403) {
      return 'Access denied. Please sign in with the correct account.';
    }
    return null;
  }



  String _sanitizePathSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _fileExtension(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return name.substring(dotIndex).toLowerCase();
  }

  MediaType _contentTypeForExtension(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.webp':
        return MediaType('image', 'webp');
      case '.heic':
        return MediaType('image', 'heic');
      case '.heif':
        return MediaType('image', 'heif');
      default:
        return MediaType('image', 'jpeg');
    }
  }
}
