import 'package:shared_preferences/shared_preferences.dart';

import '../../app_shell.dart';
import '../../models/models.dart';
import '../../services/backend_commerce_service.dart';
import 'legal_document_registry.dart';
import 'legal_versioning.dart';

class LegalConsentService {
  final BackendCommerceService _backend = BackendCommerceService();

  Future<bool> requiresConsent({
    required AppUser user,
    required AbzioAppMode mode,
  }) async {
    final audience = LegalVersioning.audienceFor(user: user, mode: mode);
    final expectedVersion = await _activeVersionFor(audience);
    final prefs = await SharedPreferences.getInstance();
    final acceptedVersion = prefs.getString(_versionKey(audience));
    return acceptedVersion != expectedVersion;
  }

  Future<void> saveConsent({
    required LegalAudience audience,
    required String version,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey(audience), version);
    await prefs.setString(
      _acceptedAtKey(audience),
      DateTime.now().toIso8601String(),
    );
  }

  Future<String> activeVersionForAudience(LegalAudience audience) {
    return _activeVersionFor(audience);
  }

  String _versionKey(LegalAudience audience) =>
      'legal_consent_version_${audience.name}';
  String _acceptedAtKey(LegalAudience audience) =>
      'legal_consent_accepted_at_${audience.name}';

  Future<String> _activeVersionFor(LegalAudience audience) async {
    try {
      final versions = await _backend.getLegalPolicyVersions();
      final value = versions[audience.name]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    } catch (_) {
      // Fallback to bundled version when remote config is unavailable.
    }
    return LegalVersioning.defaultVersionFor(audience);
  }
}
