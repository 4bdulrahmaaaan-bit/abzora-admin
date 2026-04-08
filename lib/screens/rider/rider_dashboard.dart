import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/rider_service.dart';
import '../../theme.dart';
import '../../widgets/payout_account_dialog.dart';
import '../../widgets/state_views.dart';
import 'delivery_screen.dart';
import 'rider_onboarding_screen.dart';
import 'rider_route_screen.dart';

class RiderDashboard extends StatelessWidget {
  const RiderDashboard({
    super.key,
    this.embedded = false,
  });

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
            labelText: 'Amount (Rs)',
            hintText: '200',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text.trim())),
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
      await DatabaseService().requestRiderWithdraw(amount: amount, actor: actor);
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
          content: Text(error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '')),
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
          content: Text(
            error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final actor = auth.user;
    final service = RiderService();

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
            subtitle: 'This workspace is reserved for ABZORA delivery partners.',
          ),
        ),
      );
    } else if (actor.riderApprovalStatus != 'approved') {
      content = _PendingApprovalView(actor: actor);
    } else {
      content = RefreshIndicator(
        onRefresh: () => context.read<AuthProvider>().refreshCurrentUser(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _RiderHeroCard(rider: actor),
              const SizedBox(height: 16),
              StreamBuilder<RiderAnalytics>(
                stream: DatabaseService().watchPolledValue(
                  () => DatabaseService().getRiderAnalytics(actor: actor),
                ),
                builder: (context, analyticsSnapshot) {
                  return StreamBuilder<WalletSummary>(
                    stream: DatabaseService().watchPolledValue(
                      () => DatabaseService().getRiderWallet(actor: actor),
                    ),
                    builder: (context, walletSnapshot) {
                      final wallet = walletSnapshot.data;
                      final analytics = analyticsSnapshot.data;
                      return Column(
                        children: [
                          _RiderRealtimeStats(
                            todayDeliveries: analytics?.todayDeliveries ?? 0,
                            earningsToday: analytics?.earningsToday ?? 0,
                            pendingPayout: analytics?.pendingPayout ?? wallet?.pendingAmount ?? 0,
                          ),
                          const SizedBox(height: 14),
                          _RiderWalletCard(
                            balance: wallet?.balance ?? analytics?.availableBalance ?? actor.walletBalance,
                            pendingAmount: wallet?.pendingAmount ?? analytics?.pendingPayout ?? 0,
                            reservedAmount: wallet?.reservedAmount ?? analytics?.reservedAmount ?? 0,
                            totalEarnings: wallet?.totalEarnings ?? analytics?.totalEarnings ?? actor.walletBalance,
                            payoutProfile: wallet?.payoutProfile ?? const PayoutProfileSummary.empty(),
                            transactions: analytics?.transactions ?? const <WalletTransaction>[],
                            onWithdraw: () {
                              final profile = wallet?.payoutProfile ?? const PayoutProfileSummary.empty();
                              if (!profile.isConfigured) {
                                _managePayoutAccount(context, actor, profile);
                                return;
                              }
                              _requestWithdrawal(context, actor);
                            },
                            onManagePayoutAccount: () => _managePayoutAccount(
                              context,
                              actor,
                              wallet?.payoutProfile ?? const PayoutProfileSummary.empty(),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 20),
            StreamBuilder<List<OrderModel>>(
              stream: service.watchAssignedOrders(actor),
              builder: (context, assignedSnapshot) {
                final assignedOrders = assignedSnapshot.data ?? const <OrderModel>[];
                return StreamBuilder<List<UnifiedRiderTask>>(
                  stream: service.watchUnifiedTasks(actor),
                  builder: (context, taskSnapshot) {
                    final tasks = taskSnapshot.data ?? const <UnifiedRiderTask>[];
                    final assignedCount = tasks.where((task) => task.status == 'assigned').length;
                    final activeCount = tasks.where((task) => task.status == 'in_progress').length;
                    final completedCount = tasks.where((task) => task.status == 'completed').length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RiderStatusStrip(
                          assignedCount: assignedCount,
                          activeCount: activeCount,
                          completedCount: completedCount,
                        ),
                        const SizedBox(height: 14),
                        _RouteLaunchCard(taskCount: tasks.length),
                        const SizedBox(height: 24),
                        Text('AVAILABLE DELIVERIES', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 12),
                        StreamBuilder<List<OrderModel>>(
                          stream: service.watchAvailableDeliveries(),
                          builder: (context, availableSnapshot) {
                            if (availableSnapshot.connectionState == ConnectionState.waiting) {
                              return const AbzioLoadingView(
                                title: 'Loading available deliveries',
                                subtitle: 'Checking orders ready for pickup.',
                              );
                            }
                            final availableOrders = availableSnapshot.data ?? const <OrderModel>[];
                            if (availableOrders.isEmpty) {
                              return const AbzioEmptyCard(
                                title: 'No deliveries ready right now',
                                subtitle: 'Nearby return pickups and delivery requests will appear here as logistics updates arrive.',
                              );
                            }
                            return Column(
                              children: availableOrders
                                  .map(
                                    (order) => _AvailableDeliveryCard(
                                      order: order,
                                      rider: actor,
                                      service: service,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text('UNIFIED TASK QUEUE', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 12),
                        if (taskSnapshot.connectionState == ConnectionState.waiting)
                          const AbzioLoadingView(
                            title: 'Loading rider tasks',
                            subtitle: 'Preparing your delivery and return route.',
                          )
                        else if (tasks.isEmpty && assignedOrders.isEmpty)
                          const AbzioEmptyCard(
                            title: 'No active tasks yet',
                            subtitle: 'Accept an available delivery and nearby return pickups will be bundled here automatically.',
                          )
                        else ...[
                          ...tasks.map((task) => _UnifiedTaskCard(task: task, service: service, rider: actor)),
                          ...assignedOrders.map((order) => _AssignedOrderCard(order: order)),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    if (embedded) {
      return ColoredBox(
        color: AbzioTheme.grey50,
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Hub'),
      ),
      body: content,
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
          color: const Color(0xFFF9F6EA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.alt_route_rounded, color: Colors.black),
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
            const Icon(Icons.arrow_forward_rounded, color: Colors.black),
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
    final submitted = (actor.riderVehicleType ?? '').isNotEmpty && (actor.riderCity ?? actor.city ?? '').isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
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
                submitted ? 'Application under review' : 'Complete your rider profile',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                submitted
                    ? 'Your delivery partner profile is pending admin approval. Deliveries will appear here once approved.'
                    : 'Add your vehicle and city details so ABZORA can review your rider application.',
                style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
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
              MaterialPageRoute(builder: (_) => const RiderOnboardingScreen()),
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
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELIVERY PARTNER',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            rider.name.isEmpty ? 'ABZORA Rider' : rider.name,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            '${rider.riderVehicleType ?? 'Bike'} • ${rider.riderCity ?? rider.city ?? 'City not set'}',
            style: GoogleFonts.inter(color: Colors.white70),
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
      _StatusTileData('Assigned', '$assignedCount', Icons.assignment_outlined, Colors.orange),
      _StatusTileData('Active', '$activeCount', Icons.route_outlined, Colors.blue),
      _StatusTileData('Delivered', '$completedCount', Icons.task_alt_rounded, Colors.green),
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

  String _money(double amount) => 'Rs ${amount.toStringAsFixed(0)}';

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

  String _money(double amount) => 'Rs ${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Earnings Wallet',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Withdraw'),
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
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            ...transactions.take(3).map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF666666)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        transaction.note.isEmpty ? transaction.status : transaction.note,
                        style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _money(transaction.amount.abs()),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
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
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AbzioTheme.grey500),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey100),
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
              Text(tile.value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(tile.label, style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500)),
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
      await widget.service.acceptDelivery(orderId: widget.order.id, rider: widget.rider);
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.order.invoiceNumber.isEmpty ? widget.order.id : widget.order.invoiceNumber,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(widget.order.shippingAddress, style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.45)),
          const SizedBox(height: 8),
          Text(
            '${widget.order.items.length} item(s) • Rs ${widget.order.totalAmount.toInt()}',
            style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Accept Delivery'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedOrderCard extends StatelessWidget {
  const _AssignedOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                ),
              ),
              _DeliveryStatusPill(status: order.deliveryStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.shippingAddress, style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.45)),
          const SizedBox(height: 8),
          Text('${order.items.length} item(s)', style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeliveryScreen(order: order)),
                );
              },
              child: const Text('Open Delivery'),
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
        : (widget.task.status == 'in_progress' ? (isReturn ? 'Complete Return' : 'In Progress') : 'Completed');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    : (widget.task.status == 'completed' ? 'Delivered' : 'Assigned'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.task.address, style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.45)),
          const SizedBox(height: 8),
          Text(
            isReturn
                ? 'Bundled return pickup on your route'
                : 'Unified delivery task synced from dispatch',
            style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500),
          ),
          if (isReturn) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_busy || widget.task.status == 'completed') ? null : _handlePrimaryAction,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
