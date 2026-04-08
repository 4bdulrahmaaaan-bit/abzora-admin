import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../theme.dart';

class VendorOrdersTab extends StatelessWidget {
  const VendorOrdersTab({
    super.key,
    required this.orders,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onConfirm,
    required this.onPacked,
    required this.formatCurrency,
  });

  final List<OrderModel> orders;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function(OrderModel order) onConfirm;
  final Future<void> Function(OrderModel order) onPacked;
  final String Function(double amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AbzioTheme.grey100),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 34,
              color: Color(0xFF8C8C8C),
            ),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: GoogleFonts.inter(
                color: const Color(0xFF7B7B7B),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
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
                  formatCurrency: formatCurrency,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VendorOrderPriorityCard extends StatelessWidget {
  const _VendorOrderPriorityCard({
    required this.order,
    required this.onConfirm,
    required this.onPacked,
    required this.formatCurrency,
  });

  final OrderModel order;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onPacked;
  final String Function(double amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final invoice = order.invoiceNumber.isEmpty
        ? order.id
        : order.invoiceNumber;
    final canConfirm = order.status == 'Placed';
    final canPack = order.status == 'Confirmed';
    final itemPreview = order.items
        .take(2)
        .map((item) => item.productName)
        .join(', ');
    final paymentStatus = order.isPaymentVerified ? 'Paid' : 'Pending';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AbzioTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
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
                  invoice,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF161616),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A5A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${order.shippingLabel.isEmpty ? 'Customer' : order.shippingLabel}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.items.length} item(s)${itemPreview.isEmpty ? '' : ' • $itemPreview'}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF666666),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _FinanceChip(
                label: 'Total',
                value: formatCurrency(order.totalAmount),
              ),
              _FinanceChip(
                label: 'Commission',
                value: formatCurrency(order.platformCommission),
              ),
              _FinanceChip(
                label: 'Your earning',
                value: formatCurrency(order.vendorEarnings),
              ),
              _FinanceChip(label: 'Payment', value: paymentStatus),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canConfirm
                      ? () async {
                          await onConfirm();
                        }
                      : null,
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE4C868), Color(0xFFD4AF37)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: canPack
                        ? () async {
                            await onPacked();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Mark Packed',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceChip extends StatelessWidget {
  const _FinanceChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF6A6A6A),
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF212121),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
