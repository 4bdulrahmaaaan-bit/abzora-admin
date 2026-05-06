import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';

class VendorOrdersTab extends StatelessWidget {
  const VendorOrdersTab({
    super.key,
    required this.orders,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onConfirm,
    required this.onPacked,
    required this.formatCurrency,
    this.onReadyForPickup,
    this.onReject,
  });

  final List<OrderModel> orders;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function(OrderModel order) onConfirm;
  final Future<void> Function(OrderModel order) onPacked;
  final Future<void> Function(OrderModel order)? onReadyForPickup;
  final Future<void> Function(OrderModel order)? onReject;
  final String Function(double amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 32, color: Color(0xFF8C8C8C)),
            const SizedBox(height: 10),
            Text(
              emptyTitle,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF7B7B7B), height: 1.45),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Column(
        key: ValueKey(orders.map((order) => order.id).join(',')),
        children: orders
            .map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VendorOrderPriorityCard(
                  order: order,
                  onConfirm: () => onConfirm(order),
                  onPacked: () => onPacked(order),
                  onReadyForPickup: onReadyForPickup == null
                      ? null
                      : () => onReadyForPickup!(order),
                  onReject: onReject == null ? null : () => onReject!(order),
                  formatCurrency: formatCurrency,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VendorOrderPriorityCard extends StatefulWidget {
  const _VendorOrderPriorityCard({
    required this.order,
    required this.onConfirm,
    required this.onPacked,
    required this.formatCurrency,
    this.onReadyForPickup,
    this.onReject,
  });

  final OrderModel order;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onPacked;
  final Future<void> Function()? onReadyForPickup;
  final Future<void> Function()? onReject;
  final String Function(double amount) formatCurrency;

  @override
  State<_VendorOrderPriorityCard> createState() => _VendorOrderPriorityCardState();
}

class _VendorOrderPriorityCardState extends State<_VendorOrderPriorityCard> {
  late final ValueNotifier<int> _secondsLeft;
  bool _isActionInFlight = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = ValueNotifier<int>(_remainingSeconds(widget.order));
    if (_secondsLeft.value > 0) {
      _tick();
    }
  }

  int _remainingSeconds(OrderModel order) {
    if (order.status != 'Placed') {
      return 0;
    }
    final deadline = order.timestamp.add(const Duration(seconds: 20));
    final remaining = deadline.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _tick() async {
    while (mounted && _secondsLeft.value > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _secondsLeft.value = _secondsLeft.value - 1;
    }
  }

  @override
  void dispose() {
    _secondsLeft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final invoice = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final shortId = invoice.length <= 12 ? invoice : invoice.substring(invoice.length - 12);

    final normalizedStatus = order.status;
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final customerName = order.shippingLabel.isEmpty ? 'Customer' : order.shippingLabel;

    String actionLabel = '';
    Future<void> Function()? onAction;

    if (normalizedStatus == 'Placed') {
      actionLabel = 'Accept Order';
      onAction = widget.onConfirm;
    } else if (normalizedStatus == 'Confirmed') {
      actionLabel = 'Mark as Packed';
      onAction = widget.onPacked;
    } else if (normalizedStatus == 'Packed') {
      actionLabel = 'Ready for Pickup';
      onAction = widget.onReadyForPickup;
    }

    final canSwipeAccept = normalizedStatus == 'Placed';
    final canSwipeReject = normalizedStatus == 'Placed' && widget.onReject != null;

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: normalizedStatus == 'Placed' ? const Color(0xFFFFFCF6) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                  '#$shortId',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF191919),
                  ),
                ),
              ),
              _StatusBadge(label: normalizedStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$itemCount item${itemCount == 1 ? '' : 's'} • $customerName',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF65615C),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.formatCurrency(order.totalAmount),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'You earn ${widget.formatCurrency(order.vendorEarnings)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E2A26),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Commission ${widget.formatCurrency(order.platformCommission)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF8A847E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (normalizedStatus == 'Placed') ...[
            const SizedBox(height: 10),
            ValueListenableBuilder<int>(
              valueListenable: _secondsLeft,
              builder: (context, value, child) {
                final urgencyColor = value <= 7
                    ? const Color(0xFFB34434)
                    : const Color(0xFF9B6A2D);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Accept within ${value}s',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: urgencyColor,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          if (actionLabel.isNotEmpty && onAction != null)
            SizedBox(
              width: double.infinity,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: _isActionInFlight ? 0.985 : 1,
                child: FilledButton(
                  onPressed: _isActionInFlight
                      ? null
                      : () async {
                          setState(() => _isActionInFlight = true);
                          try {
                            await onAction!();
                          } finally {
                            if (mounted) {
                              setState(() => _isActionInFlight = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFFC8A96A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isActionInFlight ? 'Processing...' : actionLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          else
            Text(
              'Waiting for rider pickup',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF8A847E),
              ),
            ),
        ],
      ),
    );

    if (!canSwipeAccept && !canSwipeReject) {
      return card;
    }

    return Dismissible(
      key: ValueKey('order-${order.id}'),
      direction: canSwipeReject
          ? DismissDirection.horizontal
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && canSwipeAccept) {
          await widget.onConfirm();
          return false;
        }
        if (direction == DismissDirection.endToStart && canSwipeReject) {
          await widget.onReject?.call();
          return false;
        }
        return false;
      },
      background: const _SwipeBackground(
        color: Color(0xFF2FA36B),
        alignment: Alignment.centerLeft,
        icon: Icons.check_rounded,
        label: 'Accept',
      ),
      secondaryBackground: const _SwipeBackground(
        color: Color(0xFFB34434),
        alignment: Alignment.centerRight,
        icon: Icons.close_rounded,
        label: 'Reject',
      ),
      child: card,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final map = <String, Color>{
      'Placed': const Color(0xFFF0B45D),
      'Confirmed': const Color(0xFF5A78C9),
      'Packed': const Color(0xFF7A68C7),
      'Ready for pickup': const Color(0xFF2FA36B),
      'Delivered': const Color(0xFF2FA36B),
    };
    final color = map[label] ?? const Color(0xFF8D8B88);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
