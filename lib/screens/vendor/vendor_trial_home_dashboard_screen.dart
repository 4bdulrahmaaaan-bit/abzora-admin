import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/trial_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
import '../../utils/app_mode_routes.dart';

class VendorTrialHomeDashboardScreen extends StatefulWidget {
  const VendorTrialHomeDashboardScreen({super.key});

  @override
  State<VendorTrialHomeDashboardScreen> createState() =>
      _VendorTrialHomeDashboardScreenState();
}

class _VendorTrialHomeDashboardScreenState
    extends State<VendorTrialHomeDashboardScreen> {
  static const Color _bg = Color(0xFFF8F5EF);
  static const Color _muted = Color(0xFF6D685F);
  static const Color _gold = Color(0xFFC8A96A);
  static const Color _goldSoft = Color(0xFFF1E8D8);
  static const double _cardRadius = 16;
  static const double _cardPadding = 14;
  static const double _sectionGap = 12;
  static const double _titleSize = 15;
  static const double _metaSize = 12.5;

  final DatabaseService _db = DatabaseService();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );
  final List<String> _sections = const <String>[
    'Overview',
    'Queue',
    'Active',
    'Returns',
    'Analytics',
    'Settings',
  ];

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;
  int _activeTab = 0;
  Map<String, dynamic> _dashboard = const <String, dynamic>{};
  List<TrialSession> _sessions = const <TrialSession>[];
  List<Map<String, dynamic>> _productSettings = const <Map<String, dynamic>>[];
  Map<String, _RiskScore> _riskOverrides = const <String, _RiskScore>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  AppUser? get _actor => context.read<AuthProvider>().user;

  Future<void> _load() async {
    final actor = _actor;
    if (!hasVendorOperationsAccess(actor)) {
      setState(() {
        _loading = false;
        _error = 'Vendor account required.';
      });
      return;
    }
    final safeActor = actor!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait<dynamic>([
        _db.getVendorTrialHomeDashboard(actor: safeActor),
        _db.getVendorTrialHomeSessions(actor: safeActor),
        _db.getVendorTrialHomeProductSettings(actor: safeActor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = Map<String, dynamic>.from(data[0] as Map);
        _sessions = data[1] as List<TrialSession>;
        _productSettings = (data[2] as List).cast<Map<String, dynamic>>();
      });
      await _loadRiskScores();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = AppErrorText.from(error));
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
        SnackBar(content: Text(AppErrorText.from(error))),
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

  _RiskScore _computeRisk(TrialSession session) {
    final itemCount = session.items.isEmpty ? 1 : session.items.length;
    final returnRate = (session.returnedItems.length / itemCount) * 100;
    final cancellations = session.approvalStatus == 'rejected' ? 100.0 : 20.0;
    final deviceRisk = session.userFlagged ? 100.0 : 20.0;
    final locationRisk = session.userCity.trim().isEmpty ? 70.0 : 20.0;
    final highValueOrder = session.subtotal >= 10000 ? 100.0 : 20.0;
    final abnormalBehavior = session.userTrialScore < 40 ? 80.0 : 20.0;

    final score = ((returnRate * 0.30) +
            (cancellations * 0.15) +
            (deviceRisk * 0.20) +
            (locationRisk * 0.15) +
            (highValueOrder * 0.10) +
            (abnormalBehavior * 0.10))
        .round()
        .clamp(0, 100);

    final reasons = <String>[];
    if (returnRate > 35) reasons.add('High return history');
    if (session.userFlagged) reasons.add('Device/account risk signal');
    if (session.subtotal >= 10000) reasons.add('High-value product request');
    if (session.userCity.trim().isEmpty) reasons.add('Location confidence low');
    if (session.userTrialScore < 40) reasons.add('Abnormal trial behavior');
    if (reasons.isEmpty) reasons.add('Stable profile and fit behavior');

    if (score <= 30) {
      return _RiskScore(
        score: score,
        level: 'Low',
        recommendation: score < 25 ? 'Auto approve' : 'Approve',
        reasons: reasons,
      );
    }
    if (score <= 70) {
      return _RiskScore(
        score: score,
        level: 'Medium',
        recommendation: 'Manual review',
        reasons: reasons,
      );
    }
    return _RiskScore(
      score: score,
      level: 'High',
      recommendation: 'Reject / Restrict',
      reasons: reasons,
    );
  }

  Future<void> _loadRiskScores() async {
    final actor = _actor;
    if (actor == null) return;
    final pending = _sessions.where((s) => s.approvalStatus == 'pending').toList();
    if (pending.isEmpty) {
      if (mounted) {
        setState(() => _riskOverrides = const <String, _RiskScore>{});
      }
      return;
    }
    final mapped = <String, _RiskScore>{};
    for (final session in pending) {
      try {
        final item = session.items.isNotEmpty ? session.items.first : null;
        final payload = {
          'user': {
            'return_rate': session.items.isEmpty
                ? 0
                : (session.returnedItems.length / session.items.length) * 100,
            'cancellations': session.approvalStatus == 'rejected' ? 2 : 0,
          },
          'session': {
            'product_views': session.items.length * 3,
            'repeated_try_requests': session.userFlagged ? 3 : 1,
          },
          'product': {
            'price': item?.price ?? session.subtotal,
            'category': item?.source ?? 'fashion',
          },
          'location': {
            'zone_risk': session.userCity.trim().isEmpty ? 60 : 20,
          },
          'device': {
            'multiple_accounts': session.userFlagged,
            'suspicious_activity': session.userFlagged,
          },
        };
        final result = await _db.getAiTrialRiskScore(actor: actor, payload: payload);
        final score = ((result['risk_score'] ?? 0) as num).toInt();
        final level = result['risk_level']?.toString() ?? 'Low';
        final recommendation = result['recommendation']?.toString() ?? 'Approve';
        final reasons = (result['reasons'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        mapped[session.id] = _RiskScore(
          score: score,
          level: level,
          recommendation: recommendation,
          reasons: reasons.isEmpty ? const ['Stable profile'] : reasons,
        );
      } catch (_) {
        mapped[session.id] = _computeRisk(session);
      }
    }
    if (!mounted) return;
    setState(() => _riskOverrides = mapped);
  }

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
    return Container(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          children: [
            Row(
              children: [
                const Text(
                  'Abianzo PARTNER',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: _sectionGap),
            _buildSectionSwitcher(),
            const SizedBox(height: _sectionGap),
            _buildSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
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
                  'Manage approvals, returns, and conversion quality',
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
    final queueCount = _pendingSessions.length;
    final activeCount = _activeSessions.length;
    final returnsCount = _returnSessions.length;
    String labelFor(int index) {
      final tab = _sections[index];
      if (tab == 'Queue') return 'Queue ($queueCount)';
      if (tab == 'Active') return 'Active ($activeCount)';
      if (tab == 'Returns') return 'Returns ($returnsCount)';
      return tab;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _goldSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, index) {
            final selected = _activeTab == index;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _activeTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE8C97C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                  border: Border(
                    bottom: BorderSide(
                      color:
                          selected ? const Color(0xFFD5AD43) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labelFor(index),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color:
                        selected ? Colors.black : const Color(0xFF7D776E),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: _sections.length,
        ),
      ),
    );
  }

  Widget _buildSection() {
    final current = switch (_activeTab) {
      0 => _buildOverviewSection(),
      1 => _buildQueueSection(),
      2 => _buildActiveSection(),
      3 => _buildReturnsSection(),
      4 => _buildAnalyticsSection(),
      5 => _buildSettingsSection(),
      _ => const SizedBox.shrink(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_activeTab),
        child: current,
      ),
    );
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
      return _empty('No requests right now\nNew try-at-home requests will appear here');
    }
    return Column(
      children: queue.map((session) {
        final score = _riskOverrides[session.id] ?? _computeRisk(session);
        final productName = session.items.isNotEmpty ? session.items.first.name : 'Abianzo Item';
        final size = session.recommendedSize.trim().isNotEmpty
            ? session.recommendedSize
            : (session.items.isNotEmpty ? session.items.first.recommendedSize : 'N/A');
        return _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: _titleSize,
                      ),
                    ),
                  ),
                  _riskPill(score.level),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${session.userName.isEmpty ? session.userId : session.userName}',
                style: const TextStyle(color: _muted, fontSize: _metaSize),
              ),
              const SizedBox(height: 4),
              Text(
                'Size: ${size.isEmpty ? 'N/A' : size} | Order value: ${_money.format(session.subtotal)}',
                style: const TextStyle(color: _muted, fontSize: _metaSize),
              ),
              const SizedBox(height: 6),
              Text(
                'AI insight: ${score.reasons.first}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Recommendation: ${score.recommendation} (Risk ${score.score}/100)',
                style: const TextStyle(color: _muted, fontSize: _metaSize),
              ),
              if (score.score > 70)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Restriction suggested: require prepaid and limit premium trials.',
                    style: TextStyle(color: Color(0xFF9A3A2A), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
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
                      style: FilledButton.styleFrom(backgroundColor: _gold),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Manual Review', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: score.level != 'Low',
                    onChanged: (_) {},
                    activeThumbColor: _gold,
                    activeTrackColor: _gold.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
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
                      product['name']?.toString() ?? 'Abianzo Item',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: _titleSize,
                      ),
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
                'Stock ${product['stock'] ?? 0} â€¢ ${product['category'] ?? ''}',
                style: const TextStyle(color: _muted, fontSize: _metaSize),
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
    final riskAlerts = _sessions.where((s) => _computeRisk(s).level == 'High').length;
    final sessionCount = (_dashboard['sessionCount'] ?? _sessions.length) as num;
    return Column(
      children: [
        _metricGrid([
          ('Conversion', '${conversion.toStringAsFixed(1)}%', Icons.trending_up_rounded),
          ('Return rate', '${returnRate.toStringAsFixed(1)}%', Icons.keyboard_return_rounded),
          ('Risk alerts', riskAlerts.toString(), Icons.warning_amber_rounded),
          ('Sessions', sessionCount.toString(), Icons.dataset_outlined),
        ]),
        const SizedBox(height: _sectionGap),
        _surface(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Last 7 days', style: TextStyle(color: _muted)),
              SizedBox(height: 6),
              Text(
                'Insights',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Approve high-fit requests quickly to improve conversion and reduce returns.',
                style: TextStyle(color: _muted),
              ),
              SizedBox(height: 4),
              Text(
                'Use manual approval for high-risk users and high-value outfits.',
                style: TextStyle(color: _muted),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: _titleSize,
                          ),
                        ),
                      ),
                      _pill(_activeStatusText(session)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _activeDurationText(session),
                    style: const TextStyle(color: _muted, fontSize: _metaSize),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _actionBusy ? null : () => _setStatus(session, 'completed'),
                          child: const Text('Mark completed'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _actionBusy ? null : () => _setStatus(session, 'return_initiated'),
                          child: const Text('Initiate return'),
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
                    session.items.isNotEmpty ? session.items.first.name : 'Abianzo Item',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: _titleSize,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer: ${session.userName.isEmpty ? session.userId : session.userName}',
                    style: const TextStyle(color: _muted, fontSize: _metaSize),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${session.returnedItems.isEmpty ? 'Not provided' : 'Item return requested'}',
                    style: const TextStyle(color: _muted, fontSize: _metaSize),
                  ),
                  const SizedBox(height: 4),
                  _pill('Status: ${_prettyStatus(session.status)}'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _gold),
                          onPressed: _actionBusy
                              ? null
                              : () => _setStatus(
                                    session,
                                    session.status,
                                    note: 'Return approved',
                                    returnDecision: 'approved',
                                  ),
                          child: const Text('Approve return'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _actionBusy
                              ? null
                              : () => _setStatus(
                                    session,
                                    session.status,
                                    note: 'Return rejected',
                                    returnDecision: 'rejected',
                                  ),
                          child: const Text('Reject return'),
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
  String _activeStatusText(TrialSession session) {
    switch (session.status) {
      case 'out_for_trial_delivery':
        return 'Out for trial';
      case 'trial_in_progress':
        return 'At customer';
      case 'return_initiated':
        return 'Return initiated';
      default:
        return _prettyStatus(session.status);
    }
  }

  String _activeDurationText(TrialSession session) {
    final created = session.createdAt;
    if (created == null) {
      return 'Duration unavailable';
    }
    final hours = DateTime.now().difference(created).inHours;
    return 'Duration: ${hours}h';
  }

  Widget _riskPill(String level) {
    Color bg;
    Color fg;
    if (level == 'Low') {
      bg = const Color(0xFFE8F7EB);
      fg = const Color(0xFF2A8C47);
    } else if (level == 'Medium') {
      bg = const Color(0xFFFFF3E3);
      fg = const Color(0xFFAF6B16);
    } else {
      bg = const Color(0xFFFFE8E3);
      fg = const Color(0xFFB23A2A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$level Risk',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
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
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
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
        minimumSize: const Size(0, 42),
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
      child: Text(text,
          style: const TextStyle(
            color: AbzioTheme.accentColor,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.1,
          )),
    );
  }

  Widget _empty(String text) {
    return _surface(
      child: Text(
        text,
        style: const TextStyle(color: _muted, height: 1.35),
      ),
    );
  }

String _prettyStatus(String status) => status.replaceAll('_', ' ').toUpperCase();
}

class _RiskScore {
  const _RiskScore({
    required this.score,
    required this.level,
    required this.recommendation,
    required this.reasons,
  });

  final int score;
  final String level;
  final String recommendation;
  final List<String> reasons;
}
