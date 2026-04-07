import 'package:abzio/models/models.dart';
import 'package:abzio/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Product buildProduct({
    required String id,
    required String storeId,
    String name = 'Running Sneakers',
    double price = 3999,
  }) {
    return Product(
      id: id,
      storeId: storeId,
      name: name,
      description: 'Premium running sneakers',
      price: price,
      images: const ['https://example.com/shoe.jpg'],
      sizes: const ['S', 'M', 'L'],
      stock: 8,
      category: 'MEN',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('revenue flow smoke: cart to paid order preserves core purchase data', () async {
    final cart = CartProvider();
    final product = buildProduct(id: 'p1', storeId: 'store-1');

    final addResult = cart.addToCart(product, 'M');

    expect(addResult, CartAddResult.added);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.size, 'M');
    expect(cart.subtotal, 3999);

    final order = OrderModel(
      id: 'ord-1',
      userId: 'user-1',
      storeId: 'store-1',
      totalAmount: 3999,
      status: 'Delivered',
      paymentMethod: 'RAZORPAY',
      timestamp: DateTime.parse('2026-04-07T10:00:00.000Z'),
      items: [
        OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          price: product.price,
          size: cart.items.single.size,
          imageUrl: product.images.first,
        ),
      ],
      shippingLabel: 'ABZORA Member',
      shippingAddress: '17/7/1, George Town, Chennai',
      trackingId: 'TRK-ABZO-0001',
      deliveryStatus: 'Delivered',
      trackingTimestamps: const {
        'Order Placed': '2026-04-07T10:00:00.000Z',
        'Confirmed': '2026-04-07T10:15:00.000Z',
        'Packed': '2026-04-07T12:00:00.000Z',
        'Out for delivery': '2026-04-08T07:30:00.000Z',
        'Delivered': '2026-04-08T13:45:00.000Z',
      },
      paymentReference: 'pay_123',
      isPaymentVerified: true,
      refundStatus: 'none',
      returnStatus: 'none',
    );

    final restoredOrder = OrderModel.fromMap(order.toMap(), order.id);

    expect(restoredOrder.paymentMethod, 'RAZORPAY');
    expect(restoredOrder.isPaymentVerified, isTrue);
    expect(restoredOrder.items.single.size, 'M');
    expect(restoredOrder.items.single.productId, product.id);
    expect(restoredOrder.trackingId, 'TRK-ABZO-0001');
    expect(restoredOrder.trackingTimestamps['Delivered'], isNotEmpty);
    expect(restoredOrder.refundStatus, 'none');
    expect(restoredOrder.returnStatus, 'none');
  });

  test('revenue flow smoke: refund and return requests preserve linked order state', () {
    const refund = RefundRequest(
      id: 'refund-1',
      orderId: 'ord-1',
      userId: 'user-1',
      reason: 'Wrong size delivered',
      status: 'pending',
      createdAt: '2026-04-08T14:00:00.000Z',
      fraudScore: 8,
      fraudDecision: 'approve',
      fraudReasons: ['Low historical refund risk.'],
    );

    final restoredRefund = RefundRequest.fromMap(refund.toMap(), refund.id);

    expect(restoredRefund.orderId, 'ord-1');
    expect(restoredRefund.userId, 'user-1');
    expect(restoredRefund.status, 'pending');
    expect(restoredRefund.reason, contains('size'));

    const returnRequest = ReturnRequest(
      id: 'return-1',
      orderId: 'ord-1',
      userId: 'user-1',
      address: '17/7/1, George Town, Chennai',
      reason: 'Need a different fit',
      status: 'requested',
      createdAt: '2026-04-08T14:05:00.000Z',
      updatedAt: '2026-04-08T14:05:00.000Z',
    );

    final restoredReturn = ReturnRequest.fromMap(returnRequest.toMap(), returnRequest.id);

    expect(restoredReturn.orderId, 'ord-1');
    expect(restoredReturn.userId, 'user-1');
    expect(restoredReturn.status, 'requested');
    expect(restoredReturn.address, contains('Chennai'));
  });
}
