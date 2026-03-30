import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'app_config.dart';
import 'backend_api_client.dart';
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
    'vendor_kyc_owner',
    'vendor_kyc_store',
    'vendor_kyc_docs',
    'vendor_kyc_selfie',
    'rider_kyc_profile',
    'rider_kyc_docs',
  };
  static const Set<String> _allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
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
      throw StateError('Only JPG, PNG, and WEBP images are allowed.');
    }

    final fileSize = await file.length();
    if (fileSize > _maxUploadBytes) {
      throw StateError('Image must be smaller than 8 MB.');
    }

    if (_backendApiClient.isConfigured) {
      return _uploadViaBackend(file: file);
    }

    if (AppConfig.hasCloudinarySignedUploadEndpoint) {
      return _uploadWithSigner(
        file: file,
        folder: folder,
        ownerId: normalizedOwnerId,
        fileName: fileName,
      );
    }

    if (!AppConfig.hasCloudinaryConfig) {
      throw StateError('Cloudinary is not configured yet.');
    }

    return _uploadUnsigned(
      file: file,
      folder: folder,
      ownerId: normalizedOwnerId,
      fileName: fileName,
    );
  }

  Future<String> _uploadViaBackend({
    required XFile file,
  }) async {
    final extension = _fileExtension(file.name);
    final payload = await _backendApiClient.multipart(
      '/upload',
      fieldName: 'image',
      bytes: await file.readAsBytes(),
      filename: file.name,
      contentType: _contentTypeForExtension(extension),
    );
    final data = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw StateError('Backend upload did not return an image URL.');
    }
    return ImageUrlService.optimizeForDelivery(url);
  }

  Future<String> _uploadUnsigned({
    required XFile file,
    required String folder,
    required String ownerId,
    String? fileName,
  }) async {
    final publicId = _buildPublicId(fileName ?? file.name);

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = '$folder/$ownerId'
      ..fields['public_id'] = publicId;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name,
      ),
    );

    return _sendCloudinaryUpload(request);
  }

  Future<String> _uploadWithSigner({
    required XFile file,
    required String folder,
    required String ownerId,
    String? fileName,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Signed uploads require an authenticated user session.');
    }

    final publicId = _buildPublicId(fileName ?? file.name);
    final signResponse = await http.post(
      Uri.parse(AppConfig.cloudinarySignedUploadEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'folder': folder,
        'ownerId': ownerId,
        'publicId': publicId,
        'fileName': file.name,
      }),
    );

    final signPayload = signResponse.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(signResponse.body) as Map<String, dynamic>;
    if (signResponse.statusCode < 200 || signResponse.statusCode >= 300) {
      throw StateError(
        signPayload['error']?.toString() ?? 'Cloudinary signed upload could not be initialized.',
      );
    }

    final cloudName = (signPayload['cloudName']?.toString().trim().isNotEmpty ?? false)
        ? signPayload['cloudName'].toString().trim()
        : AppConfig.cloudinaryCloudName;
    final signature = signPayload['signature']?.toString() ?? '';
    final apiKey = signPayload['apiKey']?.toString() ?? '';
    final timestamp = signPayload['timestamp']?.toString() ?? '';
    final signedFolder = signPayload['folder']?.toString() ?? '$folder/$ownerId';
    final signedPublicId = signPayload['publicId']?.toString() ?? publicId;

    if (cloudName.isEmpty || signature.isEmpty || apiKey.isEmpty || timestamp.isEmpty) {
      throw StateError('Signed upload response is missing required Cloudinary fields.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    )
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp
      ..fields['signature'] = signature
      ..fields['folder'] = signedFolder
      ..fields['public_id'] = signedPublicId;

    final uploadPreset = signPayload['uploadPreset']?.toString();
    if (uploadPreset != null && uploadPreset.trim().isNotEmpty) {
      request.fields['upload_preset'] = uploadPreset.trim();
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name,
      ),
    );

    return _sendCloudinaryUpload(request);
  }

  Future<String> _sendCloudinaryUpload(http.MultipartRequest request) async {
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final payload = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error'] is Map<String, dynamic>
          ? (payload['error']['message']?.toString() ?? 'Cloudinary upload failed.')
          : 'Cloudinary upload failed.';
      throw StateError(message);
    }

    final secureUrl = payload['secure_url']?.toString() ?? '';
    if (secureUrl.isEmpty) {
      throw StateError('Cloudinary did not return an image URL.');
    }

    return ImageUrlService.optimizeForDelivery(secureUrl);
  }

  String _buildPublicId(String seed) {
    final sanitized = _sanitizePathSegment(seed.replaceAll(RegExp(r'\.[^.]+$'), ''));
    final fallback = sanitized.isEmpty ? 'upload' : sanitized;
    return '$fallback-${DateTime.now().millisecondsSinceEpoch}';
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
      default:
        return MediaType('image', 'jpeg');
    }
  }
}
