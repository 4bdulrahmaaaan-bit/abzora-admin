import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/invoice_download_manager.dart';
import '../providers/invoice_providers.dart';

class InvoiceDetailsScreen extends ConsumerWidget {
  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  final String invoiceId;

  Future<void> _shareInvoice(WidgetRef ref) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final url = await repo.getDownloadUrl(invoiceId);
    await Share.share('Abianzo Invoice: $url');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceDetailsProvider(invoiceId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          IconButton(
            onPressed: () => _shareInvoice(ref),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: invoice.when(
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.invoiceNumber,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(label: Text(item.versionLabel)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Order: ${item.orderId}'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grand Total: INR ${item.grandTotal.toStringAsFixed(2)}'),
                    Text('Tax: INR ${item.tax.toStringAsFixed(2)}'),
                    Text('CGST: INR ${item.cgst.toStringAsFixed(2)}'),
                    Text('SGST: INR ${item.sgst.toStringAsFixed(2)}'),
                    Text('IGST: INR ${item.igst.toStringAsFixed(2)}'),
                    Text('Payment: ${item.paymentStatus}'),
                    Text('Refund Status: ${item.refundStatus}'),
                    Text('Verification Hash: ${item.verificationHash.isEmpty ? 'N/A' : item.verificationHash.substring(0, item.verificationHash.length > 14 ? 14 : item.verificationHash.length)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/invoice/pdf', arguments: invoiceId),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Preview PDF'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () async {
                final repo = ref.read(invoiceRepositoryProvider);
                final manager = InvoiceDownloadManager(ref.read(invoiceDioProvider));
                final url = await repo.getDownloadUrl(invoiceId);
                await manager.downloadToAppStorage(id: invoiceId, url: url);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invoice cached for offline use.')),
                  );
                }
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download & Cache'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(invoiceRepositoryProvider).emailInvoice(invoiceId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invoice email queued.')),
                  );
                }
              },
              icon: const Icon(Icons.email_outlined),
              label: const Text('Email Invoice'),
            ),
            if (item.creditNoteNumber.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/invoice/credit-note',
                  arguments: {
                    'creditNoteNumber': item.creditNoteNumber,
                    'amount': item.grandTotal,
                  },
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Credit Note'),
              ),
            ],
          ],
        ),
        error: (e, _) => Center(child: Text('Failed to load invoice\n$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
