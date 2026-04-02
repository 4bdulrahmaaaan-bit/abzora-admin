import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../theme.dart';
import 'order_tracking_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.estimatedDelivery,
  });

  final String orderId;
  final DateTime estimatedDelivery;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('ABZORA success: initState orderId=${widget.orderId}');
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      debugPrint('ABZORA success: clearing cart after navigation');
      context.read<CartProvider>().clear(trackActivity: false);
    });
  }

  void _trackOrder() {
    if (!mounted || _navigated) {
      return;
    }
    debugPrint('ABZORA success: track order tapped');
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
    );
  }

  void _continueShopping() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _deliveryHeadline() {
    final today = DateTime.now();
    final deliveryDate = DateTime(
      widget.estimatedDelivery.year,
      widget.estimatedDelivery.month,
      widget.estimatedDelivery.day,
    );
    final todayDate = DateTime(today.year, today.month, today.day);
    final difference = deliveryDate.difference(todayDate).inDays;
    if (difference <= 0) {
      return 'Arriving today';
    }
    if (difference == 1) {
      return 'Arriving by tomorrow';
    }
    return 'Arriving by ${DateFormat('EEE, d MMM').format(widget.estimatedDelivery)}';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ABZORA success: build orderId=${widget.orderId}');
    final theme = Theme.of(context);
    final deliveryLabel = DateFormat('dd MMM yyyy').format(widget.estimatedDelivery);

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AbzioTheme.accentColor,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Order Confirmed',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your order has been placed successfully.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.abzioBorder),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(label: 'Order ID', value: widget.orderId),
                          const SizedBox(height: 14),
                          _InfoRow(label: 'Estimated delivery', value: deliveryLabel),
                          const SizedBox(height: 14),
                          _InfoRow(label: 'Status', value: _deliveryHeadline()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Track your order anytime using the button below.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _trackOrder,
                        child: const Text('Track Order'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _continueShopping,
                        child: const Text('Continue Shopping'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AbzioTheme.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
