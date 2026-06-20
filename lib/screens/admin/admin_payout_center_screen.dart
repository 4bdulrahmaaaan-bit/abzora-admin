import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import 'api/admin_finance_api.dart';

class AdminPayoutCenterScreen extends StatefulWidget {
  const AdminPayoutCenterScreen({
    super.key,
    required this.finance,
    required this.users,
    required this.stores,
    this.onRefresh,
  });

  final AdminFinanceSummary finance;
  final List<AppUser> users;
  final List<Store> stores;
  final Future<void> Function()? onRefresh;

  @override
  State<AdminPayoutCenterScreen> createState() => _AdminPayoutCenterScreenState();
}

class _AdminPayoutCenterScreenState extends State<AdminPayoutCenterScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _date = DateFormat('dd MMM yyyy, hh:mm a');

  late TabController _tabController;
  AdminFinanceSummary? _finance;
  List<WithdrawalRequestSummary> _withdrawals = [];
  List<PayoutRecoveryJobSummary> _recoveryJobs = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  String _verificationFilter = 'All';
  String _search = '';
  final String _recoveryFilter = 'All';
  DateTimeRange? _dateRange;
  RangeValues? _amountRange;

  AppUser? get _actor => context.read<AuthProvider>().user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _finance = widget.finance;
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant AdminPayoutCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finance != widget.finance) {
      _finance = widget.finance;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool refreshFinance = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (refreshFinance) {
        final actor = _actor;
        if (actor != null) {
          _finance = await _db.getAdminFinance(actor: actor);
          await widget.onRefresh?.call();
        }
      }
      final results = await Future.wait([
        AdminFinanceApi.fetchWithdrawals(limit: 200),
        AdminFinanceApi.fetchRecoveryJobs(limit: 200),
      ]);
      if (!mounted) {
        return;
      }
      final withdrawals = (results[0]['withdrawals'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => WithdrawalRequestSummary.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      final recoveryJobs = (results[1]['jobs'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PayoutRecoveryJobSummary.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      setState(() {
        _withdrawals = withdrawals;
        _recoveryJobs = recoveryJobs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      await _loadAll(refreshFinance: true);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  AppUser? _userFor(WithdrawalRequestSummary withdrawal) {
    for (final user in widget.users) {
      if (user.id == withdrawal.userId) {
        return user;
      }
    }
    return null;
  }

  Store? _storeFor(WithdrawalRequestSummary withdrawal) {
    if (withdrawal.storeId.isEmpty) {
      return null;
    }
    for (final store in widget.stores) {
      if (store.id == withdrawal.storeId || store.storeId == withdrawal.storeId) {
        return store;
      }
    }
    return null;
  }

  WalletSummary? _walletFor(WithdrawalRequestSummary withdrawal) {
    final finance = _finance;
    if (finance == null) {
      return null;
    }
    final wallets = withdrawal.walletType.toLowerCase() == 'rider'
        ? finance.riderWallets
        : finance.vendorWallets;
    final linkedId = withdrawal.walletType.toLowerCase() == 'rider'
        ? withdrawal.riderId
        : withdrawal.storeId;
    for (final wallet in wallets) {
      if (wallet.linkedId == linkedId) {
        return wallet;
      }
    }
    return null;
  }

  bool _matchesSearch(WithdrawalRequestSummary withdrawal) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final user = _userFor(withdrawal);
    final store = _storeFor(withdrawal);
    final wallet = _walletFor(withdrawal);
    final haystack = <String>[
      withdrawal.id,
      withdrawal.userId,
      withdrawal.storeId,
      withdrawal.riderId,
      withdrawal.status,
      withdrawal.walletType,
      withdrawal.note,
      withdrawal.payoutId,
      withdrawal.failureReason,
      withdrawal.approvedBy,
      withdrawal.approvalLockId,
      user?.name ?? '',
      user?.phone ?? '',
      store?.name ?? '',
      wallet?.payoutProfile.accountHolderName ?? '',
      wallet?.payoutProfile.bankAccountNumber ?? '',
      wallet?.payoutProfile.upiId ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  bool _matchesFilters(WithdrawalRequestSummary withdrawal) {
    if (_roleFilter != 'All' &&
        withdrawal.walletType.toLowerCase() != _roleFilter.toLowerCase()) {
      return false;
    }
    if (_statusFilter != 'All' &&
        withdrawal.status.toLowerCase() != _statusFilter.toLowerCase()) {
      return false;
    }
    if (!_matchesSearch(withdrawal)) {
      return false;
    }
    if (_verificationFilter != 'All') {
      final wallet = _walletFor(withdrawal);
      final verification =
          wallet?.payoutProfile.verificationStatus.toLowerCase() ?? 'unverified';
      if (verification != _verificationFilter.toLowerCase()) {
        return false;
      }
    }
    if (_amountRange != null) {
      if (withdrawal.amount < _amountRange!.start ||
          withdrawal.amount > _amountRange!.end) {
        return false;
      }
    }
    if (_dateRange != null) {
      final requested = _toDate(withdrawal.requestedAt) ??
          _toDate(withdrawal.approvedAt) ??
          _toDate(withdrawal.processedAt);
      if (requested == null) {
        return false;
      }
      final from = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final to = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      if (requested.isBefore(from) || requested.isAfter(to)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesRecoveryFilters(PayoutRecoveryJobSummary job) {
    if (_recoveryFilter != 'All' &&
        job.status.toLowerCase() != _recoveryFilter.toLowerCase()) {
      return false;
    }
    if (_search.trim().isEmpty) {
      return true;
    }
    final query = _search.trim().toLowerCase();
    final haystack = <String>[
      job.id,
      job.withdrawalRequestId,
      job.userId,
      job.userRole,
      job.razorpayPayoutId,
      job.status,
      job.failureReason,
      job.metadata.toString(),
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  List<WithdrawalRequestSummary> get _filteredWithdrawals =>
      _withdrawals.where(_matchesFilters).toList();

  List<PayoutRecoveryJobSummary> get _filteredRecoveryJobs =>
      _recoveryJobs.where(_matchesRecoveryFilters).toList();

  DateTime? _toDate(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  double _sumAmount(Iterable<WithdrawalRequestSummary> items) {
    return items.fold<double>(0, (sum, item) => sum + item.amount);
  }

  Future<void> _approveWithdrawal(WithdrawalRequestSummary withdrawal) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.approveWithdrawalRequest(actor: actor, requestId: withdrawal.id);
    await _refresh();
  }

  Future<void> _rejectWithdrawal(
    WithdrawalRequestSummary withdrawal,
    String reason,
  ) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.rejectWithdrawalRequest(
      actor: actor,
      requestId: withdrawal.id,
      reason: reason,
    );
    await _refresh();
  }

  Future<void> _runRecoverySweep() async {
    await AdminFinanceApi.runRecoverySweep();
    await _refresh();
  }

  Future<void> _retryRecoveryJob(PayoutRecoveryJobSummary job) async {
    await AdminFinanceApi.retryRecoveryJob(job.id);
    await _refresh();
  }

  Future<void> _markRecoveryPaid(
    PayoutRecoveryJobSummary job, {
    String reason = '',
  }) async {
    await AdminFinanceApi.markRecoveryJobPaid(jobId: job.id, reason: reason);
    await _refresh();
  }

  Future<void> _markRecoveryFailed(
    PayoutRecoveryJobSummary job, {
    String reason = '',
    String finalStatus = 'failed',
  }) async {
    await AdminFinanceApi.markRecoveryJobFailed(
      jobId: job.id,
      reason: reason,
      finalStatus: finalStatus,
    );
    await _refresh();
  }

  Future<void> _escalateRecoveryJob(
    PayoutRecoveryJobSummary job, {
    String reason = '',
  }) async {
    await AdminFinanceApi.escalateRecoveryJob(jobId: job.id, reason: reason);
    await _refresh();
  }

  Future<void> _addRecoveryNote(PayoutRecoveryJobSummary job, String note) async {
    await AdminFinanceApi.addRecoveryJobNote(jobId: job.id, note: note);
    await _refresh();
  }

  Future<String?> _promptReason({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openWithdrawalReview(WithdrawalRequestSummary withdrawal) async {
    final user = _userFor(withdrawal);
    final wallet = _walletFor(withdrawal);
    PayoutRecoveryJobSummary? recoveryJob;
    for (final job in _recoveryJobs) {
      if (job.withdrawalRequestId == withdrawal.id) {
        recoveryJob = job;
        break;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111111),
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 980,
          child: WithdrawalReviewPanel(
            withdrawal: withdrawal,
            user: user,
            wallet: wallet,
            recoveryJob: recoveryJob,
            finance: _finance,
            onApprove: () => _approveWithdrawal(withdrawal),
            onReject: () async {
              final reason = await _promptReason(
                title: 'Reject withdrawal',
                label: 'Reason',
              );
              if (reason != null && reason.isNotEmpty) {
                await _rejectWithdrawal(withdrawal, reason);
              }
            },
            onRetry: recoveryJob == null ? null : () => _retryRecoveryJob(recoveryJob!),
            onMarkPaid: recoveryJob == null
                ? null
                : () async {
                    final reason = await _promptReason(
                      title: 'Mark payout paid',
                      label: 'Optional note',
                    );
                    await _markRecoveryPaid(recoveryJob!, reason: reason ?? '');
                  },
            onMarkFailed: recoveryJob == null
                ? null
                : () async {
                    final reason = await _promptReason(
                      title: 'Mark payout failed',
                      label: 'Reason',
                    );
                    if (reason != null && reason.isNotEmpty) {
                      await _markRecoveryFailed(recoveryJob!, reason: reason);
                    }
                  },
            onEscalate: recoveryJob == null
                ? null
                : () async {
                    final reason = await _promptReason(
                      title: 'Escalate to finance review',
                      label: 'Note',
                    );
                    if (reason != null && reason.isNotEmpty) {
                      await _escalateRecoveryJob(recoveryJob!, reason: reason);
                    }
                  },
            onAddNote: recoveryJob == null
                ? null
                : () async {
                    final note = await _promptReason(
                      title: 'Add internal note',
                      label: 'Note',
                    );
                    if (note != null && note.isNotEmpty) {
                      await _addRecoveryNote(recoveryJob!, note);
                    }
                  },
          ),
        ),
      ),
    );
  }

  List<_ReportLine> _withdrawalReportRows(List<WithdrawalRequestSummary> rows) {
    return rows.map((item) {
      final user = _userFor(item);
      final wallet = _walletFor(item);
      return _ReportLine(
        columns: [
          item.id,
          item.walletType,
          item.status,
          user?.name ?? item.userId,
          _money.format(item.amount),
          item.payoutId,
          wallet?.payoutProfile.verificationStatus ?? 'unverified',
          item.requestedAt,
        ],
      );
    }).toList();
  }

  Future<void> _exportCsv({
    required String fileName,
    required List<String> headers,
    required List<_ReportLine> rows,
  }) async {
    final csvRows = <List<String>>[
      headers,
      ...rows.map((row) => row.columns),
    ];
    final csv = csvRows
        .map(
          (row) => row.map((cell) {
            final value = cell.replaceAll('"', '""');
            if (value.contains(',') || value.contains('\n') || value.contains('"')) {
              return '"$value"';
            }
            return value;
          }).join(','),
        )
        .join('\n');
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(csv)),
          name: fileName,
          mimeType: 'text/csv',
        ),
      ],
      text: 'Exported $fileName',
    );
  }

  Future<void> _exportExcel({
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<_ReportLine> rows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    sheet.appendRow(headers.map((cell) => TextCellValue(cell)).toList());
    for (final row in rows) {
      sheet.appendRow(row.columns.map((cell) => TextCellValue(cell)).toList());
    }
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      text: 'Exported $fileName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSuperAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Admin access only'),
          ),
        ),
      );
    }
    final finance = _finance ?? widget.finance;
    final withdrawals = _filteredWithdrawals;
    final vendorWithdrawals =
        withdrawals.where((item) => item.walletType.toLowerCase() == 'vendor').toList();
    final riderWithdrawals =
        withdrawals.where((item) => item.walletType.toLowerCase() == 'rider').toList();
    final processing = withdrawals.where((item) => item.isProcessing).toList();
    final failed = withdrawals
        .where((item) =>
            item.isFailed || item.isReversed || item.isCancelled)
        .toList();
    final paidToday = withdrawals.where((item) {
      final paidAt = _toDate(item.paidAt) ?? _toDate(item.completedAt);
      if (paidAt == null) return false;
      final now = DateTime.now();
      return paidAt.year == now.year &&
          paidAt.month == now.month &&
          paidAt.day == now.day;
    }).toList();
    final paidThisMonth = withdrawals.where((item) {
      final paidAt = _toDate(item.paidAt) ?? _toDate(item.completedAt);
      if (paidAt == null) return false;
      final now = DateTime.now();
      return paidAt.year == now.year && paidAt.month == now.month;
    }).toList();
    final pending = withdrawals
        .where((item) =>
            item.isPending || item.isApproved || item.isManualReview)
        .toList();

    final summaryCards = <MetricSnapshot>[
      MetricSnapshot(
        label: 'Pending Withdrawals',
        value: pending.length.toString(),
        sublabel: _money.format(_sumAmount(pending)),
        trend: '${pending.length} open',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Processing Payouts',
        value: processing.length.toString(),
        sublabel: _money.format(_sumAmount(processing)),
        trend: '${processing.where((item) => _isStaleProcessing(item)).length} stale',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Paid Today',
        value: paidToday.length.toString(),
        sublabel: _money.format(_sumAmount(paidToday)),
        trend: 'Settled today',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Failed Payouts',
        value: failed.length.toString(),
        sublabel: _money.format(_sumAmount(failed)),
        trend: 'Needs review',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Vendor Withdrawals',
        value: vendorWithdrawals.length.toString(),
        sublabel: _money.format(_sumAmount(vendorWithdrawals)),
        trend: 'Wallet cash-outs',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Rider Withdrawals',
        value: riderWithdrawals.length.toString(),
        sublabel: _money.format(_sumAmount(riderWithdrawals)),
        trend: 'Wallet cash-outs',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Pending Amount',
        value: _money.format(finance.pendingWithdrawalAmount),
        sublabel: '${pending.length} queued',
        trend: 'Queue exposure',
        lastUpdated: _date.format(DateTime.now()),
      ),
      MetricSnapshot(
        label: 'Paid This Month',
        value: _money.format(_sumAmount(paidThisMonth)),
        sublabel: '${paidThisMonth.length} payouts',
        trend: 'Monthly settlement',
        lastUpdated: _date.format(DateTime.now()),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, summaryCards),
            const SizedBox(height: 18),
            if (_loading) const _PayoutSkeletonGrid(),
            if (!_loading && _error != null) _buildError(context),
            if (!_loading && _error == null)
              Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x33D4AF37)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: const Color(0xFFD4AF37),
                      unselectedLabelColor: Colors.white60,
                      indicatorColor: const Color(0xFFD4AF37),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Withdrawals'),
                        Tab(text: 'Processing'),
                        Tab(text: 'Failed'),
                        Tab(text: 'Recovery'),
                        Tab(text: 'Reports'),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0x22FFFFFF)),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          AdminPayoutDashboard(
                            finance: finance,
                            withdrawals: withdrawals,
                            summaryCards: summaryCards,
                            onRefresh: _refresh,
                          ),
                          WithdrawalManagementTable(
                            withdrawals: withdrawals,
                            onOpenReview: _openWithdrawalReview,
                            onSearchChanged: (value) => setState(() => _search = value),
                            onRoleChanged: (value) => setState(() => _roleFilter = value),
                            onStatusChanged: (value) => setState(() => _statusFilter = value),
                            onVerificationChanged: (value) =>
                                setState(() => _verificationFilter = value),
                            onDateRangeChanged: (value) =>
                                setState(() => _dateRange = value),
                            onAmountRangeChanged: (value) =>
                                setState(() => _amountRange = value),
                            roleFilter: _roleFilter,
                            statusFilter: _statusFilter,
                            verificationFilter: _verificationFilter,
                            search: _search,
                            dateRange: _dateRange,
                            amountRange: _amountRange,
                            userFor: _userFor,
                            storeFor: _storeFor,
                            walletFor: _walletFor,
                          ),
                          ProcessingQueueScreen(
                            withdrawals: processing,
                            onOpenReview: _openWithdrawalReview,
                          ),
                          FailedPayoutsScreen(
                            withdrawals: failed,
                            onOpenReview: _openWithdrawalReview,
                          ),
                          PayoutReconciliationScreen(
                            recoveryJobs: _filteredRecoveryJobs,
                            onRunRecovery: _runRecoverySweep,
                            onRetry: _retryRecoveryJob,
                            onMarkPaid: _markRecoveryPaid,
                            onMarkFailed: _markRecoveryFailed,
                            onEscalate: _escalateRecoveryJob,
                            onAddNote: _addRecoveryNote,
                          ),
                          PayoutReportingScreen(
                            withdrawals: withdrawals,
                            recoveryJobs: _filteredRecoveryJobs,
                            onExportWithdrawalsCsv: () => _exportCsv(
                              fileName: 'abzora-withdrawals.csv',
                              headers: const [
                                'Withdrawal ID',
                                'Role',
                                'Status',
                                'User',
                                'Amount',
                                'Payout ID',
                                'Verification',
                                'Requested At',
                              ],
                              rows: _withdrawalReportRows(withdrawals),
                            ),
                            onExportWithdrawalsExcel: () => _exportExcel(
                              fileName: 'abzora-withdrawals.xlsx',
                              sheetName: 'Withdrawals',
                              headers: const [
                                'Withdrawal ID',
                                'Role',
                                'Status',
                                'User',
                                'Amount',
                                'Payout ID',
                                'Verification',
                                'Requested At',
                              ],
                              rows: _withdrawalReportRows(withdrawals),
                            ),
                            onExportRecoveryCsv: () => _exportCsv(
                              fileName: 'abzora-payout-recovery.csv',
                              headers: const [
                                'Recovery Job ID',
                                'Withdrawal ID',
                                'Role',
                                'Status',
                                'Attempts',
                                'Payout ID',
                                'Failure Reason',
                              ],
                              rows: _recoveryJobs.map((job) {
                                return _ReportLine(columns: [
                                  job.id,
                                  job.withdrawalRequestId,
                                  job.userRole,
                                  job.status,
                                  job.attemptCount.toString(),
                                  job.razorpayPayoutId,
                                  job.failureReason,
                                ]);
                              }).toList(),
                            ),
                            onExportRecoveryExcel: () => _exportExcel(
                              fileName: 'abzora-payout-recovery.xlsx',
                              sheetName: 'Recovery',
                              headers: const [
                                'Recovery Job ID',
                                'Withdrawal ID',
                                'Role',
                                'Status',
                                'Attempts',
                                'Payout ID',
                                'Failure Reason',
                              ],
                              rows: _recoveryJobs.map((job) {
                                return _ReportLine(columns: [
                                  job.id,
                                  job.withdrawalRequestId,
                                  job.userRole,
                                  job.status,
                                  job.attemptCount.toString(),
                                  job.razorpayPayoutId,
                                  job.failureReason,
                                ]);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<MetricSnapshot> summaryCards) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF171717), Color(0xFF0E0E0E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x33D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0x22D4AF37),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.payments_outlined, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ABZORA Admin Payout Center',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Single source of truth for vendor and rider withdrawals, approvals, RazorpayX payouts, recovery, and reconciliation.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  FilledButton.icon(
                    onPressed: _runRecoverySweep,
                    icon: const Icon(Icons.search_outlined),
                    label: const Text('Run Reconciliation'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summaryCards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth > 800 ? 2.4 : 2.8,
                ),
                itemBuilder: (context, index) {
                  final card = summaryCards[index];
                  return _PayoutSummaryCard(card: card);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1313),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'Unable to load payout center.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  bool _isStaleProcessing(WithdrawalRequestSummary item) {
    final started = _toDate(item.processingStartedAt) ??
        _toDate(item.approvedAt) ??
        _toDate(item.requestedAt);
    if (started == null) {
      return false;
    }
    return DateTime.now().difference(started).inMinutes > 5;
  }
}

class AdminPayoutDashboard extends StatelessWidget {
  const AdminPayoutDashboard({
    super.key,
    required this.finance,
    required this.withdrawals,
    required this.summaryCards,
    required this.onRefresh,
  });

  final AdminFinanceSummary finance;
  final List<WithdrawalRequestSummary> withdrawals;
  final List<MetricSnapshot> summaryCards;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final pending = withdrawals.where((item) => item.isPending || item.isManualReview).length;
    final processing = withdrawals.where((item) => item.isProcessing).length;
    final failed = withdrawals
        .where((item) => item.isFailed || item.isReversed || item.isCancelled)
        .length;
    final recoveryJobs = finance.flaggedUsers;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _DetailChip(label: 'Pending queue', value: '$pending'),
            _DetailChip(label: 'Processing queue', value: '$processing'),
            _DetailChip(label: 'Failed queue', value: '$failed'),
            _DetailChip(label: 'Flagged users', value: '$recoveryJobs'),
            _DetailChip(
              label: 'Admin payouts done',
              value: NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                  .format(finance.payoutsDone),
            ),
            _DetailChip(
              label: 'Revenue',
              value: NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                  .format(finance.totalRevenue),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _AdminPanelCard(
          title: 'Operational notes',
          subtitle:
              'Approvals create RazorpayX payouts, recovery resolves crash gaps, and the review queue keeps manual approval mandatory.',
          child: Text(
            'Use the Withdrawals tab to inspect a request, verify bank profile, approve/reject, and hand off to recovery if payout state is uncertain.',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        _AdminPanelCard(
          title: 'Recent finance posture',
          subtitle: 'Latest health snapshot from the payout center.',
          child: Column(
            children: summaryCards
                .map(
                  (card) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.label, style: GoogleFonts.inter(color: Colors.white)),
                    subtitle: Text(
                      '${card.sublabel} • ${card.trend}',
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                    trailing: Text(
                      card.value,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class WithdrawalManagementTable extends StatelessWidget {
  const WithdrawalManagementTable({
    super.key,
    required this.withdrawals,
    required this.onOpenReview,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onVerificationChanged,
    required this.onDateRangeChanged,
    required this.onAmountRangeChanged,
    required this.roleFilter,
    required this.statusFilter,
    required this.verificationFilter,
    required this.search,
    required this.dateRange,
    required this.amountRange,
    required this.userFor,
    required this.storeFor,
    required this.walletFor,
  });

  final List<WithdrawalRequestSummary> withdrawals;
  final void Function(WithdrawalRequestSummary withdrawal) onOpenReview;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onVerificationChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final ValueChanged<RangeValues?> onAmountRangeChanged;
  final String roleFilter;
  final String statusFilter;
  final String verificationFilter;
  final String search;
  final DateTimeRange? dateRange;
  final RangeValues? amountRange;
  final AppUser? Function(WithdrawalRequestSummary) userFor;
  final Store? Function(WithdrawalRequestSummary) storeFor;
  final WalletSummary? Function(WithdrawalRequestSummary) walletFor;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _AdminPanelCard(
          title: 'Withdrawal management',
          subtitle:
              'Filter vendor and rider withdrawal requests, review bank verification, and open any request for action.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  _DropdownFilter(
                    label: 'Role',
                    value: roleFilter,
                    items: const ['All', 'vendor', 'rider'],
                    onChanged: onRoleChanged,
                  ),
                  _DropdownFilter(
                    label: 'Status',
                    value: statusFilter,
                    items: const [
                      'All',
                      'pending',
                      'approved',
                      'processing',
                      'paid',
                      'failed',
                      'reversed',
                      'cancelled',
                      'manual_review',
                    ],
                    onChanged: onStatusChanged,
                  ),
                  _DropdownFilter(
                    label: 'Verification',
                    value: verificationFilter,
                    items: const [
                      'All',
                      'verified',
                      'pending',
                      'unverified',
                      'failed',
                    ],
                    onChanged: onVerificationChanged,
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        initialDateRange: dateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.fromSeed(
                                seedColor: const Color(0xFFD4AF37),
                                brightness: Brightness.dark,
                              ),
                            ),
                            child: child ?? const SizedBox.shrink(),
                          );
                        },
                      );
                      onDateRangeChanged(picked);
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: const Text('Date range'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showDialog<RangeValues>(
                        context: context,
                        builder: (context) {
                          final start = TextEditingController(
                            text: amountRange?.start.toStringAsFixed(0) ?? '0',
                          );
                          final end = TextEditingController(
                            text: amountRange?.end.toStringAsFixed(0) ?? '50000',
                          );
                          return AlertDialog(
                            backgroundColor: const Color(0xFF111111),
                            title: const Text('Amount range'),
                            content: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: start,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Min'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: end,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Max'),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  final min = double.tryParse(start.text.trim()) ?? 0;
                                  final max =
                                      double.tryParse(end.text.trim()) ?? min + 1;
                                  Navigator.of(context).pop(RangeValues(min, max));
                                },
                                child: const Text('Apply'),
                              ),
                            ],
                          );
                        },
                      );
                      onAmountRangeChanged(result);
                    },
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: const Text('Amount range'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      onSearchChanged('');
                      onRoleChanged('All');
                      onStatusChanged('All');
                      onVerificationChanged('All');
                      onDateRangeChanged(null);
                      onAmountRangeChanged(null);
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear filters'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${withdrawals.length} withdrawal(s) match the current filter set.',
                style: GoogleFonts.inter(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFF1C1C1C)),
                  columns: const [
                    DataColumn(label: Text('Withdrawal ID')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Requested At')),
                    DataColumn(label: Text('Verified')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: withdrawals.map((withdrawal) {
                    final user = userFor(withdrawal);
                    final wallet = walletFor(withdrawal);
                    final store = storeFor(withdrawal);
                    final verification =
                        wallet?.payoutProfile.verificationStatus ?? 'unverified';
                    final displayName = user?.name.isNotEmpty == true
                        ? user!.name
                        : withdrawal.walletType == 'vendor'
                            ? store?.name ?? withdrawal.storeId
                            : withdrawal.riderId;
                    return DataRow(
                      cells: [
                        DataCell(Text(withdrawal.id)),
                        DataCell(Text(displayName)),
                        DataCell(Text(withdrawal.walletType.toUpperCase())),
                        DataCell(Text(money.format(withdrawal.amount))),
                        DataCell(_StatusChip(status: withdrawal.status)),
                        DataCell(Text(_fmtDate(withdrawal.requestedAt))),
                        DataCell(_StatusChip(status: verification)),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => onOpenReview(withdrawal),
                                child: const Text('Review'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WithdrawalReviewPanel extends StatelessWidget {
  const WithdrawalReviewPanel({
    super.key,
    required this.withdrawal,
    required this.user,
    required this.wallet,
    required this.recoveryJob,
    required this.finance,
    required this.onApprove,
    required this.onReject,
    required this.onRetry,
    required this.onMarkPaid,
    required this.onMarkFailed,
    required this.onEscalate,
    required this.onAddNote,
  });

  final WithdrawalRequestSummary withdrawal;
  final AppUser? user;
  final WalletSummary? wallet;
  final PayoutRecoveryJobSummary? recoveryJob;
  final AdminFinanceSummary? finance;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onMarkPaid;
  final Future<void> Function()? onMarkFailed;
  final Future<void> Function()? onEscalate;
  final Future<void> Function()? onAddNote;

  @override
  Widget build(BuildContext context) {
    final bank = wallet?.payoutProfile;
    final title = withdrawal.walletType == 'vendor'
        ? 'Vendor withdrawal review'
        : 'Rider withdrawal review';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD4AF37)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Review identity, wallet, bank verification, timeline, and payout recovery state.',
                      style: GoogleFonts.inter(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _InfoPanel(
                title: 'User information',
                children: [
                  _InfoRow(label: 'Name', value: user?.name ?? '-'),
                  _InfoRow(label: 'Phone', value: user?.phone ?? '-'),
                  _InfoRow(label: 'User ID', value: user?.id ?? withdrawal.userId),
                  _InfoRow(label: 'Role', value: user?.role ?? withdrawal.walletType),
                ],
              ),
              _InfoPanel(
                title: 'Wallet information',
                children: [
                  _InfoRow(
                    label: 'Available Balance',
                    value: finance == null
                        ? '-'
                        : NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                            .format(withdrawal.amount),
                  ),
                  _InfoRow(label: 'Pending Balance', value: _maybeWalletAmount(wallet?.pendingAmount)),
                  _InfoRow(label: 'Total Earnings', value: _maybeWalletAmount(wallet?.totalEarnings)),
                  _InfoRow(label: 'Total Withdrawals', value: _maybeWalletAmount(wallet?.totalWithdrawn)),
                ],
              ),
              _InfoPanel(
                title: 'Bank information',
                children: [
                  _InfoRow(label: 'Account Holder', value: bank?.accountHolderName ?? '-'),
                  _InfoRow(label: 'Bank Name', value: bank?.bankName ?? '-'),
                  _InfoRow(label: 'IFSC', value: bank?.bankIfsc ?? '-'),
                  _InfoRow(
                    label: 'Masked Account',
                    value: _maskAccount(bank?.bankAccountNumber ?? ''),
                  ),
                  _InfoRow(label: 'UPI ID', value: bank?.upiId ?? '-'),
                  _InfoRow(label: 'Verification', value: bank?.verificationStatus ?? 'unverified'),
                ],
              ),
              _InfoPanel(
                title: 'Withdrawal information',
                children: [
                  _InfoRow(label: 'Withdrawal ID', value: withdrawal.id),
                  _InfoRow(label: 'Amount', value: NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(withdrawal.amount)),
                  _InfoRow(label: 'Requested', value: _fmtDate(withdrawal.requestedAt)),
                  _InfoRow(label: 'Approved', value: _fmtDate(withdrawal.approvedAt)),
                  _InfoRow(label: 'Payout Status', value: withdrawal.status),
                  _InfoRow(label: 'Payout ID', value: withdrawal.payoutId.isEmpty ? '-' : withdrawal.payoutId),
                  _InfoRow(label: 'Approval Lock', value: withdrawal.approvalLockId.isEmpty ? '-' : withdrawal.approvalLockId),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoPanel(
            title: 'Timeline',
            children: [
              _InfoRow(label: 'Requested', value: _fmtDate(withdrawal.requestedAt)),
              _InfoRow(label: 'Approved', value: _fmtDate(withdrawal.approvedAt)),
              _InfoRow(label: 'Processing', value: _fmtDate(withdrawal.processingStartedAt)),
              _InfoRow(label: 'Payout Created', value: withdrawal.payoutId.isEmpty ? '-' : withdrawal.payoutId),
              _InfoRow(label: 'Webhook Received', value: _fmtDate(withdrawal.processedAt)),
              _InfoRow(label: 'Paid', value: _fmtDate(withdrawal.paidAt)),
            ],
          ),
          const SizedBox(height: 16),
          if (recoveryJob != null)
            _InfoPanel(
              title: 'Recovery',
              children: [
                _InfoRow(label: 'Recovery Job ID', value: recoveryJob!.id),
                _InfoRow(label: 'Status', value: recoveryJob!.status),
                _InfoRow(label: 'Attempts', value: recoveryJob!.attemptCount.toString()),
                _InfoRow(label: 'Last checked', value: _fmtDate(recoveryJob!.lastCheckedAt)),
                _InfoRow(label: 'Resolved', value: _fmtDate(recoveryJob!.resolvedAt)),
                _InfoRow(label: 'Failure reason', value: recoveryJob!.failureReason.isEmpty ? '-' : recoveryJob!.failureReason),
              ],
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => onApprove(),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve Withdrawal'),
              ),
              OutlinedButton.icon(
                onPressed: () => onReject(),
                icon: const Icon(Icons.close_outlined),
                label: const Text('Reject Withdrawal'),
              ),
              if (onRetry != null)
                OutlinedButton.icon(
                  onPressed: () => onRetry!(),
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('Retry Recovery'),
                ),
              if (onMarkPaid != null)
                OutlinedButton.icon(
                  onPressed: () => onMarkPaid!(),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Mark Paid'),
                ),
              if (onMarkFailed != null)
                OutlinedButton.icon(
                  onPressed: () => onMarkFailed!(),
                  icon: const Icon(Icons.report_outlined),
                  label: const Text('Mark Failed'),
                ),
              if (onEscalate != null)
                OutlinedButton.icon(
                  onPressed: () => onEscalate!(),
                  icon: const Icon(Icons.priority_high_outlined),
                  label: const Text('Escalate'),
                ),
              if (onAddNote != null)
                OutlinedButton.icon(
                  onPressed: () => onAddNote!(),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add Internal Note'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProcessingQueueScreen extends StatelessWidget {
  const ProcessingQueueScreen({
    super.key,
    required this.withdrawals,
    required this.onOpenReview,
  });

  final List<WithdrawalRequestSummary> withdrawals;
  final void Function(WithdrawalRequestSummary withdrawal) onOpenReview;

  @override
  Widget build(BuildContext context) {
    final stale = withdrawals.where((item) {
      final started = DateTime.tryParse(item.processingStartedAt) ??
          DateTime.tryParse(item.approvedAt) ??
          DateTime.tryParse(item.requestedAt);
      return started != null &&
          DateTime.now().difference(started).inMinutes > 5;
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _AdminPanelCard(
          title: 'Processing queue',
          subtitle: 'Watch all processing withdrawals and flag anything stuck for more than 5 minutes.',
          child: Column(
            children: withdrawals.isEmpty
                ? [const _EmptyState(message: 'No processing payouts right now.')]
                : withdrawals.map((item) {
                    final isStale = stale.any((staleItem) => staleItem.id == item.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isStale
                            ? Colors.red.withValues(alpha: 0.2)
                            : const Color(0x22D4AF37),
                        child: Icon(
                          Icons.hourglass_bottom_outlined,
                          color: isStale ? Colors.redAccent : const Color(0xFFD4AF37),
                        ),
                      ),
                      title: Text('${item.id} • ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(item.amount)}'),
                      subtitle: Text(
                        'User ${item.userId} • Payout ${item.payoutId.isEmpty ? 'pending' : item.payoutId}\nElapsed ${_elapsedLabel(item)}',
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          if (isStale) const _StatusChip(status: 'stale'),
                          TextButton(
                            onPressed: () => onOpenReview(item),
                            child: const Text('Review'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        ),
      ],
    );
  }
}

class FailedPayoutsScreen extends StatelessWidget {
  const FailedPayoutsScreen({
    super.key,
    required this.withdrawals,
    required this.onOpenReview,
  });

  final List<WithdrawalRequestSummary> withdrawals;
  final void Function(WithdrawalRequestSummary withdrawal) onOpenReview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _AdminPanelCard(
          title: 'Failed payouts center',
          subtitle: 'Review payout failures, reversals, cancellations, and retry-safe recovery cases.',
          child: Column(
            children: withdrawals.isEmpty
                ? [const _EmptyState(message: 'No failed payouts to review.')]
                : withdrawals.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x22FF5C5C),
                        child: Icon(Icons.error_outline, color: Colors.redAccent),
                      ),
                      title: Text(
                        '${item.id} • ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(item.amount)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${item.status.toUpperCase()} • ${item.failureReason.isEmpty ? 'No reason captured' : item.failureReason}',
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                      trailing: TextButton(
                        onPressed: () => onOpenReview(item),
                        child: const Text('Open'),
                      ),
                    );
                  }).toList(),
          ),
        ),
      ],
    );
  }
}

class PayoutReconciliationScreen extends StatelessWidget {
  const PayoutReconciliationScreen({
    super.key,
    required this.recoveryJobs,
    required this.onRunRecovery,
    required this.onRetry,
    required this.onMarkPaid,
    required this.onMarkFailed,
    required this.onEscalate,
    required this.onAddNote,
  });

  final List<PayoutRecoveryJobSummary> recoveryJobs;
  final Future<void> Function() onRunRecovery;
  final Future<void> Function(PayoutRecoveryJobSummary job) onRetry;
  final Future<void> Function(PayoutRecoveryJobSummary job, {String reason}) onMarkPaid;
  final Future<void> Function(PayoutRecoveryJobSummary job, {String reason, String finalStatus}) onMarkFailed;
  final Future<void> Function(PayoutRecoveryJobSummary job, {String reason}) onEscalate;
  final Future<void> Function(PayoutRecoveryJobSummary job, String note) onAddNote;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _AdminPanelCard(
          title: 'Recovery & reconciliation',
          subtitle:
              'Resolved, investigating, and manual review cases sit here until the payout state is clean again.',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => onRunRecovery(),
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: const Text('Run reconciliation'),
                  ),
                  _DetailChip(label: 'Recovered', value: _count('recovered').toString()),
                  _DetailChip(label: 'Manual review', value: _count('manual_review').toString()),
                  _DetailChip(label: 'Investigating', value: _count('investigating').toString()),
                  _DetailChip(label: 'Failed', value: _count('failed').toString()),
                ],
              ),
              const SizedBox(height: 18),
              if (recoveryJobs.isEmpty)
                const _EmptyState(message: 'No recovery jobs in the current filter scope.')
              else
                ...recoveryJobs.map(
                  (job) => Card(
                    color: const Color(0xFF171717),
                    child: ListTile(
                      title: Text(job.withdrawalRequestId, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        'Status: ${job.status} • Attempts: ${job.attemptCount} • Payout: ${job.razorpayPayoutId.isEmpty ? '-' : job.razorpayPayoutId}\n${job.failureReason.isEmpty ? 'No failure reason' : job.failureReason}',
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(onPressed: () => onRetry(job), child: const Text('Retry')),
                          TextButton(onPressed: () async {
                            final note = await _promptNote(context, 'Add internal note');
                            if (note != null && note.isNotEmpty) {
                              await onAddNote(job, note);
                            }
                          }, child: const Text('Note')),
                          TextButton(onPressed: () async {
                            final note = await _promptNote(context, 'Escalate to finance review');
                            await onEscalate(job, reason: note ?? '');
                          }, child: const Text('Escalate')),
                          TextButton(onPressed: () async {
                            final note = await _promptNote(context, 'Mark payout paid');
                            await onMarkPaid(job, reason: note ?? '');
                          }, child: const Text('Mark Paid')),
                          TextButton(onPressed: () async {
                            final note = await _promptNote(context, 'Mark payout failed');
                            await onMarkFailed(job, reason: note ?? '', finalStatus: 'failed');
                          }, child: const Text('Mark Failed')),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  int _count(String status) =>
      recoveryJobs.where((job) => job.status.toLowerCase() == status).length;

  Future<String?> _promptNote(BuildContext context, String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class PayoutReportingScreen extends StatelessWidget {
  const PayoutReportingScreen({
    super.key,
    required this.withdrawals,
    required this.recoveryJobs,
    required this.onExportWithdrawalsCsv,
    required this.onExportWithdrawalsExcel,
    required this.onExportRecoveryCsv,
    required this.onExportRecoveryExcel,
  });

  final List<WithdrawalRequestSummary> withdrawals;
  final List<PayoutRecoveryJobSummary> recoveryJobs;
  final Future<void> Function() onExportWithdrawalsCsv;
  final Future<void> Function() onExportWithdrawalsExcel;
  final Future<void> Function() onExportRecoveryCsv;
  final Future<void> Function() onExportRecoveryExcel;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final pending = withdrawals.where((item) => item.isPending || item.isManualReview).fold<double>(0, (sum, item) => sum + item.amount);
    final failed = withdrawals.where((item) => item.isFailed || item.isReversed || item.isCancelled).fold<double>(0, (sum, item) => sum + item.amount);
    final paid = withdrawals.where((item) => item.isPaid).fold<double>(0, (sum, item) => sum + item.amount);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _AdminPanelCard(
          title: 'Reporting center',
          subtitle: 'Generate operational reports for finance, settlements, and recovery.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DetailChip(label: 'Pending', value: money.format(pending)),
                  _DetailChip(label: 'Failed', value: money.format(failed)),
                  _DetailChip(label: 'Paid', value: money.format(paid)),
                  _DetailChip(label: 'Recovery jobs', value: recoveryJobs.length.toString()),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => onExportWithdrawalsCsv(),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export withdrawals CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExportWithdrawalsExcel(),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export withdrawals Excel'),
                  ),
                  FilledButton.icon(
                    onPressed: () => onExportRecoveryCsv(),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export recovery CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExportRecoveryExcel(),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export recovery Excel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminPanelCard extends StatelessWidget {
  const _AdminPanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x22D4AF37)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PayoutSummaryCard extends StatelessWidget {
  const _PayoutSummaryCard({required this.card});

  final MetricSnapshot card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(card.label, style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            card.value,
            style: GoogleFonts.inter(
              color: const Color(0xFFD4AF37),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(card.sublabel, style: GoogleFonts.inter(color: Colors.white54)),
          const SizedBox(height: 4),
          Text('${card.trend} • ${card.lastUpdated}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color _colorForStatus(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'paid':
      case 'verified':
        return Colors.green;
      case 'failed':
      case 'rejected':
        return Colors.red;
      case 'reversed':
        return Colors.deepOrange;
      case 'cancelled':
        return Colors.grey;
      case 'manual_review':
      case 'investigating':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 455,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: GoogleFonts.inter(color: Colors.white60)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white54),
        ),
      ),
    );
  }
}

class _PayoutSkeletonGrid extends StatelessWidget {
  const _PayoutSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x22D4AF37)),
            ),
          ),
        ),
      ),
    );
  }
}

String _fmtDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value.isEmpty ? '-' : value;
  }
  return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
}

String _maskAccount(String value) {
  if (value.length <= 4) {
    return value.isEmpty ? '-' : value;
  }
  return '****${value.substring(value.length - 4)}';
}

String _maybeWalletAmount(double? value) {
  if (value == null) {
    return '-';
  }
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
}

String _elapsedLabel(WithdrawalRequestSummary item) {
  final started = DateTime.tryParse(item.processingStartedAt) ??
      DateTime.tryParse(item.approvedAt) ??
      DateTime.tryParse(item.requestedAt);
  if (started == null) {
    return 'Unknown';
  }
  final minutes = DateTime.now().difference(started).inMinutes;
  if (minutes < 1) {
    return 'Just now';
  }
  return '$minutes min';
}

class MetricSnapshot {
  const MetricSnapshot({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.trend,
    required this.lastUpdated,
  });

  final String label;
  final String value;
  final String sublabel;
  final String trend;
  final String lastUpdated;
}

class _ReportLine {
  const _ReportLine({required this.columns});

  final List<String> columns;
}
