import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({
    super.key,
    required this.actor,
    required this.store,
  });

  final AppUser actor;
  final Store store;

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  static const int _pageSize = 8;

  final _db = DatabaseService();
  final _searchController = TextEditingController();
  String _statusFilter = 'All';
  int _page = 0;

  List<OrderModel> _filtered(List<OrderModel> orders) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = orders.where((order) {
      final invoice = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
      final matchesStatus = _statusFilter == 'All' || order.status == _statusFilter;
      final matchesQuery = query.isEmpty ||
          invoice.toLowerCase().contains(query) ||
          order.shippingAddress.toLowerCase().contains(query) ||
          order.items.any((item) => item.productName.toLowerCase().contains(query));
      return matchesStatus && matchesQuery;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _page = 0);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.store.name.toUpperCase()} ORDERS'),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _db.getVendorOrders(widget.store.id, actor: widget.actor),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AbzioLoadingView(
              title: 'Loading store orders',
              subtitle: 'Preparing live order flow and fulfillment actions.',
            );
          }

          final orders = snapshot.data ?? const <OrderModel>[];
          final filtered = _filtered(orders);
          final pending = orders.where((order) => order.status == 'Placed' || order.status == 'Confirmed').length;
          final revenue = orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
          final pageCount = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
          final safePage = _page >= pageCount ? pageCount - 1 : _page;
          final start = safePage * _pageSize;
          final end = (start + _pageSize).clamp(0, filtered.length);
          final visible = start >= filtered.length ? const <OrderModel>[] : filtered.sublist(start, end);

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'No orders yet',
                  subtitle: 'Customer purchases will appear here as soon as they are placed.',
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _OrderMetric(label: 'Total orders', value: '${orders.length}'),
                  _OrderMetric(label: 'Pending', value: '$pending'),
                  _OrderMetric(label: 'Revenue', value: '₹${revenue.toInt()}'),
                  _OrderMetric(label: 'Visible', value: '${filtered.length}'),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order filters',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by invoice, address, or item name',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: _statusFilter,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const ['All', 'Placed', 'Confirmed', 'Packed', 'Out for delivery', 'Delivered', 'Cancelled']
                              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setState(() {
                            _statusFilter = value ?? 'All';
                            _page = 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const AbzioEmptyCard(
                  title: 'No matching orders',
                  subtitle: 'Try a different status or search term to find the orders you need.',
                )
              else ...[
                ...visible.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OrderManagementCard(
                      order: order,
                      actor: widget.actor,
                      db: _db,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _OrderPager(
                  currentPage: safePage,
                  pageCount: pageCount,
                  totalItems: filtered.length,
                  pageSize: _pageSize,
                  onPrevious: safePage > 0 ? () => setState(() => _page = safePage - 1) : null,
                  onNext: safePage + 1 < pageCount ? () => setState(() => _page = safePage + 1) : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OrderManagementCard extends StatelessWidget {
  const _OrderManagementCard({
    required this.order,
    required this.actor,
    required this.db,
  });

  final OrderModel order;
  final AppUser actor;
  final DatabaseService db;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '₹${order.totalAmount.toInt()}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.items.length} item(s) • ${order.shippingAddress}',
            style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.4),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: order.status),
              _StatusChip(label: order.paymentMethod),
              _StatusChip(label: order.payoutStatus),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: order.status,
            decoration: const InputDecoration(labelText: 'Update status'),
            items: const [
              DropdownMenuItem(value: 'Placed', child: Text('Placed')),
              DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'Packed', child: Text('Packed')),
              DropdownMenuItem(value: 'Out for delivery', child: Text('Out for delivery')),
              DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
            ],
            onChanged: (value) async {
              if (value == null || value == order.status) {
                return;
              }
              await db.updateOrderStatus(order.id, value, actor: actor);
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Order updated to $value.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OrderPager extends StatelessWidget {
  const _OrderPager({
    required this.currentPage,
    required this.pageCount,
    required this.totalItems,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start-$end of $totalItems',
            style: GoogleFonts.inter(color: Theme.of(context).hintColor),
          ),
        ),
        TextButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Previous'),
        ),
        Text(
          '${currentPage + 1} / $pageCount',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        TextButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Next'),
        ),
      ],
    );
  }
}
