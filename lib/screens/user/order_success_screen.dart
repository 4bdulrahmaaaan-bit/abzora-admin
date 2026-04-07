import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'order_tracking_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.estimatedDelivery,
    this.paymentMethod,
  });

  final String orderId;
  final DateTime estimatedDelivery;
  final String? paymentMethod;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _navigated = false;
  late final List<CartItem> _orderPreviewItems;

  @override
  void initState() {
    super.initState();
    debugPrint('ABZORA success: initState orderId=${widget.orderId}');
    HapticFeedback.mediumImpact();
    _orderPreviewItems = List<CartItem>.from(context.read<CartProvider>().items);
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

  void _viewDetails() {
    _trackOrder();
  }

  String _paymentLabel() {
    switch ((widget.paymentMethod ?? '').toUpperCase()) {
      case 'UPI':
        return 'UPI';
      case 'CARDS':
      case 'RAZORPAY':
        return 'Card / UPI';
      case 'COD':
        return 'Cash on Delivery';
      default:
        return 'Confirmed';
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ABZORA success: build orderId=${widget.orderId}');
    final theme = Theme.of(context);
    final deliveryLabel = DateFormat('EEE, dd MMM').format(widget.estimatedDelivery);
    final previewItem = _orderPreviewItems.isNotEmpty ? _orderPreviewItems.first : null;
    final extraItems = _orderPreviewItems.length > 1 ? _orderPreviewItems.length - 1 : 0;

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AbzioTheme.accentColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Order Confirmed',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your payment was successful and your order is now confirmed.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                        children: [
                          _InfoRow(label: 'Order ID', value: widget.orderId),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'Delivery', value: deliveryLabel),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'Payment', value: _paymentLabel()),
                        ],
                      ),
                    ),
                    if (previewItem != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.abzioBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: AbzioNetworkImage(
                                  imageUrl: previewItem.product.images.isNotEmpty
                                      ? previewItem.product.images.first
                                      : '',
                                  fallbackLabel: previewItem.product.name,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    previewItem.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AbzioTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    extraItems > 0 ? '+$extraItems more item${extraItems == 1 ? '' : 's'}' : 'Ready to ship',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: context.abzioSecondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _trackOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.route_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Track Order'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _continueShopping,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Continue Shopping'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _viewDetails,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('View Details'),
                          ),
                        ),
                      ],
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
