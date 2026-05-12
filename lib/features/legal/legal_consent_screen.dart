import 'package:flutter/material.dart';

import 'legal_consent_service.dart';
import 'legal_document_registry.dart';
import 'legal_document_screen.dart';

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key, required this.audience});

  final LegalAudience audience;

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  final LegalConsentService _consentService = LegalConsentService();
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _saving = false;
  String _version = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await _consentService.activeVersionForAudience(
      widget.audience,
    );
    if (!mounted) {
      return;
    }
    setState(() => _version = version);
  }

  Future<void> _saveConsent() async {
    if (!_acceptedTerms || !_acceptedPrivacy) {
      return;
    }
    setState(() => _saving = true);
    await _consentService.saveConsent(
      audience: widget.audience,
      version: _version,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final docs = LegalDocumentRegistry.forAudience(widget.audience);
    final terms = docs.firstWhere((d) => d.title.contains('Terms'));
    final privacy = docs.firstWhere((d) => d.title.contains('Privacy'));

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy Consent')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Please review and accept the legal documents to continue using this app role. Required policy version: $_version',
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(terms.title),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(document: terms),
              ),
            ),
          ),
          CheckboxListTile(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            title: const Text('I agree to the Terms & Conditions'),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(privacy.title),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(document: privacy),
              ),
            ),
          ),
          CheckboxListTile(
            value: _acceptedPrivacy,
            onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
            title: const Text('I agree to the Privacy Policy'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _saveConsent,
            child: Text(_saving ? 'Saving...' : 'Accept and Continue'),
          ),
        ],
      ),
    );
  }
}
