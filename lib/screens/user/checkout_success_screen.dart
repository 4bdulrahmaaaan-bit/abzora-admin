import 'package:flutter/material.dart';

import 'order_success_screen.dart';

class CheckoutSuccessScreen extends StatelessWidget {
  const CheckoutSuccessScreen({
    super.key,
    this.orderId = 'ORDER',
    this.estimatedDelivery,
  });

  final String orderId;
  final DateTime? estimatedDelivery;

  @override
  Widget build(BuildContext context) {
    return OrderSuccessScreen(
      orderId: orderId,
      estimatedDelivery: estimatedDelivery ?? DateTime.now().add(const Duration(days: 3)),
    );
  }
}
