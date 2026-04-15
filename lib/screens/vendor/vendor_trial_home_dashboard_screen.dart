import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/trial_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';

class VendorTrialHomeDashboardScreen extends StatefulWidget {
  const VendorTrialHomeDashboardScreen({super.key});

  @override
  State<VendorTrialHomeDashboardScreen> createState() =>
      _VendorTrialHomeDashboardScreenState();
}

class _VendorTrialHomeDashboardScreenState
    extends State<VendorTrialHomeDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );
  final List<String> _sections = const <String>[
    'Overview',
    'Queue',
    'Settings',
    'Analytics',
    'Active',
    'Returns',
    'Risk',
  ];

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;
  int _sectionIndex = 0;
  Map<String, dynamic> _dashboard = const <String, dynamic>{};
  List<TrialSession> _sessions = const <TrialSession>[];
  List<Map<String, dynamic>> _productSettings = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  AppUser? get _actor => context.read<AuthProvider>().user;

  Future<void> _load() async {
    final actor = _actor;
    if (actor == null || actor.role != 'vendor') {
      setState(() {
        _loading = false;
        _error = 'Vendor account required.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait<dynamic>([
        _db.getVendorTrialHomeDashboard(actor: actor),
        _db.getVendorTrialHomeSessions(actor: actor),
        _db.getVendorTrialHomeProductSettings(actor: actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = Map<String, dynamic>.from(data[0] as Map);
        _sessions = data[1] as List<TrialSession>;
        _productSettings = (data[2] as List).cast<Map<String, dynamic>>();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approve(TrialSession session) async {
    await _guardedAction(() async {
      final actor = _actor;
      if (actor == null) return;
      await _db.approveVendorTrialRequest(actor: actor, trialId: session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trial request approved.')),
      );
      await _load();
    });
  }

  Future<void> _reject(TrialSession session) async {
    await _guardedAction(() async {
      final actor = _actor;
      if (actor == null) return;
      await _db.rejectVendorTrialRequest(actor: actor, trialId: session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trial request rejected.')),
      );
      await _load();
    });
  }

  Future<void> _setStatus(
    TrialSession session,
    String status, {
    String note = '',
    String returnDecision = '',
  }) async {
    await _guardedAction(() async {
      final actor = _actor;
      if (actor == null) return;
      await _db.updateVendorTrialHomeSession(
        actor: actor,
        trialId: session.id,
        status: status,
        note: note,
        returnDecision: returnDecision.isEmpty ? null : returnDecision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session updated to ${_prettyStatus(status)}.')),
      );
      await _load();
    });
  }

  Future<void> _updateProductSettings(
    Map<String, dynamic> product,
    Map<String, dynamic> trialHome,
  ) async {
    await _guardedAction(() async {
      final actor = _actor;
      if (actor == null) return;
      await _db.updateVendorTrialHomeProductSettings(
        actor: actor,
        productId: product['id']?.toString() ?? '',
        trialHome: trialHome,
      );
      await _load();
    });
  }

  Future<void> _guardedAction(Future<void> Function() action) async {
    if (_actionBusy) {
      return;
    }
    setState(() => _actionBusy = true);
    HapticFeedback.lightImpact();
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  List<TrialSession> get _pendingSessions => _sessions
      .where((session) => session.approvalStatus == 'pending')
      .toList();

  List<TrialSession> get _activeSessions => _sessions
      .where((session) => const <String>[
            'booked',
            'confirmed',
            'out_for_trial_delivery',
            'trial_in_progress',
          ].contains(session.status))
      .toList();

  List<TrialSession> get _returnSessions => _sessions
      .where((session) =>
          session.status == 'completed' ||
          session.returnedItems.isNotEmpty)
      .toList();

  List<TrialSession> get _riskSessions => _sessions
      .where((session) => session.userRiskScore >= 70 || session.userFlagged)
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildSectionSwitcher(),
          const SizedBox(height: 12),
          _buildSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.home_work_outlined, color: AbzioTheme.accentColor),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial at Home Control',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage approvals, returns, and conversion quality.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSwitcher() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) => ChoiceChip(
          selected: _sectionIndex == index,
          label: Text(_sections[index]),
          onSelected: (_) => setState(() => _sectionIndex = index),
          selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: _sections.length,
      ),
    );
  }

  Widget _buildSection() {
    switch (_sectionIndex) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildQueueSection();
      case 2:
        return _buildSettingsSection();
      case 3:
        return _buildAnalyticsSection();
      case 4:
        return _buildActiveSection();
      case 5:
        return _buildReturnsSection();
      case 6:
        return _buildRiskSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewSection() {
    final activeTrials = (_dashboard['activeTrials'] ?? _activeSessions.length) as num;
    final pending = (_dashboard['pendingApprovals'] ?? _pendingSessions.length) as num;
    final conversionRate = (_dashboard['conversionRate'] ?? 0) as num;
    final revenueFromTrials = (_dashboard['revenueFromTrials'] ?? 0) as num;
    return Column(
      children: [
        _metricGrid([
          ('Active trials', activeTrials.toString(), Icons.local_shipping_outlined),
          ('Pending approvals', pending.toString(), Icons.pending_actions_outlined),
          ('Conversion rate', '${conversionRate.toStringAsFixed(1)}%', Icons.show_chart_rounded),
          ('Trial revenue', _money.format(revenueFromTrials), Icons.currency_rupee_rounded),
        ]),
      ],
    );
  }

  Widget _buildQueueSection() {
    final queue = _pendingSessions;
    if (queue.isEmpty) {
      return _empty('No pending approvals.');
    }
    return Column(
      children: queue
          .map(
            (session) => _surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.userName.isEmpty ? session.userId : session.userName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _pill(_prettyStatus(session.approvalStatus)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.items.length} items | ${_money.format(session.subtotal)} | ${session.userCity.isEmpty ? 'Location pending' : session.userCity}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fit confidence ${session.fitConfidence.toStringAsFixed(0)}% • User score ${session.userTrialScore.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _actionBusy ? null : () => _reject(session),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _actionBusy ? null : () => _approve(session),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSettingsSection() {
    if (_productSettings.isEmpty) {
      return _empty('No products found for trial settings.');
    }
    return Column(
      children: _productSettings.map((product) {
        final trialHome = Map<String, dynamic>.from(
          product['trialHome'] as Map? ?? const {},
        );
        final enabled = trialHome['trialEnabled'] == true;
        final approvalMode = trialHome['approvalMode']?.toString() == 'manual'
            ? 'manual'
            : 'auto';
        final limit = ((trialHome['trialLimitPerDay'] ?? 20) as num).toInt();
        final trialFee = ((trialHome['trialFee'] ?? 99) as num).toDouble();
        return _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product['name']?.toString() ?? 'ABZORA Item',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Switch(
                    value: enabled,
                    activeThumbColor: AbzioTheme.accentColor,
                    onChanged: (value) => _updateProductSettings(product, {
                      ...trialHome,
                      'trialEnabled': value,
                    }),
                  ),
                ],
              ),
              Text(
                'Stock ${product['stock'] ?? 0} • ${product['category'] ?? ''}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniAction(
                    label: 'Daily limit: $limit',
                    onTap: () => _updateProductSettings(product, {
                      ...trialHome,
                      'trialLimitPerDay': limit + 1,
                    }),
                  ),
                  _miniAction(
                    label: 'Trial fee: ${_money.format(trialFee)}',
                    onTap: () => _updateProductSettings(product, {
                      ...trialHome,
                      'trialFee': trialFee + 20,
                    }),
                  ),
                  _miniAction(
                    label: 'Mode: ${approvalMode == 'manual' ? 'Manual' : 'Auto'}',
                    onTap: () => _updateProductSettings(product, {
                      ...trialHome,
                      'approvalMode': approvalMode == 'manual' ? 'auto' : 'manual',
                    }),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalyticsSection() {
    final conversion = ((_dashboard['conversionRate'] ?? 0) as num).toDouble();
    final returnRate = ((_dashboard['returnRate'] ?? 0) as num).toDouble();
    final riskAlerts = (_dashboard['riskAlerts'] ?? _riskSessions.length) as num;
    final sessionCount = (_dashboard['sessionCount'] ?? _sessions.length) as num;
    return Column(
      children: [
        _metricGrid([
          ('Conversion', '${conversion.toStringAsFixed(1)}%', Icons.trending_up_rounded),
          ('Return rate', '${returnRate.toStringAsFixed(1)}%', Icons.keyboard_return_rounded),
          ('Risk alerts', riskAlerts.toString(), Icons.warning_amber_rounded),
          ('Sessions', sessionCount.toString(), Icons.dataset_outlined),
        ]),
        const SizedBox(height: 12),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Insights',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Approve high-fit requests quickly to improve conversion and reduce returns.',
                style: TextStyle(color: Colors.black54),
              ),
              SizedBox(height: 4),
              Text(
                'Use manual approval for high-risk users and high-value outfits.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSection() {
    if (_activeSessions.isEmpty) {
      return _empty('No active trials right now.');
    }
    return Column(
      children: _activeSessions
          .map(
            (session) => _surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.userName.isEmpty ? session.userId : session.userName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _pill(_prettyStatus(session.status)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.deliverySlot} • ${session.deliveryWindowLabel}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniAction(
                        label: 'Out for trial',
                        onTap: () => _setStatus(session, 'out_for_trial_delivery'),
                      ),
                      _miniAction(
                        label: 'In progress',
                        onTap: () => _setStatus(session, 'trial_in_progress'),
                      ),
                      _miniAction(
                        label: 'Completed',
                        onTap: () => _setStatus(session, 'completed'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReturnsSection() {
    if (_returnSessions.isEmpty) {
      return _empty('No return reviews pending.');
    }
    return Column(
      children: _returnSessions
          .map(
            (session) => _surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.userName.isEmpty ? session.userId : session.userName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Returned ${session.returnedItems.length} • Kept ${session.keptItems.length}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _setStatus(
                                  session,
                                  session.status,
                                  note: 'Return approved',
                                  returnDecision: 'approved',
                                ),
                        child: const Text('Approve Return'),
                      ),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _setStatus(
                                  session,
                                  session.status,
                                  note: 'Condition issue flagged',
                                  returnDecision: 'flagged',
                                ),
                        child: const Text('Flag Issue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRiskSection() {
    if (_riskSessions.isEmpty) {
      return _empty('No active risk alerts for trial users.');
    }
    return Column(
      children: _riskSessions
          .map(
            (session) => _surface(
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFB45309)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.userName.isEmpty ? session.userId : session.userName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Risk ${session.userRiskScore.toStringAsFixed(0)} • Score ${session.userTrialScore.toStringAsFixed(0)}${session.userFlagged ? ' • Flagged' : ''}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _metricGrid(List<(String, String, IconData)> items) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return _surface(
          child: Row(
            children: [
              Icon(item.$3, color: AbzioTheme.accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    Text(
                      item.$1,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _surface({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _miniAction({required String label, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: _actionBusy ? null : onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2DED4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AbzioTheme.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AbzioTheme.accentColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return _surface(
      child: Text(
        text,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  String _prettyStatus(String status) => status.replaceAll('_', ' ').toUpperCase();
}
