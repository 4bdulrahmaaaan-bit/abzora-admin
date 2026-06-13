import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'delivery_screen.dart';

class RiderTasksScreen extends StatelessWidget {
  const RiderTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<AuthProvider>().user;
    if (rider == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Loading tasks',
          subtitle: 'Syncing your delivery queue.',
        ),
      );
    }
    final service = RiderService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(title: const Text('Tasks & Deliveries')),
      body: StreamBuilder<List<UnifiedRiderTask>>(
        stream: service.watchUnifiedTasks(rider),
        builder: (context, taskSnapshot) {
          final tasks = taskSnapshot.data ?? const <UnifiedRiderTask>[];
          return StreamBuilder<List<OrderModel>>(
            stream: service.watchAssignedOrders(rider),
            builder: (context, orderSnapshot) {
              final assigned = orderSnapshot.data ?? const <OrderModel>[];
              if (taskSnapshot.connectionState == ConnectionState.waiting &&
                  orderSnapshot.connectionState == ConnectionState.waiting) {
                return const AbzioLoadingView(
                  title: 'Loading task queue',
                  subtitle: 'Preparing assigned deliveries and return pickups.',
                );
              }
              if (tasks.isEmpty && assigned.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: AbzioEmptyCard(
                      title: 'No active tasks',
                      subtitle:
                          'Accepted deliveries and return pickups will appear here.',
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  ...tasks.map(
                    (task) =>
                        _TaskTile(task: task, rider: rider, service: service),
                  ),
                  ...assigned.map((order) => _AssignedTile(order: order)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatefulWidget {
  const _TaskTile({
    required this.task,
    required this.rider,
    required this.service,
  });

  final UnifiedRiderTask task;
  final AppUser rider;
  final RiderService service;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _busy = false;

  Future<void> _runAction() async {
    if (widget.task.type != 'return' || widget.task.returnId == null) return;
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReturn = widget.task.type == 'return';
    final status = widget.task.status.toUpperCase();
    final buttonLabel = widget.task.status == 'assigned'
        ? 'Mark Picked'
        : widget.task.status == 'in_progress'
        ? 'Complete Return'
        : 'Completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isReturn ? 'RETURN PICKUP' : 'DELIVERY TASK',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFD4B06A),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                status,
                style: GoogleFonts.inter(
                  color: AbzioTheme.grey600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.task.address, style: GoogleFonts.inter(height: 1.45)),
          if (isReturn) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_busy || widget.task.status == 'completed')
                    ? null
                    : _runAction,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignedTile extends StatelessWidget {
  const _AssignedTile({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            order.shippingAddress,
            style: GoogleFonts.inter(color: AbzioTheme.grey600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryScreen(order: order),
                  ),
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
