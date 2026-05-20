import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/invoice_download_manager.dart';
import '../providers/invoice_providers.dart';

class InvoicePdfViewerScreen extends ConsumerStatefulWidget {
  const InvoicePdfViewerScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoicePdfViewerScreen> createState() => _InvoicePdfViewerScreenState();
}

class _InvoicePdfViewerScreenState extends ConsumerState<InvoicePdfViewerScreen> {
  String _url = '';
  File? _localFile;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final manager = InvoiceDownloadManager(ref.read(invoiceDioProvider));
      final url = await repo.getDownloadUrl(widget.invoiceId);
      final cached = await manager.getCachedCopy(url);
      if (cached != null && await cached.exists()) {
        setState(() {
          _localFile = cached;
          _url = url;
          _loading = false;
        });
        return;
      }
      final file = await manager.downloadToAppStorage(id: widget.invoiceId, url: url);
      setState(() {
        _localFile = file;
        _url = url;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice PDF'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Unable to open invoice PDF.\n$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: _localFile != null
                          ? SfPdfViewer.file(_localFile!)
                          : SfPdfViewer.network(_url),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Verified PDF',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
