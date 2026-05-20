import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/invoice_offline_cache.dart';
import '../providers/invoice_providers.dart';

class InvoiceHistoryScreen extends ConsumerStatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  ConsumerState<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends ConsumerState<InvoiceHistoryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _cache = InvoiceOfflineCache();
  bool _isOfflineSnapshot = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final nearEnd = _scrollController.position.pixels >=
          (_scrollController.position.maxScrollExtent - 280);
      if (nearEnd) {
        ref.read(customerInvoicePagerProvider.notifier).nextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerInvoicePagerProvider);
    if (state.items.isNotEmpty) {
      _cache.saveRawJson(
        state.items
            .map(
              (e) => {
                'id': e.id,
                'invoiceNumber': e.invoiceNumber,
                'orderId': e.orderId,
                'grandTotal': e.grandTotal,
                'status': e.status,
                'paymentStatus': e.paymentStatus,
                'generatedAt': e.generatedAt.toIso8601String(),
                'cgst': e.cgst,
                'sgst': e.sgst,
                'igst': e.igst,
                'tax': e.tax,
                'versionLabel': e.versionLabel,
              },
            )
            .toList(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(customerInvoicePagerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(customerInvoicePagerProvider.notifier).refresh(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search invoice number',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  final rows = state.items
                      .where((r) => _searchController.text.trim().isEmpty
                          ? true
                          : r.invoiceNumber
                              .toLowerCase()
                              .contains(_searchController.text.trim().toLowerCase()))
                      .toList();
                  if (rows.isEmpty && state.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rows.isEmpty && state.error.isNotEmpty) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cache.readRawJson(),
                      builder: (context, snapshot) {
                        final cached = snapshot.data ?? const <Map<String, dynamic>>[];
                        if (cached.isEmpty) {
                          return Center(child: Text('No invoices available.\n${state.error}'));
                        }
                        _isOfflineSnapshot = true;
                        return ListView(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Offline snapshot shown. Pull to retry.'),
                            ),
                            ...cached.map(
                              (row) => ListTile(
                                title: Text((row['invoiceNumber'] ?? '').toString()),
                                subtitle: Text('INR ${(row['grandTotal'] ?? 0).toString()}'),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }
                  if (rows.isEmpty) {
                    return const Center(child: Text('No invoices available.'));
                  }
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length + (state.loading ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index >= rows.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final invoice = rows[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/invoice/details',
                          arguments: invoice.id,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE6DED0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      invoice.invoiceNumber,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2EFE9),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(invoice.versionLabel),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Status: ${invoice.paymentStatus} • ${invoice.status}'),
                              const SizedBox(height: 6),
                              Text(
                                'INR ${invoice.grandTotal.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isOfflineSnapshot)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF3CD),
                padding: const EdgeInsets.all(10),
                child: const Text(
                  'Offline mode: showing cached invoices.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
