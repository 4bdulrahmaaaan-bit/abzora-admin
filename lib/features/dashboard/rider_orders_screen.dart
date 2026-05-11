import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/rider_telemetry.dart';
import '../../core/widgets/rider_glass_card.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_service.dart';
import 'rider_live_tracking_screen.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen> {
  final RiderService _service = RiderService();
  final Set<String> _busyOrderIds = <String>{};

  Future<void> _accept(OrderModel order, AppUser rider) async {
    setState(() => _busyOrderIds.add(order.id));
    try {
      await _service.acceptDelivery(orderId: order.id, rider: rider);
      RiderTelemetry.event(
        'delivery_accept_success',
        data: {'orderId': order.id},
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RiderLiveTrackingScreen(order: order, rider: rider),
        ),
      );
    } catch (error) {
      RiderTelemetry.event(
        'delivery_accept_failed',
        data: {'orderId': order.id, 'error': error.toString()},
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busyOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _reject(OrderModel order, AppUser rider) async {
    setState(() => _busyOrderIds.add(order.id));
    try {
      await _service.updateDeliveryStatus(
        orderId: order.id,
        deliveryStatus: 'Rejected',
        rider: rider,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order rejected')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busyOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _showIncomingOrderPopup(OrderModel order, AppUser rider) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _IncomingOrderDialog(order: order),
    );
    if (!mounted || accepted == null) {
      return;
    }
    if (accepted) {
      await _accept(order, rider);
      return;
    }
    await _reject(order, rider);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<OrderModel>>(
      stream: _service.watchAssignedOrders(user),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snap.data!;
        if (orders.isEmpty) {
          return const Center(child: Text('No assigned deliveries yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RiderGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${order.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('${order.deliveryStatus} | ${order.shippingAddress}'),
                    const SizedBox(height: 6),
                    Text('Rs ${order.totalAmount.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    _actionRow(order, user),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _actionRow(OrderModel order, AppUser rider) {
    final isBusy = _busyOrderIds.contains(order.id);
    final status = order.deliveryStatus.toLowerCase();
    final isUnassigned = (order.riderId ?? '').isEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isUnassigned)
          FilledButton(
            onPressed: isBusy
                ? null
                : () => _showIncomingOrderPopup(order, rider),
            child: Text(isBusy ? 'Please wait...' : 'Incoming Order'),
          ),
        if (!isUnassigned && status != 'delivered')
          FilledButton.tonal(
            onPressed: isBusy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RiderLiveTrackingScreen(order: order, rider: rider),
                    ),
                  ),
            child: const Text('Open Live Map'),
          ),
      ],
    );
  }
}

class _IncomingOrderDialog extends StatefulWidget {
  const _IncomingOrderDialog({required this.order});

  final OrderModel order;

  @override
  State<_IncomingOrderDialog> createState() => _IncomingOrderDialogState();
}

class _IncomingOrderDialogState extends State<_IncomingOrderDialog> {
  static const int _initialSeconds = 18;
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop(false);
        }
        return;
      }
      if (mounted) {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / _initialSeconds;
    return AlertDialog(
      backgroundColor: const Color(0xFF101010),
      title: const Text(
        'Incoming Order',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Store: ${widget.order.storeId}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Drop: ${widget.order.shippingAddress}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Earnings: Rs ${(widget.order.totalAmount * 0.1).toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            'Auto close in ${_secondsLeft}s',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
