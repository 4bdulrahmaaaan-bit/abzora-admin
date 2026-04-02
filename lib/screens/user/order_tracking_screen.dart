import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tracking_animation_controller.dart';
import '../../widgets/tracking_step_widget.dart';
import '../../widgets/tracking_timeline.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with TickerProviderStateMixin {
  late final TrackingAnimationController _trackingAnimation;
  final DatabaseService _database = DatabaseService();
  String? _selectedOrderId;
  String? _activeUserId;
  Stream<List<OrderModel>>? _ordersStream;
  int? _lastAnimatedStepIndex;

  @override
  void initState() {
    super.initState();
    _trackingAnimation = TrackingAnimationController(vsync: this, totalSteps: 5);
  }

  @override
  void dispose() {
    _trackingAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      _activeUserId = null;
      _ordersStream = null;
      _lastAnimatedStepIndex = null;
      return const AbzioThemeScope.light(
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: AbzioEmptyCard(
                title: 'Sign in to track your orders',
                subtitle: 'Your order journey will appear here once you place an order.',
              ),
            ),
          ),
        ),
      );
    }

    if (_activeUserId != user.id || _ordersStream == null) {
      _activeUserId = user.id;
      _ordersStream = _database.getUserOrders(user.id);
      _lastAnimatedStepIndex = null;
    }

    return AbzioThemeScope.light(
      child: Scaffold(
        appBar: AppBar(title: const Text('Track Order')),
        body: StreamBuilder<List<OrderModel>>(
          stream: _ordersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AbzioLoadingView(
                title: 'Loading tracking updates',
                subtitle: 'Checking the latest delivery progress for your orders.',
              );
            }

            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AbzioEmptyCard(
                    title: 'Tracking not available yet',
                    subtitle: 'Place your first order and we will show its journey here.',
                    ctaLabel: 'Continue shopping',
                    onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ),
              );
            }

            final selectedOrder = _resolveSelectedOrder(orders);
            final currentStepIndex = _currentStepIndex(selectedOrder);
            if (_lastAnimatedStepIndex != currentStepIndex) {
              _lastAnimatedStepIndex = currentStepIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _trackingAnimation.animateToStep(currentStepIndex);
                }
              });
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _OrderHeroCard(order: selectedOrder),
                const SizedBox(height: 16),
                _CurrentStatusCard(order: selectedOrder),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.abzioBorder),
                    boxShadow: context.abzioShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tracking Timeline', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 18),
                      TrackingTimeline(
                        steps: _buildSteps(selectedOrder),
                        progressAnimation: _trackingAnimation.progress,
                        pulseAnimation: _trackingAnimation.pulse,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<AppUser?>(
                  future: _riderFor(selectedOrder),
                  builder: (context, riderSnapshot) {
                    return _RiderDetailsCard(
                      order: selectedOrder,
                      rider: riderSnapshot.data,
                      onCall: () => _handleCallAction(riderSnapshot.data),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ProductSummaryCard(order: selectedOrder),
                const SizedBox(height: 16),
                _ActionPanel(
                  order: selectedOrder,
                  refundRequestFuture: _database.getRefundRequestForOrder(selectedOrder.id, actor: user),
                  returnRequestFuture: _database.getReturnRequestForOrder(selectedOrder.id, actor: user),
                  canCancel: _canCancel(selectedOrder),
                  onCall: () async {
                    final rider = await _riderFor(selectedOrder);
                    if (!mounted) {
                      return;
                    }
                    _handleCallAction(rider);
                  },
                  onCancel: () => _cancelOrder(selectedOrder),
                  onRequestReturn: () => _requestReturn(selectedOrder, user),
                  onRequestRefund: () => _requestRefund(selectedOrder, user),
                  onHelp: () => _toast('AI Assistant can help with returns, refunds, and delivery updates.'),
                ),
                if (selectedOrder.trackingId.isEmpty) ...[
                  const SizedBox(height: 16),
                  _TrackingEmptyHint(order: selectedOrder),
                ],
                if (orders.length > 1) ...[
                  const SizedBox(height: 20),
                  Text('Your Recent Orders', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...orders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OrderSwitcherTile(
                        order: order,
                        selected: order.id == selectedOrder.id,
                        onTap: () => setState(() => _selectedOrderId = order.id),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  OrderModel _resolveSelectedOrder(List<OrderModel> orders) {
    final selected = orders.cast<OrderModel?>().firstWhere(
          (item) => item?.id == _selectedOrderId,
          orElse: () => orders.first,
        );
    final resolved = selected ?? orders.first;
    _selectedOrderId ??= resolved.id;
    return resolved;
  }

  Future<AppUser?> _riderFor(OrderModel order) async {
    if (order.riderId == null || order.riderId!.isEmpty) {
      return null;
    }
    return _database.getUser(order.riderId!);
  }

  int _currentStepIndex(OrderModel order) {
    final status = _normalizeStatus(order);
    switch (status) {
      case 'delivered':
        return 4;
      case 'out for delivery':
      case 'shipped':
      case 'assigned':
        return 3;
      case 'packed':
        return 2;
      case 'confirmed':
        return 1;
      case 'cancelled':
        return 0;
      default:
        return 0;
    }
  }

  String _normalizeStatus(OrderModel order) {
    final value = (order.deliveryStatus.isNotEmpty ? order.deliveryStatus : order.status).trim().toLowerCase();
    if (value == 'placed' || value == 'pending') {
      return 'order placed';
    }
    return value;
  }

  List<TrackingStepData> _buildSteps(OrderModel order) {
    const labels = [
      'Order Placed',
      'Confirmed',
      'Packed',
      'Out for Delivery',
      'Delivered',
    ];
    const icons = [
      Icons.receipt_long_outlined,
      Icons.verified_outlined,
      Icons.inventory_2_outlined,
      Icons.local_shipping_outlined,
      Icons.home_filled,
    ];

    final current = _currentStepIndex(order);
    return List.generate(labels.length, (index) {
      final state = index < current
          ? TrackingStepState.completed
          : index == current
              ? TrackingStepState.current
              : TrackingStepState.upcoming;
      return TrackingStepData(
        title: labels[index],
        timestampLabel: _timestampLabelFor(order, labels[index], index),
        icon: icons[index],
        state: state,
      );
    });
  }

  String _timestampLabelFor(OrderModel order, String title, int index) {
    final value = order.trackingTimestamps[title];
    if (value != null) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('dd MMM, hh:mm a').format(parsed);
      }
    }

    final current = _currentStepIndex(order);
    if (index == 0) {
      return DateFormat('dd MMM, hh:mm a').format(order.timestamp);
    }
    if (index <= current) {
      final inferred = order.timestamp.add(Duration(hours: index * 6));
      return DateFormat('dd MMM, hh:mm a').format(inferred);
    }

    final expected = _estimatedDelivery(order).subtract(Duration(hours: (4 - index) * 6));
    return 'Expected ${DateFormat('dd MMM, hh:mm a').format(expected)}';
  }

  DateTime _estimatedDelivery(OrderModel order) {
    if (_normalizeStatus(order) == 'delivered') {
      final delivered = order.trackingTimestamps['Delivered'];
      final parsed = delivered == null ? null : DateTime.tryParse(delivered);
      if (parsed != null) {
        return parsed;
      }
    }
    return order.timestamp.add(Duration(days: order.orderType == 'custom_tailoring' ? 6 : 3));
  }

  bool _canCancel(OrderModel order) {
    final status = _normalizeStatus(order);
    return status != 'out for delivery' &&
        status != 'shipped' &&
        status != 'delivered' &&
        status != 'cancelled';
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This action cannot be undone once the order starts shipping.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep order')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel order')),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _database.updateOrderStatus(order.id, 'Cancelled');
    if (!mounted) {
      return;
    }
    _toast('Your order has been cancelled.');
  }

  Future<void> _requestRefund(OrderModel order, AppUser user) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request refund'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tell us what went wrong with this order',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Submit request'),
            ),
          ],
        ),
      );

      if ((reason ?? '').trim().isEmpty) {
        return;
      }

      final refund = await _database.createRefundRequest(
        orderId: order.id,
        reason: reason!.trim(),
        actor: user,
      );
      if (!mounted) {
        return;
      }
      setState(() {});
      if (refund.status.toLowerCase() == 'rejected') {
        _toast(refund.rejectionReason ?? 'This refund request was blocked for safety reasons.');
      } else if (refund.fraudDecision.toLowerCase() == 'review') {
        _toast('Refund request submitted for manual review.');
      } else {
        _toast('Refund request submitted successfully.');
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      _toast(error.message.toString());
    } catch (_) {
      if (!mounted) {
        return;
      }
      _toast('Refund request could not be submitted right now.');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _requestReturn(OrderModel order, AppUser user) async {
    final reasonController = TextEditingController();
    final imageController = TextEditingController();
    try {
      final payload = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Return item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Tell us why you want to return this item',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                  hintText: 'Optional image URL',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'reason': reasonController.text,
                'imageUrl': imageController.text,
              }),
              child: const Text('Submit return'),
            ),
          ],
        ),
      );

      final reason = (payload?['reason'] ?? '').trim();
      if (reason.isEmpty) {
        return;
      }

      final request = await _database.createReturnRequest(
        orderId: order.id,
        reason: reason,
        actor: user,
        imageUrl: (payload?['imageUrl'] ?? '').trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {});
      _toast(
        request.status.toLowerCase() == 'assigned'
            ? 'Pickup has been scheduled for your return.'
            : 'Return request submitted successfully. Pickup will be scheduled.',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      _toast(error.message.toString());
    } catch (_) {
      if (!mounted) {
        return;
      }
      _toast('Return request could not be submitted right now.');
    } finally {
      reasonController.dispose();
      imageController.dispose();
    }
  }

  void _handleCallAction(AppUser? rider) {
    if (rider?.phone != null && rider!.phone!.trim().isNotEmpty) {
      _toast('Call ${rider.phone}');
      return;
    }
    _toast('Delivery partner contact will appear once assigned.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _OrderHeroCard extends StatelessWidget {
  const _OrderHeroCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final eta = DateFormat('dd MMM').format(
      order.timestamp.add(Duration(days: order.orderType == 'custom_tailoring' ? 6 : 3)),
    );
    final orderLabel = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AbzioTheme.accentColor.withValues(alpha: 0.18),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arriving by $eta', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _MetaBlock(label: 'Order ID', value: orderLabel),
              _MetaBlock(label: 'Order date', value: DateFormat('dd MMM yyyy').format(order.timestamp)),
              _MetaBlock(label: 'Delivery ETA', value: DateFormat('dd MMM yyyy').format(order.timestamp.add(Duration(days: order.orderType == 'custom_tailoring' ? 6 : 3)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final normalized = (order.deliveryStatus.isNotEmpty ? order.deliveryStatus : order.status).trim();
    final title = normalized.isEmpty ? 'Tracking not available yet' : normalized;
    final lower = normalized.toLowerCase();
    String subtitle;
    if (lower == 'out for delivery' || lower == 'shipped') {
      subtitle = 'Your order is on the way and should arrive soon.';
    } else if (lower == 'delivered') {
      subtitle = 'Your order has arrived successfully.';
    } else if (lower == 'packed') {
      subtitle = 'Your items are packed and preparing for dispatch.';
    } else if (lower == 'confirmed') {
      subtitle = 'Your order has been confirmed by the store.';
    } else if (lower == 'cancelled') {
      subtitle = 'This order has been cancelled.';
    } else {
      subtitle = 'Your order is confirmed and being prepared.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.local_shipping_outlined, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderDetailsCard extends StatelessWidget {
  const _RiderDetailsCard({
    required this.order,
    required this.rider,
    required this.onCall,
  });

  final OrderModel order;
  final AppUser? rider;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final hasRider = rider != null || order.assignedDeliveryPartner != 'Unassigned';
    final riderName = rider?.name ?? order.assignedDeliveryPartner;
    final riderPhone = rider?.phone;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Partner', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (!hasRider)
            Text(
              'A delivery partner will be assigned once your order is ready to move.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
                  child: Text(
                    riderName.isEmpty ? 'A' : riderName.substring(0, 1).toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AbzioTheme.accentColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(riderName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        riderPhone?.trim().isNotEmpty == true ? riderPhone! : 'Phone will appear once available',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProductSummaryCard extends StatelessWidget {
  const _ProductSummaryCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: item.imageUrl.isEmpty
                        ? Container(
                            height: 74,
                            width: 74,
                            color: context.abzioMuted,
                            child: Icon(Icons.checkroom_outlined, color: context.abzioSecondaryText),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            height: 74,
                            width: 74,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: context.abzioMuted),
                            errorWidget: (context, url, error) => Container(
                              color: context.abzioMuted,
                              child: Icon(Icons.broken_image_outlined, color: context.abzioSecondaryText),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Qty ${item.quantity}${item.size.trim().isNotEmpty ? ' • Size ${item.size}' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rs ${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.order,
    required this.refundRequestFuture,
    required this.returnRequestFuture,
    required this.canCancel,
    required this.onCall,
    required this.onCancel,
    required this.onRequestReturn,
    required this.onRequestRefund,
    required this.onHelp,
  });

  final OrderModel order;
  final Future<RefundRequest?> refundRequestFuture;
  final Future<ReturnRequest?> returnRequestFuture;
  final bool canCancel;
  final VoidCallback onCall;
  final VoidCallback onCancel;
  final VoidCallback onRequestReturn;
  final VoidCallback onRequestRefund;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          FutureBuilder<List<Object?>>(
            future: Future.wait<Object?>([
              refundRequestFuture,
              returnRequestFuture,
            ]),
            builder: (context, snapshot) {
              final refundRequest = snapshot.data?[0] as RefundRequest?;
              final returnRequest = snapshot.data?[1] as ReturnRequest?;
              final canRequestRefund = order.isPaymentVerified &&
                  order.paymentMethod.toUpperCase() != 'COD' &&
                  order.refundStatus.toLowerCase() != 'refunded' &&
                  order.returnStatus.toLowerCase() != 'completed' &&
                  (refundRequest == null || refundRequest.status.toLowerCase() == 'rejected') &&
                  ['delivered', 'cancelled', 'out for delivery'].contains(order.status.toLowerCase());
              final canRequestReturn = order.returnStatus.toLowerCase() != 'completed' &&
                  (returnRequest == null || returnRequest.status.toLowerCase() == 'rejected') &&
                  (order.isDelivered || order.status.toLowerCase() == 'delivered') &&
                  order.orderType != 'custom_tailoring' &&
                  !order.items.any((item) => item.isCustomTailoring);
              final refundLabel = () {
                if (order.refundStatus.toLowerCase() == 'refunded') {
                  return 'Refund status: Refunded';
                }
                if (refundRequest == null) {
                  return 'Online orders can be refunded from here when eligible.';
                }
                final status = refundRequest.status.toLowerCase();
                if (status == 'approved') {
                  return 'Refund status: Approved';
                }
                if (status == 'rejected') {
                  return 'Refund status: Rejected';
                }
                return 'Refund status: Pending review';
              }();
              final returnLabel = () {
                final status = (returnRequest?.status ?? order.returnStatus).trim().toLowerCase();
                if (status.isEmpty) {
                  return 'Returns are available within 3 days of delivery for non-custom items.';
                }
                if (status == 'requested') {
                  return 'Return status: Requested';
                }
                if (status == 'approved') {
                  return 'Return status: Approved for pickup';
                }
                if (status == 'assigned') {
                  return 'Return status: Pickup assigned';
                }
                if (status == 'picked') {
                  return 'Return status: Picked and awaiting quality check';
                }
                if (status == 'completed') {
                  return 'Return status: Completed';
                }
                if (status == 'rejected') {
                  return 'Return status: Rejected';
                }
                return 'Return status: ${status[0].toUpperCase()}${status.substring(1)}';
              }();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Call Delivery Partner'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canCancel ? onCancel : null,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel Order'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canRequestReturn ? onRequestReturn : null,
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('Return Item'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canRequestRefund ? onRequestRefund : null,
                        icon: const Icon(Icons.currency_rupee_rounded),
                        label: const Text('Request Refund'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onHelp,
                        icon: const Icon(Icons.support_agent_outlined),
                        label: const Text('Help / Support'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    returnLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.abzioSecondaryText,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    refundLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.abzioSecondaryText,
                        ),
                  ),
                  if ((returnRequest?.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Return note: ${returnRequest!.rejectionReason}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.abzioSecondaryText,
                          ),
                    ),
                  ],
                  if ((refundRequest?.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${refundRequest!.rejectionReason}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.abzioSecondaryText,
                          ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrackingEmptyHint extends StatelessWidget {
  const _TrackingEmptyHint({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.abzioSecondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tracking not available yet. We will update this screen as soon as your order moves to the next stage.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSwitcherTile extends StatelessWidget {
  const _OrderSwitcherTile({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  final OrderModel order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : context.abzioBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(order.timestamp),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              order.deliveryStatus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
