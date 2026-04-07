import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tracking_step_widget.dart';
import '../../widgets/tracking_timeline.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final DatabaseService _database = DatabaseService();
  String? _activeUserId;
  Stream<List<OrderModel>>? _ordersStream;
  String _searchQuery = '';
  _OrderFilter _activeFilter = _OrderFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      _activeUserId = null;
      _ordersStream = null;
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
    }

    return AbzioThemeScope.light(
      child: Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: StreamBuilder<List<OrderModel>>(
          stream: _ordersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AbzioLoadingView(
                title: 'Loading your orders',
                subtitle: 'Fetching your latest purchases and delivery updates.',
              );
            }

            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AbzioEmptyCard(
                    title: 'No orders yet',
                    subtitle: 'Once you place an order, it will show up here with delivery updates.',
                    ctaLabel: 'Continue shopping',
                    onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ),
              );
            }
            final filteredOrders = orders.where(_matchesFilter).where(_matchesSearch).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search your orders',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: context.abzioBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: context.abzioBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AbzioTheme.accentColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.abzioBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _activeFilter.label,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${filteredOrders.length} orders',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                if (filteredOrders.isEmpty)
                  AbzioEmptyCard(
                    title: 'No matching orders',
                    subtitle: 'Try a different search or filter to find your purchase faster.',
                    ctaLabel: 'Clear filters',
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _activeFilter = _OrderFilter.all;
                      });
                    },
                  ),
                if (filteredOrders.isNotEmpty)
                  ...filteredOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _OrderListCard(
                        order: order,
                        statusLabel: _statusLabel(order),
                        statusColor: _statusColor(order),
                        statusIcon: _statusIcon(order),
                        statusMessage: _statusMessage(order),
                        onTap: () => _openOrderDetails(order, user),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _matchesSearch(OrderModel order) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final query = _searchQuery.toLowerCase();
    final itemText = order.items.map((item) => '${item.productName} ${item.size}').join(' ').toLowerCase();
    final orderLabel = (order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber).toLowerCase();
    return itemText.contains(query) ||
        orderLabel.contains(query) ||
        _statusLabel(order).toLowerCase().contains(query);
  }

  bool _matchesFilter(OrderModel order) {
    switch (_activeFilter) {
      case _OrderFilter.all:
        return true;
      case _OrderFilter.active:
        final status = _normalizeStatus(order);
        return status != 'delivered' && status != 'cancelled';
      case _OrderFilter.delivered:
        return _normalizeStatus(order) == 'delivered';
      case _OrderFilter.cancelled:
        return _normalizeStatus(order) == 'cancelled';
    }
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

  String _statusLabel(OrderModel order) {
    final status = _normalizeStatus(order);
    switch (status) {
      case 'cancelled':
        return 'Cancelled';
      case 'delivered':
        return 'Delivered';
      case 'out for delivery':
        return 'Out for delivery';
      case 'shipped':
      case 'assigned':
        return 'Shipped';
      case 'packed':
        return 'Packed';
      case 'confirmed':
        return 'Confirmed';
      default:
        return 'Order placed';
    }
  }

  IconData _statusIcon(OrderModel order) {
    switch (_normalizeStatus(order)) {
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'out for delivery':
      case 'shipped':
      case 'assigned':
        return Icons.local_shipping_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Color _statusColor(OrderModel order) {
    switch (_normalizeStatus(order)) {
      case 'cancelled':
        return const Color(0xFFB23A3A);
      case 'delivered':
        return const Color(0xFF1B8E5A);
      case 'out for delivery':
      case 'shipped':
      case 'assigned':
        return const Color(0xFF9E6A00);
      default:
        return const Color(0xFF7B6A2D);
    }
  }

  String _statusMessage(OrderModel order) {
    final label = _statusLabel(order);
    if (label == 'Cancelled') {
      return 'on ${DateFormat('EEE, dd MMM, hh:mm a').format(order.timestamp)} as per your request';
    }
    if (label == 'Delivered') {
      return 'on ${DateFormat('EEE, dd MMM, hh:mm a').format(_estimatedDelivery(order))}';
    }
    if (label == 'Out for delivery') {
      return 'Arriving today • ${DateFormat('hh:mm a').format(_estimatedDelivery(order))}';
    }
    return 'Ordered on ${DateFormat('EEE, dd MMM').format(order.timestamp)}';
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

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<_OrderFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _OrderFilter.values
                .map(
                  (filter) => ListTile(
                    leading: Icon(
                      filter == _activeFilter ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: filter == _activeFilter ? AbzioTheme.accentColor : context.abzioSecondaryText,
                    ),
                    title: Text(filter.label),
                    onTap: () => Navigator.of(context).pop(filter),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _activeFilter = result);
    }
  }

  Future<void> _openOrderDetails(OrderModel order, AppUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _OrderDetailsPage(
          order: order,
          actor: user,
          database: _database,
          canCancel: _canCancel(order),
          onCancel: () => _cancelOrder(order, user),
          onSupport: () => _toast('Support is ready to help with delivery and order updates.'),
          onReorder: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
    );
  }
}

enum _OrderFilter {
  all('All'),
  active('Active'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const _OrderFilter(this.label);

  final String label;
}

class _OrderDetailsPage extends StatelessWidget {
  const _OrderDetailsPage({
    required this.order,
    required this.actor,
    required this.database,
    required this.canCancel,
    required this.onCancel,
    required this.onSupport,
    required this.onReorder,
  });

  final OrderModel order;
  final AppUser actor;
  final DatabaseService database;
  final bool canCancel;
  final VoidCallback onCancel;
  final VoidCallback onSupport;
  final VoidCallback onReorder;

  String get _normalizedStatus {
    final value = (order.deliveryStatus.isNotEmpty ? order.deliveryStatus : order.status).trim().toLowerCase();
    if (value == 'placed' || value == 'pending') {
      return 'order placed';
    }
    return value;
  }

  int get _currentStepIndex {
    switch (_normalizedStatus) {
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

  DateTime get _estimatedDelivery {
    if (_normalizedStatus == 'delivered') {
      final delivered = order.trackingTimestamps['Delivered'];
      final parsed = delivered == null ? null : DateTime.tryParse(delivered);
      if (parsed != null) {
        return parsed;
      }
    }
    return order.timestamp.add(Duration(days: order.orderType == 'custom_tailoring' ? 6 : 3));
  }

  String _timestampLabelFor(String title, int index) {
    final value = order.trackingTimestamps[title];
    if (value != null) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('dd MMM, hh:mm a').format(parsed);
      }
    }
    if (index == 0) {
      return DateFormat('dd MMM, hh:mm a').format(order.timestamp);
    }
    if (index <= _currentStepIndex) {
      final inferred = order.timestamp.add(Duration(hours: index * 6));
      return DateFormat('dd MMM, hh:mm a').format(inferred);
    }
    final expected = _estimatedDelivery.subtract(Duration(hours: (4 - index) * 6));
    return 'Expected ${DateFormat('dd MMM, hh:mm a').format(expected)}';
  }

  List<TrackingStepData> _buildSteps() {
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

    return List.generate(labels.length, (index) {
      final state = index < _currentStepIndex
          ? TrackingStepState.completed
          : index == _currentStepIndex
              ? TrackingStepState.current
              : TrackingStepState.upcoming;
      return TrackingStepData(
        title: labels[index],
        timestampLabel: _timestampLabelFor(labels[index], index),
        icon: icons[index],
        state: state,
      );
    });
  }

  String get _statusTitle {
    switch (_normalizedStatus) {
      case 'cancelled':
        return 'Order Cancelled';
      case 'delivered':
        return 'Item Delivered';
      case 'out for delivery':
        return 'Out for Delivery';
      case 'shipped':
      case 'assigned':
        return 'Shipped';
      case 'packed':
        return 'Packed';
      case 'confirmed':
        return 'Confirmed';
      default:
        return 'Order Placed';
    }
  }

  Color get _statusColor {
    switch (_normalizedStatus) {
      case 'cancelled':
        return const Color(0xFFB23A3A);
      case 'delivered':
        return const Color(0xFF1B8E5A);
      case 'out for delivery':
      case 'shipped':
      case 'assigned':
        return const Color(0xFF9E6A00);
      default:
        return const Color(0xFF7B6A2D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryItem = order.items.isEmpty ? null : order.items.first;
    final recommendedProducts = context
        .watch<ProductProvider>()
        .trendingProducts
        .where((product) => product.id != primaryItem?.productId)
        .take(6)
        .toList();
    final savedAmount = (order.subtotal > 0 ? (order.subtotal - order.totalAmount) : 0).clamp(0, double.infinity);
    final orderLabel = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final contactLabel = (actor.phone ?? '').trim().isEmpty ? 'Not available' : actor.phone!.trim();

    return AbzioThemeScope.light(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: onSupport,
                icon: const Icon(Icons.support_agent_outlined, size: 16),
                label: const Text('Help'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (primaryItem != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.abzioBorder),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: primaryItem.imageUrl.isEmpty
                          ? Container(
                              height: 110,
                              width: 110,
                              color: context.abzioMuted,
                              child: Icon(Icons.checkroom_outlined, color: context.abzioSecondaryText),
                            )
                          : CachedNetworkImage(
                              imageUrl: primaryItem.imageUrl,
                              height: 110,
                              width: 110,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 110,
                                width: 110,
                                color: context.abzioMuted,
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 110,
                                width: 110,
                                color: context.abzioMuted,
                                child: Icon(Icons.broken_image_outlined, color: context.abzioSecondaryText),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      primaryItem.productName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (primaryItem.size.trim().isNotEmpty) 'Size: ${primaryItem.size}',
                        'Quantity: ${primaryItem.quantity}',
                        'Order ID: #$orderLabel',
                      ].join(' • '),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.abzioSecondaryText,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: _statusColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusTitle,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _statusColor,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _normalizedStatus == 'delivered'
                                      ? 'On ${DateFormat('EEE, dd MMM, hh:mm a').format(_estimatedDelivery)}'
                                      : 'Expected by ${DateFormat('EEE, dd MMM').format(_estimatedDelivery)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _statusColor.withValues(alpha: 0.9),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EAD2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          actor.name.trim().isEmpty ? 'A' : actor.name.trim().substring(0, 1).toUpperCase(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF8C6A12),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(context, 'Delivery To'),
                            const SizedBox(height: 2),
                            Text(
                              actor.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: context.abzioSecondaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(context, Icons.call_outlined, 'Contact Details', contactLabel),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    Icons.location_on_outlined,
                    'Delivery Address',
                    order.shippingAddress.trim().isEmpty
                        ? 'Delivery address will appear here once available.'
                        : order.shippingAddress.trim(),
                  ),
                ],
              ),
            ),
            if (savedAmount > 0) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8EE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.savings_outlined, color: Color(0xFF1B8E5A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'On this order you saved a total of Rs ${savedAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B8E5A),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _sectionTitle(context, 'Total Order Price')),
                      Text(
                        'Rs ${order.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(context, Icons.account_balance_outlined, 'Paid by', order.paymentMethod),
                  const SizedBox(height: 12),
                  _detailRow(context, Icons.receipt_long_outlined, 'Order ID', '#$orderLabel'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invoice download will be available here.')),
                        );
                      },
                      child: const Text('Get Invoice'),
                    ),
                  ),
                ],
              ),
            ),
            if (_normalizedStatus == 'delivered') ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Row(
                  children: [
                    const Text('★★★★★', style: TextStyle(color: Color(0xFFE91E63), fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Loved this order? Rate and review it to help other shoppers.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.abzioSecondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Review flow can open from here.')),
                        );
                      },
                      child: const Text('View Review'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'Tracking'),
                  const SizedBox(height: 14),
                  TrackingTimeline(
                    steps: _buildSteps(),
                    progressAnimation: AlwaysStoppedAnimation<double>(_currentStepIndex / 4),
                    pulseAnimation: const AlwaysStoppedAnimation<double>(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'Updates sent to'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniInfo(context, 'Call', contactLabel)),
                      const SizedBox(width: 10),
                      Expanded(child: _miniInfo(context, 'Payment', order.paymentMethod)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'Order details'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _miniInfo(
                          context,
                          'Ordered On',
                          DateFormat('dd MMM yyyy').format(order.timestamp),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _miniInfo(context, 'Order ID', '#$orderLabel')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ProductSummaryCard(order: order),
            if (recommendedProducts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(context, 'Items that go well with this item'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recommendedProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final product = recommendedProducts[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).pushNamed('/product-detail', arguments: product),
                            child: SizedBox(
                              width: 132,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
                                      imageUrl: product.primaryImage,
                                      height: 148,
                                      width: 132,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 148,
                                        width: 132,
                                        color: context.abzioMuted,
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        height: 148,
                                        width: 132,
                                        color: context.abzioMuted,
                                        child: Icon(Icons.broken_image_outlined, color: context.abzioSecondaryText),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    product.brand,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: context.abzioSecondaryText,
                                          height: 1.2,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs ${product.effectivePrice.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ActionPanel(
              actor: actor,
              order: order,
              refundRequestFuture: database.getRefundRequestForOrder(order.id, actor: actor),
              returnRequestFuture: database.getReturnRequestForOrder(order.id, actor: actor),
              canCancel: canCancel,
              onSupport: onSupport,
              onCancel: onCancel,
              onReorder: onReorder,
            ),
            if (order.trackingId.isEmpty) ...[
              const SizedBox(height: 12),
              _TrackingEmptyHint(order: order),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: context.abzioMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: context.abzioSecondaryText),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.abzioSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniInfo(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.abzioMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.abzioSecondaryText,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.abzioBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ignore: unused_element
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

// ignore: unused_element
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

class _OrderListCard extends StatelessWidget {
  const _OrderListCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.statusMessage,
    required this.onTap,
  });

  final OrderModel order;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String statusMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryItem = order.items.isEmpty ? null : order.items.first;
    final extraCount = order.items.length > 1 ? order.items.length - 1 : 0;
    final orderLabel = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.abzioBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(statusIcon, size: 16, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.abzioSecondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.abzioBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: primaryItem == null || primaryItem.imageUrl.isEmpty
                        ? Container(
                            height: 72,
                            width: 72,
                            color: context.abzioMuted,
                            child: Icon(Icons.checkroom_outlined, color: context.abzioSecondaryText),
                          )
                        : CachedNetworkImage(
                            imageUrl: primaryItem.imageUrl,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          primaryItem?.productName ?? 'Order $orderLabel',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (primaryItem != null && primaryItem.size.trim().isNotEmpty) 'Size: ${primaryItem.size}',
                            if (primaryItem != null) 'Qty: ${primaryItem.quantity}',
                            if (extraCount > 0) '+$extraCount more item${extraCount > 1 ? 's' : ''}',
                          ].join('  •  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.abzioSecondaryText,
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rs ${order.totalAmount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: context.abzioSecondaryText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
