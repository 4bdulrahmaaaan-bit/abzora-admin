import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../widgets/success_animation_widget.dart';
import '../../widgets/tap_scale.dart';
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
  Timer? _redirectTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _redirectTimer = Timer(const Duration(seconds: 7), _trackOrder);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _trackOrder() {
    if (!mounted || _navigated) {
      return;
    }
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
    );
  }

  void _continueShopping() {
    _redirectTimer?.cancel();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _deliveryHeadline() {
    final today = DateTime.now();
    final onlyDate = DateTime(widget.estimatedDelivery.year, widget.estimatedDelivery.month, widget.estimatedDelivery.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final difference = onlyDate.difference(todayDate).inDays;
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
    final theme = Theme.of(context);
    final deliveryLabel = DateFormat('dd MMM yyyy').format(widget.estimatedDelivery);

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFFFAEF),
                      AbzioTheme.accentColor.withValues(alpha: 0.10),
                      const Color(0xFFFFFCF8),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AbzioTheme.accentColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.46),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 560),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 26 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 28,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const SuccessAnimationWidget(),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Payment secure • Order locked in',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AbzioTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Order Confirmed',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 32),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your order has been placed successfully and is now moving into premium fulfillment.',
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
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFFFF8EA),
                                        AbzioTheme.accentColor.withValues(alpha: 0.10),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AbzioTheme.accentColor.withValues(alpha: 0.16),
                                    ),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: context.abzioSecondaryText,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Auto-opening order tracking in a few seconds',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: context.abzioSecondaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: context.abzioBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                TapScale(
                                  onTap: _trackOrder,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFE1C768), AbzioTheme.accentColor],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _trackOrder,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        minimumSize: const Size.fromHeight(56),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: const Text(
                                        'Track Order',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
