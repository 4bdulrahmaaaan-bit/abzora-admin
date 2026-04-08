import 'package:abzio/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('financial breakdown survives order serialization', () {
    final order = OrderModel(
      id: 'ord-fin-1',
      userId: 'u1',
      storeId: 's1',
      totalAmount: 4999,
      status: 'Delivered',
      paymentMethod: 'RAZORPAY',
      timestamp: DateTime.parse('2026-04-08T10:30:00.000Z'),
      items: [
        OrderItem(
          productId: 'p1',
          productName: 'Runner Pro',
          quantity: 1,
          price: 4499,
          size: 'M',
        ),
      ],
      subtotal: 4499,
      taxAmount: 320,
      extraCharges: 180,
      platformCommission: 540,
      vendorEarnings: 3959,
      isPaymentVerified: true,
      payoutStatus: 'pending',
      refundStatus: 'none',
      returnStatus: 'none',
    );

    final restored = OrderModel.fromMap(order.toMap(), order.id);
    expect(restored.subtotal, 4499);
    expect(restored.taxAmount, 320);
    expect(restored.extraCharges, 180);
    expect(restored.platformCommission, 540);
    expect(restored.vendorEarnings, 3959);
    expect(restored.totalAmount, 4999);
    expect(restored.isPaymentVerified, isTrue);
  });

  test('withdrawal statuses parse for payout lifecycle', () {
    const statuses = ['pending', 'approved', 'processing', 'completed', 'failed', 'rejected'];
    for (final status in statuses) {
      final summary = WithdrawalRequestSummary.fromMap({
        'id': 'wd-$status',
        'walletType': 'vendor',
        'status': status,
        'amount': 1200,
        'requestedAt': '2026-04-08T12:00:00.000Z',
      });
      expect(summary.status, status);
      expect(summary.amount, 1200);
      expect(summary.walletType, 'vendor');
    }
  });

  test('admin finance summary keeps risk and pending payout totals', () {
    const summary = AdminFinanceSummary(
      totalCommission: 14000,
      totalRevenue: 98000,
      payoutsDone: 42000,
      vendorSettlementsDone: 28000,
      riderSettlementsDone: 14000,
      failedSettlements: 0,
      vendorPending: 7300,
      riderPending: 2100,
      pendingWithdrawalAmount: 3400,
      flaggedUsers: 3,
    );

    expect(summary.totalRevenue, greaterThan(summary.totalCommission));
    expect(summary.vendorPending + summary.riderPending, 9400);
    expect(summary.pendingWithdrawalAmount, 3400);
    expect(summary.flaggedUsers, 3);
  });
}
