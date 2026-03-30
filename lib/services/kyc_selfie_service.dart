import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'app_config.dart';

class SelfieVerificationCapture {
  const SelfieVerificationCapture({
    required this.selfieUrl,
    required this.verification,
  });

  final String selfieUrl;
  final KycVerificationSummary verification;
}

class LiveSelfieCheckResult {
  const LiveSelfieCheckResult({
    required this.imagePath,
    required this.livenessPassed,
    required this.livenessMode,
    required this.retryCount,
  });

  final String imagePath;
  final bool livenessPassed;
  final String livenessMode;
  final int retryCount;
}

class KycSelfieService {
  const KycSelfieService();

  Future<KycVerificationSummary> verifyLiveSelfie({
    required String selfieUrl,
    required String ownerPhotoUrl,
    required String aadhaarUrl,
    required bool livenessPassed,
    required String livenessMode,
    required int retryCount,
  }) async {
    if (!livenessPassed) {
      return KycVerificationSummary(
        livenessPassed: false,
        faceVerified: false,
        matchScore: 0,
        livenessMode: livenessMode,
        selfieRetryCount: retryCount,
        selfieVerifiedAt: DateTime.now().toIso8601String(),
        autoReviewStatus: 'pending_review',
        reviewSummary: 'Live verification did not pass liveness checks.',
        flags: const ['Liveness check failed.'],
        provider: 'local',
      );
    }

    if (!AppConfig.hasKycFaceMatchEndpoint) {
      return KycVerificationSummary(
        livenessPassed: true,
        faceVerified: false,
        matchScore: 0,
        livenessMode: livenessMode,
        selfieRetryCount: retryCount,
        selfieVerifiedAt: DateTime.now().toIso8601String(),
        autoReviewStatus: 'pending_review',
        reviewSummary: 'Live selfie captured. Face match endpoint is unavailable, so manual review is required.',
        flags: const ['Face match service is unavailable.'],
        provider: 'fallback',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.kycFaceMatchEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'selfieImageUrl': selfieUrl,
              'referenceImageUrls': [
                if (ownerPhotoUrl.trim().isNotEmpty) ownerPhotoUrl.trim(),
                if (aadhaarUrl.trim().isNotEmpty) aadhaarUrl.trim(),
              ],
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return KycVerificationSummary(
          livenessPassed: true,
          faceVerified: false,
          matchScore: 0,
          livenessMode: livenessMode,
          selfieRetryCount: retryCount,
          selfieVerifiedAt: DateTime.now().toIso8601String(),
          autoReviewStatus: 'pending_review',
          reviewSummary: 'Live selfie captured, but face matching could not finish.',
          flags: const ['Face match request failed.'],
          provider: 'fallback',
        );
      }

      final decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final score = ((payload['similarity'] ?? payload['matchScore'] ?? 0) as num).toDouble();
      final verified = (payload['verified'] == true) || score >= 85;
      final flags = List<String>.from((payload['flags'] as List?) ?? const []);
      return KycVerificationSummary(
        livenessPassed: true,
        faceVerified: verified,
        matchScore: score,
        livenessMode: livenessMode,
        selfieRetryCount: retryCount,
        selfieVerifiedAt: DateTime.now().toIso8601String(),
        autoReviewStatus: verified ? 'auto_verified' : 'pending_review',
        reviewSummary: verified
            ? 'Live selfie matched the submitted identity documents.'
            : 'Live selfie did not meet the face match threshold.',
        flags: flags,
        provider: 'face_match_api',
      );
    } catch (_) {
      return KycVerificationSummary(
        livenessPassed: true,
        faceVerified: false,
        matchScore: 0,
        livenessMode: livenessMode,
        selfieRetryCount: retryCount,
        selfieVerifiedAt: DateTime.now().toIso8601String(),
        autoReviewStatus: 'pending_review',
        reviewSummary: 'Live selfie captured, but face matching timed out.',
        flags: const ['Face match timeout.'],
        provider: 'fallback',
      );
    }
  }
}
