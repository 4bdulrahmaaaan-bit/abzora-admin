import '../models/models.dart';
import 'database_service.dart';

class VendorPayoutSummary {
  const VendorPayoutSummary({
    required this.totalEarnings,
    required this.totalCommission,
    required this.netPaidOut,
    required this.pendingOrders,
    required this.processedPayouts,
  });

  final double totalEarnings;
  final double totalCommission;
  final double netPaidOut;
  final int pendingOrders;
  final List<PayoutModel> processedPayouts;
}

class PayoutService {
  PayoutService({
    DatabaseService? databaseService,
  }) : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  Future<VendorPayoutSummary> getVendorSummary({
    required String storeId,
    AppUser? actor,
  }) async {
    final payouts = await _databaseService.getPayouts(actor: actor, storeId: storeId);
    final orders = (await _databaseService.getAllOrders(actor: actor)).where((order) => order.storeId == storeId).toList();
    final readyOrders = orders.where((order) => order.payoutStatus == 'Ready' || order.payoutStatus == 'Pending').toList();
    final totalCommission = orders.fold<double>(0, (sum, order) => sum + order.platformCommission);
    final totalEarnings = orders.fold<double>(0, (sum, order) => sum + order.vendorEarnings);
    final netPaidOut = payouts.fold<double>(0, (sum, payout) => sum + payout.amount);

    return VendorPayoutSummary(
      totalEarnings: totalEarnings,
      totalCommission: totalCommission,
      netPaidOut: netPaidOut,
      pendingOrders: readyOrders.length,
      processedPayouts: payouts,
    );
  }
}
