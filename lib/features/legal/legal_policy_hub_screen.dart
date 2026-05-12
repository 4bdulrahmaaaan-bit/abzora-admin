import 'package:flutter/material.dart';

import 'legal_document_registry.dart';
import 'legal_document_screen.dart';

class LegalPolicyHubScreen extends StatelessWidget {
  const LegalPolicyHubScreen({super.key, required this.audience, this.title});

  final LegalAudience audience;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final docs = LegalDocumentRegistry.forAudience(audience);
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Legal & Policies')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final doc = docs[index];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.white,
            title: Text(doc.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(document: doc),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemCount: docs.length,
      ),
    );
  }
}
