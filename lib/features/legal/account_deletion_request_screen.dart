import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDeletionRequestScreen extends StatefulWidget {
  const AccountDeletionRequestScreen({super.key, required this.roleLabel});

  final String roleLabel;

  @override
  State<AccountDeletionRequestScreen> createState() =>
      _AccountDeletionRequestScreenState();
}

class _AccountDeletionRequestScreenState
    extends State<AccountDeletionRequestScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    setState(() => _submitting = true);
    final body = Uri.encodeComponent(
      'Account deletion request\nRole: ${widget.roleLabel}\nReason: ${_reasonController.text.trim()}\nRequested At: ${DateTime.now().toIso8601String()}',
    );
    final uri = Uri.parse(
      'mailto:support@abzora.in?subject=Abianzo Account Deletion Request&body=$body',
    );
    await launchUrl(uri);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deletion request draft opened in your mail app.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Deletion Request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Deletion requests are processed in 7-30 days after verification. Financial and statutory records may be retained as required by law.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Reason (optional but recommended)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submitRequest,
            child: Text(_submitting ? 'Submitting...' : 'Request Deletion'),
          ),
        ],
      ),
    );
  }
}

