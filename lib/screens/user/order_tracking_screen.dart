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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _OrderHeroCard(order: selectedOrder),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.abzioBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TrackingTimeline(
                        steps: _buildSteps(selectedOrder),
                        progressAnimation: _trackingAnimation.progress,
                        pulseAnimation: _trackingAnimation.pulse,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DeliveryDetailsCard(order: selectedOrder),
                const SizedBox(height: 12),
                _ProductSummaryCard(order: selectedOrder),
                const SizedBox(height: 12),
                _ActionPanel(
                  actor: user,
                  order: selectedOrder,
                  refundRequestFuture: _database.getRefundRequestForOrder(selectedOrder.id, actor: user),
                  returnRequestFuture: _database.getReturnRequestForOrder(selectedOrder.id, actor: user),
                  canCancel: _canCancel(selectedOrder),
                  onSupport: () => _toast('Support is ready to help with delivery and order updates.'),
                  onCancel: () => _cancelOrder(selectedOrder, user),
                  onReorder: () => Navigator.popUntil(context, (route) => route.isFirst),
                ),
                if (selectedOrder.trackingId.isEmpty) ...[
                  const SizedBox(height: 12),
                  _TrackingEmptyHint(order: selectedOrder),
                ],
                if (orders.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Recent Orders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
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

  Future<void> _cancelOrder(OrderModel order, AppUser actor) async {
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

    await _database.updateOrderStatus(order.id, 'Cancelled', actor: actor);
    if (!mounted) {
      return;
    }
    _toast('Your order has been cancelled.');
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
    final eta = DateFormat('EEE, dd MMM').format(
      order.timestamp.add(Duration(days: order.orderType == 'custom_tailoring' ? 6 : 3)),
    );
    final orderLabel = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.abzioBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #$orderLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Arriving by $eta',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                  fontWeight: FontWeight.w600,
                ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: item.imageUrl.isEmpty
                        ? Container(
                            height: 72,
                            width: 72,
                            color: context.abzioMuted,
                            child: Icon(Icons.checkroom_outlined, color: context.abzioSecondaryText),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            height: 72,
                            width: 72,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: context.abzioMuted),
                            errorWidget: (context, url, error) => Container(
                              color: context.abzioMuted,
                              child: Icon(Icons.broken_image_outlined, color: context.abzioSecondaryText),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty ${item.quantity}${item.size.trim().isNotEmpty ? ' • Size ${item.size}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.abzioSecondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs ${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
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

class _DeliveryDetailsCard extends StatelessWidget {
  const _DeliveryDetailsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final recipient = order.shippingLabel.trim().isEmpty ? 'ABZORA Member' : order.shippingLabel.trim();
    final address = order.shippingAddress.trim().isEmpty
        ? 'Delivery address will appear here once available.'
        : order.shippingAddress.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_outlined, size: 18, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.actor,
    required this.order,
    required this.refundRequestFuture,
    required this.returnRequestFuture,
    required this.canCancel,
    required this.onSupport,
    required this.onCancel,
    required this.onReorder,
  });

  final AppUser actor;
  final OrderModel order;
  final Future<RefundRequest?> refundRequestFuture;
  final Future<ReturnRequest?> returnRequestFuture;
  final bool canCancel;
  final VoidCallback onSupport;
  final VoidCallback onCancel;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return _ActionPanelBody(
      actor: actor,
      order: order,
      refundRequestFuture: refundRequestFuture,
      returnRequestFuture: returnRequestFuture,
      canCancel: canCancel,
      onSupport: onSupport,
      onCancel: onCancel,
      onReorder: onReorder,
    );
  }
}

class _ActionPanelBody extends StatefulWidget {
  const _ActionPanelBody({
    required this.actor,
    required this.order,
    required this.refundRequestFuture,
    required this.returnRequestFuture,
    required this.canCancel,
    required this.onSupport,
    required this.onCancel,
    required this.onReorder,
  });

  final AppUser actor;
  final OrderModel order;
  final Future<RefundRequest?> refundRequestFuture;
  final Future<ReturnRequest?> returnRequestFuture;
  final bool canCancel;
  final VoidCallback onSupport;
  final VoidCallback onCancel;
  final VoidCallback onReorder;

  @override
  State<_ActionPanelBody> createState() => _ActionPanelBodyState();
}

class _ActionPanelBodyState extends State<_ActionPanelBody> {
  final DatabaseService _database = DatabaseService();
  RefundRequest? _refundRequest;
  ReturnRequest? _returnRequest;
  bool _loading = true;
  bool _submittingRefund = false;
  bool _submittingReturn = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void didUpdateWidget(covariant _ActionPanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _loadRequests();
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    final results = await Future.wait<Object?>([
      widget.refundRequestFuture,
      widget.returnRequestFuture,
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _refundRequest = results[0] as RefundRequest?;
      _returnRequest = results[1] as ReturnRequest?;
      _loading = false;
    });
  }

  bool get _canRequestRefund {
    final paymentMethod = widget.order.paymentMethod.trim().toUpperCase();
    final refundState = (_refundRequest?.status ?? widget.order.refundStatus).trim().toLowerCase();
    return paymentMethod != 'COD' &&
        widget.order.isPaymentVerified &&
        !['requested', 'pending', 'approved', 'refunded'].contains(refundState);
  }

  bool get _canRequestReturn {
    final status = widget.order.status.trim().toLowerCase();
    final returnState = (_returnRequest?.status ?? widget.order.returnStatus).trim().toLowerCase();
    final isCustom = widget.order.orderType == 'custom_tailoring' ||
        widget.order.items.any((item) => item.isCustomTailoring);
    return status == 'delivered' &&
        !isCustom &&
        !['requested', 'approved', 'assigned', 'picked', 'completed'].contains(returnState);
  }

  Future<String?> _askReason({
    required BuildContext context,
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
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
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _submitRefund() async {
    final reason = await _askReason(
      context: context,
      title: 'Request Refund',
      hint: 'Tell us why you want a refund',
    );
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    setState(() => _submittingRefund = true);
    try {
      final refund = await _database.createRefundRequest(
        orderId: widget.order.id,
        reason: reason,
        actor: widget.actor,
      );
      if (!mounted) {
        return;
      }
      setState(() => _refundRequest = refund);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request submitted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingRefund = false);
      }
    }
  }

  Future<void> _submitReturn() async {
    final reason = await _askReason(
      context: context,
      title: 'Request Return',
      hint: 'Tell us why you want to return this item',
    );
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    setState(() => _submittingReturn = true);
    try {
      final request = await _database.createReturnRequest(
        orderId: widget.order.id,
        reason: reason,
        actor: widget.actor,
      );
      if (!mounted) {
        return;
      }
      setState(() => _returnRequest = request);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return request submitted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingReturn = false);
      }
    }
  }

  String get _refundLabel {
    if (widget.order.refundStatus.toLowerCase() == 'refunded') {
      return 'Refund status: Refunded';
    }
    if (_refundRequest == null) {
      return 'Online orders can be refunded from here when eligible.';
    }
    final status = _refundRequest!.status.toLowerCase();
    if (status == 'approved') {
      return 'Refund status: Approved';
    }
    if (status == 'rejected') {
      return 'Refund status: Rejected';
    }
    return 'Refund status: Pending review';
  }

  String get _returnLabel {
    final status = (_returnRequest?.status ?? widget.order.returnStatus).trim().toLowerCase();
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onSupport,
                      icon: const Icon(Icons.support_agent_outlined, size: 18),
                      label: const Text('Contact Support'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.canCancel ? widget.onCancel : null,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel Order'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onReorder,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reorder'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_canRequestReturn && !_submittingReturn) ? _submitReturn : null,
                      icon: _submittingReturn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assignment_return_outlined, size: 18),
                      label: const Text('Request Return'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_canRequestRefund && !_submittingRefund) ? _submitRefund : null,
                      icon: _submittingRefund
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Request Refund'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _returnLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _refundLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                      ),
                ),
                if ((_returnRequest?.rejectionReason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Return note: ${_returnRequest!.rejectionReason}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.abzioSecondaryText,
                        ),
                  ),
                ],
                if ((_refundRequest?.rejectionReason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Reason: ${_refundRequest!.rejectionReason}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.abzioSecondaryText,
                        ),
                  ),
                ],
              ],
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
