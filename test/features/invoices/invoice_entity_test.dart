import 'package:abzio/features/invoices/domain/entities/invoice_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InvoiceEntity keeps enterprise fields', () {
    final entity = InvoiceEntity(
      id: '1',
      invoiceNumber: 'ABZ-2026-000001',
      orderId: 'o1',
      grandTotal: 100,
      status: 'generated',
      paymentStatus: 'paid',
      generatedAt: DateTime(2026, 1, 1),
      cgst: 9,
      sgst: 9,
      igst: 0,
      tax: 18,
      versionLabel: 'v2',
      verificationHash: 'abc123',
      creditNoteNumber: 'CN-2026-000001',
      refundStatus: 'none',
    );

    expect(entity.versionLabel, 'v2');
    expect(entity.verificationHash, isNotEmpty);
    expect(entity.creditNoteNumber, startsWith('CN-'));
  });
}
