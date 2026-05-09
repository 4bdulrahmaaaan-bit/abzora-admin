import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../core/widgets/rider_glass_card.dart';

class RiderOrdersScreen extends StatelessWidget {
  const RiderOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final db = DatabaseService();
    return StreamBuilder<List<OrderModel>>(
      stream: db.getRiderOrders(user),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snap.data!;
        if (orders.isEmpty) {
          return const Center(child: Text('No assigned deliveries yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final o = orders[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RiderGlassCard(
                child: ListTile(
                  title: Text('Order ${o.id}'),
                  subtitle: Text('${o.status} • ${o.shippingAddress}'),
                  trailing: Text('Rs ${o.totalAmount.toStringAsFixed(0)}'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
