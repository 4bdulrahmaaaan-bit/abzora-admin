import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/rider_telemetry.dart';
import '../../core/widgets/rider_glass_card.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_service.dart';

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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delivery accepted')));
    } catch (error) {
      RiderTelemetry.event(
        'delivery_accept_failed',
        data: {'orderId': order.id, 'error': error.toString()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busyOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _setStatus(
    OrderModel order,
    AppUser rider,
    String nextStatus,
    String successLabel,
  ) async {
    setState(() => _busyOrderIds.add(order.id));
    try {
      await _service.updateDeliveryStatus(
        orderId: order.id,
        deliveryStatus: nextStatus,
        rider: rider,
      );
      RiderTelemetry.event(
        'delivery_status_updated',
        data: {'orderId': order.id, 'status': nextStatus},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successLabel)));
    } catch (error) {
      RiderTelemetry.event(
        'delivery_status_failed',
        data: {
          'orderId': order.id,
          'status': nextStatus,
          'error': error.toString(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busyOrderIds.remove(order.id));
      }
    }
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
                    Text('${order.deliveryStatus} • ${order.shippingAddress}'),
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
          OutlinedButton(
            onPressed: isBusy ? null : () => _accept(order, rider),
            child: Text(isBusy ? 'Please wait...' : 'Accept'),
          ),
        if (!isUnassigned &&
            status != 'out_for_delivery' &&
            status != 'delivered')
          FilledButton(
            onPressed: isBusy
                ? null
                : () => _setStatus(
                    order,
                    rider,
                    'out_for_delivery',
                    'Marked as out for delivery',
                  ),
            child: const Text('Start'),
          ),
        if (!isUnassigned && status != 'delivered')
          FilledButton.tonal(
            onPressed: isBusy
                ? null
                : () => _setStatus(
                    order,
                    rider,
                    'delivered',
                    'Marked as delivered',
                  ),
            child: const Text('Complete'),
          ),
      ],
    );
  }
}
