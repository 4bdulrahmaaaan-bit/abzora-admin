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
    String labelFor(int index) {
      final tab = _sections[index];
      if (tab == 'Active') return 'Active (${_activeSessions.length})';
      if (tab == 'Returns') return 'Returns (${_returnSessions.length})';
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
      1 => _buildActiveSection(),
      2 => _buildReturnsSection(),
      3 => _buildAnalyticsSection(),
      4 => _buildSettingsSection(),
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
    final conversionRate = (_dashboard['conversionRate'] ?? 0) as num;
    final revenueFromTrials = (_dashboard['revenueFromTrials'] ?? 0) as num;
    return Column(
      children: [
        _metricGrid([
          ('Active trials', activeTrials.toString(), Icons.local_shipping_outlined),
          ('Conversion rate', '${conversionRate.toStringAsFixed(1)}%', Icons.show_chart_rounded),
          ('Trial revenue', _money.format(revenueFromTrials), Icons.currency_rupee_rounded),
        ]),
      ],
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
    final sessionCount = (_dashboard['sessionCount'] ?? _sessions.length) as num;
    return Column(
      children: [
        _metricGrid([
          ('Conversion', '${conversion.toStringAsFixed(1)}%', Icons.trending_up_rounded),
          ('Return rate', '${returnRate.toStringAsFixed(1)}%', Icons.keyboard_return_rounded),
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
