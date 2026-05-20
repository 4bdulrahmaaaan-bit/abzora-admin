import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/auth_provider.dart';
import '../../domain/entities/invoice_entity.dart';
import '../providers/invoice_providers.dart';
import 'invoice_history_screen.dart';

class InvoiceHubScreen extends ConsumerWidget {
  const InvoiceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? 'customer';
    if (role == 'admin' || role == 'super_admin') {
      return const _AdminInvoiceOpsScreen();
    }
    if (role == 'vendor') {
      return const _VendorInvoiceOpsScreen();
    }
    return const InvoiceHistoryScreen();
  }
}

class _VendorInvoiceOpsScreen extends ConsumerWidget {
  const _VendorInvoiceOpsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vendorInvoicePagerProvider);
    final gst = ref.watch(gstSummaryProvider);
    final totalInvoiced = state.items.fold<double>(0, (sum, row) => sum + row.grandTotal);
    final totalGst = state.items.fold<double>(0, (sum, row) => sum + row.tax);
    final refunds = state.items.where((e) => e.status.contains('refund')).length;
    final pending = state.items.where((e) => e.paymentStatus.toLowerCase() != 'paid').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Invoices'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(vendorInvoicePagerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vendorInvoicePagerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Total Invoiced', 'INR ${totalInvoiced.toStringAsFixed(0)}'),
                _metric('GST Collected', 'INR ${totalGst.toStringAsFixed(0)}'),
                _metric('Refunds Issued', '$refunds'),
                _metric('Pending Invoices', '$pending'),
              ],
            ),
            const SizedBox(height: 16),
            gst.when(
              data: (data) => Card(
                child: ListTile(
                  title: const Text('GST Summary'),
                  subtitle: Text(
                    'Invoices: ${data['summary']?['invoices'] ?? 0} • '
                    'Taxable: ${data['summary']?['taxable'] ?? 0} • '
                    'Refunds: ${data['summary']?['refunds'] ?? 0}',
                  ),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            ...state.items.map(
              (invoice) => Card(
                child: ListTile(
                  title: Text(invoice.invoiceNumber),
                  subtitle: Text(
                    'INR ${invoice.grandTotal.toStringAsFixed(2)} • ${invoice.status} • ${invoice.versionLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/invoice/details', arguments: invoice.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminInvoiceOpsScreen extends ConsumerStatefulWidget {
  const _AdminInvoiceOpsScreen();

  @override
  ConsumerState<_AdminInvoiceOpsScreen> createState() => _AdminInvoiceOpsScreenState();
}

class _AdminInvoiceOpsScreenState extends ConsumerState<_AdminInvoiceOpsScreen> {
  final _search = TextEditingController();
  final _verifyInvoiceId = TextEditingController();
  final _verifyHash = TextEditingController();

  String _paymentFilter = '';
  String _statusFilter = '';
  String _sortBy = 'latest';
  Map<String, dynamic>? _verifyResult;

  @override
  void dispose() {
    _search.dispose();
    _verifyInvoiceId.dispose();
    _verifyHash.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await ref.read(adminInvoicePagerProvider.notifier).refresh();
    ref.invalidate(invoiceEmailLogsProvider);
    ref.invalidate(invoiceReplayDashboardProvider);
    ref.invalidate(invoiceQueueHealthProvider);
    ref.invalidate(invoiceStorageHealthProvider);
    ref.invalidate(invoiceEmailHealthProvider);
    ref.invalidate(invoiceOpsHealthProvider);
    ref.invalidate(invoiceReplayAuditProvider);
    ref.invalidate(invoiceSuppressionsProvider);
  }

  Future<void> _applyFilters({int page = 1}) async {
    final current = ref.read(adminInvoicePagerProvider).query;
    await ref.read(adminInvoicePagerProvider.notifier).refresh(
          query: current.copyWith(
            search: _search.text.trim(),
            paymentStatus: _paymentFilter,
            status: _statusFilter,
            page: page,
          ),
        );
  }

  Future<void> _openExport(String relativePath) async {
    final baseUrl = const String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'https://abzora-backend.onrender.com',
    );
    await launchUrl(Uri.parse('$baseUrl$relativePath'), mode: LaunchMode.externalApplication);
  }

  Future<String?> _askReplayToken(String title) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Confirmation Token',
            hintText: 'CONFIRM_INVOICE_REPLAY',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return null;
    final token = controller.text.trim();
    if (token.isEmpty) return null;
    return token;
  }

  Future<void> _replayDlq() async {
    final token = await _askReplayToken('Replay DLQ');
    if (token == null) return;
    await ref.read(invoiceRepositoryProvider).replayDlq(confirmation: token);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DLQ replay queued.')));
    _refreshAll();
  }

  Future<void> _queueControl({required bool pause}) async {
    final token = await _askReplayToken(pause ? 'Pause Email Queue' : 'Resume Email Queue');
    if (token == null) return;
    if (pause) {
      await ref.read(invoiceRepositoryProvider).pauseQueue(
            queueName: 'invoice-email-sending',
            confirmation: token,
          );
    } else {
      await ref.read(invoiceRepositoryProvider).resumeQueue(
            queueName: 'invoice-email-sending',
            confirmation: token,
          );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pause ? 'Queue pause requested.' : 'Queue resume requested.')),
    );
    _refreshAll();
  }

  Future<void> _verifyInvoiceLookup() async {
    final id = _verifyInvoiceId.text.trim();
    if (id.isEmpty) return;
    final result = await ref.read(invoiceRepositoryProvider).verifyInvoice(id, hash: _verifyHash.text.trim());
    if (!mounted) return;
    setState(() => _verifyResult = result);
  }

  Future<void> _freezeInvoice(InvoiceEntity invoice) async {
    String freezeState = invoice.freezeState;
    bool legalHold = invoice.legalHold;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setStateDialog) => AlertDialog(
          title: Text('Freeze / Legal Hold (${invoice.invoiceNumber})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: freezeState.isEmpty ? 'none' : freezeState,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('none')),
                  DropdownMenuItem(value: 'frozen', child: Text('frozen')),
                  DropdownMenuItem(value: 'locked', child: Text('locked')),
                ],
                onChanged: (v) => setStateDialog(() => freezeState = v ?? 'none'),
              ),
              CheckboxListTile(
                value: legalHold,
                onChanged: (v) => setStateDialog(() => legalHold = v ?? false),
                title: const Text('Legal Hold'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(invoiceRepositoryProvider).freezeInvoice(
          invoice.id,
          freezeState: freezeState,
          legalHold: legalHold,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Freeze/hold updated.')));
    _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesState = ref.watch(adminInvoicePagerProvider);
    final emailLogs = ref.watch(invoiceEmailLogsProvider);
    final replay = ref.watch(invoiceReplayDashboardProvider);
    final queueHealth = ref.watch(invoiceQueueHealthProvider);
    final storageHealth = ref.watch(invoiceStorageHealthProvider);
    final emailHealth = ref.watch(invoiceEmailHealthProvider);
    final invoiceHealth = ref.watch(invoiceOpsHealthProvider);
    final replayAudit = ref.watch(invoiceReplayAuditProvider);
    final suppressions = ref.watch(invoiceSuppressionsProvider);
    final query = invoicesState.query;

    final sorted = [...invoicesState.items];
    if (_sortBy == 'amount_desc') {
      sorted.sort((a, b) => b.grandTotal.compareTo(a.grandTotal));
    } else if (_sortBy == 'amount_asc') {
      sorted.sort((a, b) => a.grandTotal.compareTo(b.grandTotal));
    } else {
      sorted.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Invoice Operations')),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Search customer id',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _paymentFilter,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Payment: All')),
                        DropdownMenuItem(value: 'paid', child: Text('Payment: Paid')),
                        DropdownMenuItem(value: 'pending', child: Text('Payment: Pending')),
                      ],
                      onChanged: (v) {
                        setState(() => _paymentFilter = v ?? '');
                        _applyFilters();
                      },
                    ),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Status: All')),
                        DropdownMenuItem(value: 'generated', child: Text('Generated')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                        DropdownMenuItem(value: 'partially_refunded', child: Text('Partially Refunded')),
                      ],
                      onChanged: (v) {
                        setState(() => _statusFilter = v ?? '');
                        _applyFilters();
                      },
                    ),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'latest', child: Text('Sort: Latest')),
                        DropdownMenuItem(value: 'amount_desc', child: Text('Sort: Amount High-Low')),
                        DropdownMenuItem(value: 'amount_asc', child: Text('Sort: Amount Low-High')),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v ?? 'latest'),
                    ),
                    FilledButton.tonal(onPressed: _refreshAll, child: const Text('Reload')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _replayDlq,
                  icon: const Icon(Icons.replay_circle_filled_outlined),
                  label: const Text('Replay DLQ'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _queueControl(pause: true),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Pause Queue'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _queueControl(pause: false),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Resume Queue'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openExport(ref.read(invoiceRepositoryProvider).exportCsvUrl()),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Export CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openExport(ref.read(invoiceRepositoryProvider).exportXlsxUrl()),
                  icon: const Icon(Icons.grid_on_outlined),
                  label: const Text('Export XLSX'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _verifyInvoiceId,
                        decoration: const InputDecoration(hintText: 'Invoice ID'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _verifyHash,
                        decoration: const InputDecoration(hintText: 'Optional hash'),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _verifyInvoiceLookup,
                      child: const Text('Verify Lookup'),
                    ),
                    if (_verifyResult != null)
                      Text(
                        'valid:${_verifyResult!['valid']} hash:${_verifyResult!['hashVerified']} qr:${_verifyResult!['qrVerified']}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _healthGrid(queueHealth, storageHealth, emailHealth, invoiceHealth),
            const SizedBox(height: 10),
            replay.when(
              data: (data) => Card(
                child: ListTile(
                  title: const Text('Replay Dashboard'),
                  subtitle: Text(
                    'Queues: ${(data['queues'] as Map?)?.length ?? 0} • Audits: ${(data['replayAudit'] as List?)?.length ?? 0}',
                  ),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            replayAudit.when(
              data: (rows) => Card(
                child: ExpansionTile(
                  title: const Text('Replay Audit Logs'),
                  subtitle: Text('Recent: ${rows.length}'),
                  children: rows.take(10).map((row) => ListTile(
                    dense: true,
                    title: Text((row['action'] ?? '').toString()),
                    subtitle: Text('queue: ${row['queueName'] ?? ''}'),
                  )).toList(),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            suppressions.when(
              data: (rows) => Card(
                child: ExpansionTile(
                  title: const Text('Suppressed Emails'),
                  subtitle: Text('Active: ${rows.length}'),
                  children: rows.take(10).map((row) => ListTile(
                    dense: true,
                    title: Text((row['email'] ?? '').toString()),
                    subtitle: Text('reason: ${row['reason'] ?? ''}'),
                  )).toList(),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            emailLogs.when(
              data: (logs) => Card(
                child: ExpansionTile(
                  title: const Text('Email Lifecycle Logs'),
                  subtitle: Text('Recent: ${logs.length}'),
                  children: logs.take(12).map((log) {
                    final id = (log['_id'] ?? '').toString();
                    final status = (log['status'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      title: Text((log['email'] ?? '').toString()),
                      subtitle: Text('status: $status'),
                      trailing: status == 'failed'
                          ? IconButton(
                              onPressed: id.isEmpty
                                  ? null
                                  : () async {
                                      await ref.read(invoiceRepositoryProvider).resendEmailLog(id);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('Resend queued.')),
                                      );
                                      ref.invalidate(invoiceEmailLogsProvider);
                                    },
                              icon: const Icon(Icons.restart_alt_rounded),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text('Page ${query.page}'),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: query.page <= 1 ? null : () => _applyFilters(page: query.page - 1),
                      child: const Text('Prev'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: invoicesState.hasMore ? () => ref.read(adminInvoicePagerProvider.notifier).nextPage() : null,
                      child: const Text('Next'),
                    ),
                    const Spacer(),
                    if (invoicesState.loading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
            ...sorted.map((invoice) => _invoiceTile(context, invoice, onFreeze: () => _freezeInvoice(invoice))),
          ],
        ),
      ),
    );
  }
}

Widget _invoiceTile(
  BuildContext context,
  InvoiceEntity invoice, {
  required VoidCallback onFreeze,
}) {
  return Card(
    child: ListTile(
      title: Text(invoice.invoiceNumber),
      subtitle: Text(
        'INR ${invoice.grandTotal.toStringAsFixed(2)} • ${invoice.paymentStatus} • '
        '${invoice.status} • ${invoice.versionLabel} • freeze:${invoice.freezeState}${invoice.legalHold ? ' • legal-hold' : ''}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'freeze') onFreeze();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'freeze', child: Text('Freeze / Legal Hold')),
        ],
      ),
      onTap: () => Navigator.pushNamed(context, '/invoice/details', arguments: invoice.id),
    ),
  );
}

Widget _metric(String title, String value) {
  return SizedBox(
    width: 170,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E0D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

Widget _healthGrid(
  AsyncValue<Map<String, dynamic>> queue,
  AsyncValue<Map<String, dynamic>> storage,
  AsyncValue<Map<String, dynamic>> email,
  AsyncValue<Map<String, dynamic>> invoices,
) {
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _healthCard('Queue', queue),
      _healthCard('Storage', storage),
      _healthCard('Email', email),
      _healthCard('Invoices', invoices),
    ],
  );
}

Widget _healthCard(String label, AsyncValue<Map<String, dynamic>> state) {
  return SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: state.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('status: ${data['status'] ?? 'ok'}'),
            ],
          ),
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Loading...'),
              SizedBox(height: 6),
              LinearProgressIndicator(),
            ],
          ),
          error: (_, _) => const Text('Unavailable'),
        ),
      ),
    ),
  );
}
