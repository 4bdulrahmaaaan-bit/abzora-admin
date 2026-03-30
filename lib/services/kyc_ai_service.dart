import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'app_config.dart';

class KycAiService {
  const KycAiService();

  static const String _systemPrompt =
      'Extract Indian KYC details from Aadhaar and PAN images. Return JSON only.';

  Future<KycVerificationSummary> analyzeVendorDocuments({
    required String ownerName,
    required String aadhaarImageUrl,
    required String panImageUrl,
  }) async {
    final fallback = _fallback(ownerName);
    if (!AppConfig.hasOpenAiConfig) {
      return fallback.copyWith(
        flags: const ['AI OCR is unavailable, so this request needs review.'],
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.openAiResponsesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
            },
            body: jsonEncode({
              'model': AppConfig.openAiModel,
              'max_output_tokens': 220,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _systemPrompt,
                    },
                  ],
                },
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'input_text',
                      'text':
                          'Owner name hint: $ownerName\nReturn strict JSON with keys name, aadhaarNumber, panNumber, confidenceScore, and flags. '
                          'Normalize Aadhaar to 12 digits with no spaces and PAN to uppercase ABCDE1234F format. '
                          'If uncertain, keep the value empty and add a short flag.',
                    },
                    if (aadhaarImageUrl.trim().isNotEmpty)
                      {
                        'type': 'input_image',
                        'image_url': aadhaarImageUrl.trim(),
                      },
                    if (panImageUrl.trim().isNotEmpty)
                      {
                        'type': 'input_image',
                        'image_url': panImageUrl.trim(),
                      },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback.copyWith(
          flags: const ['AI OCR could not verify the documents right now.'],
        );
      }

      final decoded = jsonDecode(response.body);
      final text = _extractTextResponse(decoded).trim();
      final payload = _extractJsonObject(text);
      if (payload == null) {
        return fallback.copyWith(
          flags: const ['Document text could not be parsed cleanly.'],
        );
      }

      final extractedName = _normalizedName(
        payload['name']?.toString() ?? payload['extractedName']?.toString() ?? '',
        fallback: ownerName,
      );
      final aadhaarNumber = _normalizeAadhaar(
        payload['aadhaarNumber']?.toString() ?? payload['aadhaar']?.toString() ?? '',
      );
      final panNumber = _normalizePan(
        payload['panNumber']?.toString() ?? payload['pan']?.toString() ?? '',
      );
      final flags = _coerceFlags(payload['flags']);
      final aadhaarValid = isValidAadhaar(aadhaarNumber);
      final panValid = isValidPan(panNumber);
      final confidenceScore = _coerceConfidence(payload['confidenceScore']);
      final seededFlags = <String>[
        ...flags,
        if (!aadhaarValid) 'Aadhaar number could not be verified clearly.',
        if (!panValid) 'PAN number could not be verified clearly.',
      ];

      final autoReviewStatus =
          confidenceScore >= 85 && aadhaarValid && panValid ? 'auto_verified' : 'pending_review';

      return KycVerificationSummary(
        extractedName: extractedName,
        aadhaarNumber: aadhaarNumber,
        panNumber: panNumber,
        confidenceScore: confidenceScore,
        aadhaarValid: aadhaarValid,
        panValid: panValid,
        autoReviewStatus: autoReviewStatus,
        duplicateDetected: false,
        duplicateMatches: const [],
        flags: seededFlags.toSet().toList(),
        provider: 'openai',
        analyzedAt: DateTime.now().toIso8601String(),
        reviewSummary: autoReviewStatus == 'auto_verified'
            ? 'Documents look strong for fast approval.'
            : 'Documents need manual review before approval.',
      );
    } catch (_) {
      return fallback.copyWith(
        flags: const ['AI OCR timed out, so this request was routed for review.'],
      );
    }
  }

  bool isValidAadhaar(String value) => RegExp(r'^\d{12}$').hasMatch(value.trim());

  bool isValidPan(String value) =>
      RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(value.trim().toUpperCase());

  KycVerificationSummary _fallback(String ownerName) {
    return KycVerificationSummary(
      extractedName: _normalizedName(ownerName, fallback: ownerName),
      confidenceScore: 0,
      aadhaarValid: false,
      panValid: false,
      autoReviewStatus: 'pending_review',
      provider: 'fallback',
      analyzedAt: DateTime.now().toIso8601String(),
      reviewSummary: 'Documents need manual review before approval.',
    );
  }

  String _extractTextResponse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return '';
    }
    final direct = (decoded['output_text'] ?? '').toString().trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final output = decoded['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final content = item['content'];
        if (content is! List) {
          continue;
        }
        for (final block in content) {
          if (block is! Map<String, dynamic>) {
            continue;
          }
          final text = (block['text'] ?? block['output_text'] ?? '')
              .toString()
              .trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }
    return '';
  }

  Map<String, dynamic>? _extractJsonObject(String value) {
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(
        jsonDecode(value.substring(start, end + 1)) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _coerceFlags(Object? raw) {
    if (raw is List) {
      return raw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  double _coerceConfidence(Object? raw) {
    if (raw is num) {
      final value = raw.toDouble();
      if (value <= 1) {
        return (value * 100).clamp(0, 100).toDouble();
      }
      return value.clamp(0, 100).toDouble();
    }
    final parsed = double.tryParse(raw?.toString() ?? '');
    if (parsed == null) {
      return 0;
    }
    if (parsed <= 1) {
      return (parsed * 100).clamp(0, 100).toDouble();
    }
    return parsed.clamp(0, 100).toDouble();
  }

  String _normalizeAadhaar(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '').trim();

  String _normalizePan(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim().toUpperCase();

  String _normalizedName(String value, {required String fallback}) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return fallback.trim();
    }
    return cleaned;
  }
}
