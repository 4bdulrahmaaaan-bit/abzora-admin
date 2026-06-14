import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/rider_service.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
import '../../widgets/payout_account_dialog.dart';
import '../../widgets/state_views.dart';

import '../../features/onboarding/rider_onboarding_screens.dart';
import 'rider_notifications_screen.dart';
import 'rider_operations_hub_screen.dart';
import 'rider_route_screen.dart';
import 'rider_tasks_screen.dart';
import 'rider_trials_screen.dart';

import 'rider_performance_screen.dart';
import 'rider_earnings_screen.dart';
import '../../services/rider_notification_api.dart';
import 'rider_payouts_screen.dart';

class _RiderUi {
  static const Color ivory = Color(0xFFF8F5EF);
  static const Color gold = Color(0xFFC8A86B);
}

class RiderDashboard extends StatelessWidget {
  const RiderDashboard({super.key, this.embedded = false});

  final bool embedded;

  Future<void> _requestWithdrawal(BuildContext context, AppUser actor) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw earnings'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            hintText: '200',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !context.mounted) {
      return;
    }
    try {
      await DatabaseService().requestRiderWithdraw(
        amount: amount,
        actor: actor,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Withdrawal request submitted.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppErrorText.from(error)),
        ),
      );
    }
  }

  Future<void> _managePayoutAccount(
    BuildContext context,
    AppUser actor,
    PayoutProfileSummary profile,
  ) async {
    final formValue = await showPayoutAccountDialog(
      context: context,
      title: 'Rider payout account',
      initialValue: profile,
    );
    if (formValue == null || !context.mounted) {
      return;
    }
    try {
      await DatabaseService().saveRiderPayoutProfile(
        actor: actor,
        methodType: formValue.methodType,
        accountHolderName: formValue.accountHolderName,
        upiId: formValue.upiId,
        bankAccountNumber: formValue.bankAccountNumber,
        bankIfsc: formValue.bankIfsc,
        bankName: formValue.bankName,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Payout account saved successfully.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppErrorText.from(error)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiderDashboardContent(
      embedded: embedded,
      requestWithdrawal: _requestWithdrawal,
      managePayoutAccount: _managePayoutAccount,
    );
  }
}

class RiderDashboardContent extends StatefulWidget {
  const RiderDashboardContent({
    super.key,
    required this.embedded,
    required this.requestWithdrawal,
    required this.managePayoutAccount,
  });

  final bool embedded;
  final Future<void> Function(BuildContext context, AppUser actor)
  requestWithdrawal;
  final Future<void> Function(
    BuildContext context,
    AppUser actor,
    PayoutProfileSummary profile,
  )
  managePayoutAccount;

  @override
  State<RiderDashboardContent> createState() => _RiderDashboardContentState();
}

class _RiderDashboardContentState extends State<RiderDashboardContent> {
  final RiderService _service = RiderService();
  Future<RiderDashboardSnapshot>? _dashboardFuture;
  String? _boundActorId;

  void _ensureDashboardFuture(AppUser actor) {
    if (_boundActorId == actor.id && _dashboardFuture != null) {
      return;
    }
    _boundActorId = actor.id;
    _dashboardFuture = _service.loadDashboardSnapshot(actor);
  }

  Future<void> _refreshDashboard(AppUser actor) async {
    setState(() {
      _dashboardFuture = _service.loadDashboardSnapshot(actor);
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final actor = auth.user;

    Widget content;
    if (actor == null) {
      content = const AbzioLoadingView(
        title: 'Loading rider workspace',
        subtitle: 'Syncing delivery requests and assigned orders.',
      );
    } else if (!auth.isRider) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AbzioEmptyCard(
            title: 'Rider access only',
            subtitle:
                'This workspace is reserved for Abianzo delivery partners.',
          ),
        ),
      );
    } else if (actor.riderApprovalStatus != 'approved') {
      content = _PendingApprovalView(actor: actor);
    } else {
      _ensureDashboardFuture(actor);
      content = FutureBuilder<RiderDashboardSnapshot>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const AbzioLoadingView(
              title: 'Loading rider dashboard',
              subtitle: 'Preparing wallet, deliveries, and route data.',
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const AbzioEmptyCard(
              title: 'Unable to load rider dashboard',
              subtitle: 'Please try refreshing the dashboard.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshDashboard(actor),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _RiderHeroCard(rider: actor),
                const SizedBox(height: 16),
                _RiderRealtimeStats(
                  todayDeliveries: data.analytics.todayDeliveries,
                  earningsToday: data.analytics.earningsToday,
                  pendingPayout:
                      data.analytics.pendingPayout + data.wallet.pendingAmount,
                ),
                const SizedBox(height: 14),
                _RiderWalletCard(
                  balance: data.wallet.balance,
                  pendingAmount: data.wallet.pendingAmount,
                  reservedAmount: data.wallet.reservedAmount,
                  totalEarnings: data.wallet.totalEarnings,
                  payoutProfile: data.wallet.payoutProfile,
                  transactions: data.analytics.transactions,
                  onWithdraw: () {
                    final profile = data.wallet.payoutProfile;
                    if (!profile.isConfigured) {
                      widget.managePayoutAccount(context, actor, profile);
                      return;
                    }
                    widget.requestWithdrawal(context, actor);
                  },
                  onManagePayoutAccount: () => widget.managePayoutAccount(
                    context,
                    actor,
                    data.wallet.payoutProfile,
                  ),
                ),
                const SizedBox(height: 20),
                _RiderStatusStrip(
                  assignedCount: data.assignedCount,
                  activeCount: data.activeCount,
                  completedCount: data.completedCount,
                ),
                const SizedBox(height: 14),
                const _RiderTbybCard(),
                const SizedBox(height: 14),
                _RouteLaunchCard(taskCount: data.tasks.length),
                const SizedBox(height: 24),

                // ─── ENTERPRISE ACTION GRID ───
                Text(
                  'OPERATIONS',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                _EnterpriseActionGrid(
                  items: [
                    _GridAction(
                      icon: Icons.local_shipping_rounded,
                      label: 'Deliveries',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderTasksScreen())),
                    ),
                    _GridAction(
                      icon: Icons.inventory_2_rounded,
                      label: 'Active Tasks',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderTasksScreen())),
                    ),
                    _GridAction(
                      icon: Icons.map_rounded,
                      label: 'Routes',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderRouteScreen())),
                    ),
                    _GridAction(
                      icon: Icons.checkroom_rounded,
                      label: 'Trials',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderTrialsScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  'FINANCIAL',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                _EnterpriseActionGrid(
                  items: [
                    _GridAction(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Earnings',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderEarningsScreen())),
                    ),
                    _GridAction(
                      icon: Icons.payments_rounded,
                      label: 'Wallet',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderPayoutsScreen())),
                    ),
                    _GridAction(
                      icon: Icons.history_rounded,
                      label: 'Settlements',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderPayoutsScreen())),
                    ),
                    _GridAction(
                      icon: Icons.trending_up_rounded,
                      label: 'Performance',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderPerformanceScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  'OPERATIONS HUB',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                _EnterpriseActionGrid(
                  items: [
                    _GridAction(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderOperationsHubScreen(initialIndex: 0))),
                    ),
                    _GridAction(
                      icon: Icons.school_rounded,
                      label: 'Training',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderOperationsHubScreen(initialIndex: 1))),
                    ),
                    _GridAction(
                      icon: Icons.support_agent_rounded,
                      label: 'Support',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderOperationsHubScreen(initialIndex: 2))),
                    ),
                    _GridAction(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RiderOperationsHubScreen(initialIndex: 3))),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'AVAILABLE DELIVERIES',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                if (data.availableDeliveries.isEmpty)
                  const AbzioEmptyCard(
                    title: 'No deliveries ready right now',
                    subtitle:
                        'Nearby return pickups and delivery requests will appear here as logistics updates arrive.',
                  )
                else
                  ...data.availableDeliveries.map(
                    (order) => _AvailableDeliveryCard(
                      order: order,
                      rider: actor,
                      service: _service,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'UNIFIED TASK QUEUE',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                if (data.tasks.isEmpty)
                  const AbzioEmptyCard(
                    title: 'No active tasks yet',
                    subtitle:
                        'Accept an available delivery and nearby return pickups will be bundled here automatically.',
                  )
                else ...[
                  ...data.tasks.map(
                    (task) => _UnifiedTaskCard(
                      task: task,
                      service: _service,
                      rider: actor,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    if (widget.embedded) {
      return ColoredBox(color: _RiderUi.ivory, child: content);
    }

    return Scaffold(
      backgroundColor: _RiderUi.ivory,
      appBar: AppBar(
        title: const Text('Abianzo Rider'),
        actions: [
          FutureBuilder<int>(
            future: RiderNotificationApi.getUnreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: const Color(0xFFD4AF37),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RiderNotificationsScreen()),
                ).then((_) {
                  // Refresh count when returning
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                }),
              );
            },
          ),
        ],
      ),
      extendBody: true,
      body: content,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFCF8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFE8DCC2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickNavItem(
                icon: Icons.space_dashboard_rounded,
                label: 'Home',
                active: true,
                onTap: () {},
              ),
              _QuickNavItem(
                icon: Icons.inventory_2_rounded,
                label: 'Tasks',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RiderTasksScreen()),
                  );
                },
              ),
              _QuickNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RiderRouteScreen()),
                  );
                },
              ),
              _QuickNavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderEarningsScreen(),
                    ),
                  );
                },
              ),
              _QuickNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                onTap: () {
                  final auth = context.read<AuthProvider>();
                  final user = auth.user;
                  final submitted = (user?.riderVehicleType ?? '').isNotEmpty && (user?.riderCity ?? user?.city ?? '').isNotEmpty;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => submitted 
                          ? const RiderOperationsHubScreen() 
                          : const RiderOnboardingFlowScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNavItem extends StatelessWidget {
  const _QuickNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _RiderUi.gold : const Color(0xFF6D655B);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF8E9) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLaunchCard extends StatelessWidget {
  const _RouteLaunchCard({required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RiderRouteScreen()),
        );
      },
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AbzioTheme.accentColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1E1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: Color(0xFF8D6A2E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open optimized route',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    taskCount == 0
                        ? 'Plan your next delivery route and bundle returns automatically.'
                        : 'See deliveries first, then nearby return pickups ordered by distance.',
                    style: GoogleFonts.inter(
                      color: AbzioTheme.grey600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF8D6A2E)),
          ],
        ),
      ),
    );
  }
}

class _PendingApprovalView extends StatelessWidget {
  const _PendingApprovalView({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context) {
    final submitted =
        (actor.riderVehicleType ?? '').isNotEmpty &&
        (actor.riderCity ?? actor.city ?? '').isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFB),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE8DCC2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RIDER ACCESS',
                style: GoogleFonts.poppins(
                  color: AbzioTheme.accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                submitted
                    ? 'Application under review'
                    : 'Complete your rider profile',
                style: GoogleFonts.inter(
                  color: const Color(0xFF111111),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                submitted
                    ? 'Your delivery partner profile is pending admin approval. Deliveries will appear here once approved.'
                    : 'Add your vehicle and city details so Abianzo can review your rider application.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AbzioEmptyCard(
          title: submitted ? 'Approval pending' : 'Rider profile incomplete',
          subtitle: submitted
              ? 'We have your rider details. An admin must approve your profile before you can accept deliveries.'
              : 'Name, phone, vehicle type, and city are required before rider access is enabled.',
          ctaLabel: submitted ? 'Edit application' : 'Start onboarding',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RiderOnboardingFlowScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _RiderHeroCard extends StatelessWidget {
  const _RiderHeroCard({required this.rider});

  final AppUser rider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8DCC2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELIVERY PARTNER',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            rider.name.isEmpty ? 'Abianzo Rider' : rider.name,
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: const Color(0xFF111111)),
          ),
          const SizedBox(height: 6),
          Text(
            '${rider.riderVehicleType ?? 'Bike'} • ${rider.riderCity ?? rider.city ?? 'City not set'}',
            style: GoogleFonts.inter(color: const Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}

class _RiderStatusStrip extends StatelessWidget {
  const _RiderStatusStrip({
    required this.assignedCount,
    required this.activeCount,
    required this.completedCount,
  });

  final int assignedCount;
  final int activeCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatusTileData(
        'Assigned',
        '$assignedCount',
        Icons.assignment_outlined,
        Colors.orange,
      ),
      _StatusTileData(
        'Active',
        '$activeCount',
        Icons.route_outlined,
        Colors.blue,
      ),
      _StatusTileData(
        'Delivered',
        '$completedCount',
        Icons.task_alt_rounded,
        Colors.green,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < tiles.length; index++) ...[
          Expanded(child: _RiderStatusTile(tile: tiles[index])),
          if (index != tiles.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _RiderRealtimeStats extends StatelessWidget {
  const _RiderRealtimeStats({
    required this.todayDeliveries,
    required this.earningsToday,
    required this.pendingPayout,
  });

  final int todayDeliveries;
  final double earningsToday;
  final double pendingPayout;

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RiderMoneyTile(
            label: 'Today deliveries',
            value: '$todayDeliveries',
            tint: const Color(0xFFD4AF37),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RiderMoneyTile(
            label: 'Earnings today',
            value: _money(earningsToday),
            tint: const Color(0xFF1C9A5F),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RiderMoneyTile(
            label: 'Pending payout',
            value: _money(pendingPayout),
            tint: const Color(0xFFD97A00),
          ),
        ),
      ],
    );
  }
}

class _RiderWalletCard extends StatelessWidget {
  const _RiderWalletCard({
    required this.balance,
    required this.pendingAmount,
    required this.reservedAmount,
    required this.totalEarnings,
    required this.payoutProfile,
    required this.transactions,
    required this.onWithdraw,
    required this.onManagePayoutAccount,
  });

  final double balance;
  final double pendingAmount;
  final double reservedAmount;
  final double totalEarnings;
  final PayoutProfileSummary payoutProfile;
  final List<WalletTransaction> transactions;
  final VoidCallback onWithdraw;
  final VoidCallback onManagePayoutAccount;

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Earnings Wallet',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Withdraw'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8D6A2E),
                  side: const BorderSide(color: Color(0xFFE8DCC2)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PayoutAccountSummaryCard(
            title: 'Settlement destination',
            profile: payoutProfile,
            onManage: onManagePayoutAccount,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RiderMoneyTile(
                  label: 'Available',
                  value: _money(balance),
                  tint: const Color(0xFF1C9A5F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RiderMoneyTile(
                  label: 'Pending',
                  value: _money(pendingAmount),
                  tint: const Color(0xFFD97A00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RiderMoneyTile(
                  label: 'Reserved',
                  value: _money(reservedAmount),
                  tint: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RiderMoneyTile(
                  label: 'Total earned',
                  value: _money(totalEarnings),
                  tint: const Color(0xFF635BFF),
                ),
              ),
            ],
          ),
          if (transactions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent payouts',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...transactions
                .take(3)
                .map(
                  (transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: Color(0xFF8D6A2E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            transaction.note.isEmpty
                                ? transaction.status
                                : transaction.note,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF666666),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _money(transaction.amount.abs()),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _RiderMoneyTile extends StatelessWidget {
  const _RiderMoneyTile({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DCC2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: tint,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusTileData {
  const _StatusTileData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _RiderStatusTile extends StatelessWidget {
  const _RiderStatusTile({required this.tile});

  final _StatusTileData tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DCC2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tile.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tile.icon, color: tile.color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tile.value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tile.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailableDeliveryCard extends StatefulWidget {
  const _AvailableDeliveryCard({
    required this.order,
    required this.rider,
    required this.service,
  });

  final OrderModel order;
  final AppUser rider;
  final RiderService service;

  @override
  State<_AvailableDeliveryCard> createState() => _AvailableDeliveryCardState();
}

class _AvailableDeliveryCardState extends State<_AvailableDeliveryCard> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await widget.service.acceptDelivery(
        orderId: widget.order.id,
        rider: widget.rider,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Delivery accepted and moved to your assigned orders.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.order.invoiceNumber.isEmpty
                ? widget.order.id
                : widget.order.invoiceNumber,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.order.shippingAddress,
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.order.items.length} item(s) • ₹${widget.order.totalAmount.toInt()}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Accept Delivery'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedTaskCard extends StatefulWidget {
  const _UnifiedTaskCard({
    required this.task,
    required this.service,
    required this.rider,
  });

  final UnifiedRiderTask task;
  final RiderService service;
  final AppUser rider;

  @override
  State<_UnifiedTaskCard> createState() => _UnifiedTaskCardState();
}

class _UnifiedTaskCardState extends State<_UnifiedTaskCard> {
  bool _busy = false;

  Future<void> _handlePrimaryAction() async {
    if (widget.task.type != 'return') {
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.task.status == 'assigned') {
        await widget.service.markReturnPicked(
          returnId: widget.task.returnId!,
          rider: widget.rider,
        );
      } else if (widget.task.status == 'in_progress') {
        await widget.service.completeReturn(
          returnId: widget.task.returnId!,
          rider: widget.rider,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            widget.task.status == 'assigned'
                ? 'Return marked as picked.'
                : 'Return marked as completed.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReturn = widget.task.type == 'return';
    final title = isReturn ? 'Return Pickup' : 'Delivery Task';
    final accent = isReturn ? Colors.orange : Colors.blue;
    final actionLabel = widget.task.status == 'assigned'
        ? (isReturn ? 'Mark Picked' : 'Start Task')
        : (widget.task.status == 'in_progress'
              ? (isReturn ? 'Complete Return' : 'In Progress')
              : 'Completed');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              _DeliveryStatusPill(
                status: widget.task.status == 'in_progress'
                    ? 'Picked up'
                    : (widget.task.status == 'completed'
                          ? 'Delivered'
                          : 'Assigned'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.task.address,
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isReturn
                ? 'Bundled return pickup on your route'
                : 'Unified delivery task synced from dispatch',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF666666),
            ),
          ),
          if (isReturn) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_busy || widget.task.status == 'completed')
                    ? null
                    : _handlePrimaryAction,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryStatusPill extends StatelessWidget {
  const _DeliveryStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Delivered' => Colors.green,
      'Out for delivery' => Colors.blue,
      'Picked up' => Colors.orange,
      _ => AbzioTheme.accentColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RiderTbybCard extends StatelessWidget {
  const _RiderTbybCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: AbzioTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Try Before You Buy',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TbybStat(
                  label: 'Active Trials',
                  value: '1',
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _TbybStat(
                  label: 'Upcoming',
                  value: '3',
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _TbybStat(
                  label: 'Avg. Duration',
                  value: '25m',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RiderTrialsScreen()),
              );
            },
            icon: const Icon(Icons.timer),
            label: const Text('View Assigned Trials'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AbzioTheme.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TbybStat extends StatelessWidget {
  const _TbybStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AbzioTheme.grey600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Enterprise Action Grid ────────────────────────────────────────────────────

class _GridAction {
  const _GridAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _EnterpriseActionGrid extends StatelessWidget {
  const _EnterpriseActionGrid({required this.items});

  final List<_GridAction> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items.map((action) {
        return GestureDetector(
          onTap: action.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8DCC2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  action.icon,
                  color: const Color(0xFF8D6A2E),
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
