import 'package:abzio/features/invoices/domain/entities/invoice_entity.dart';
import 'package:abzio/features/invoices/presentation/providers/invoice_providers.dart';
import 'package:abzio/features/invoices/presentation/screens/invoice_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Invoice history renders scaffold', (tester) async {
    final seededNotifier = InvoicePagerNotifier((_) async {
      return [
        InvoiceEntity(
          id: 'inv-1',
          invoiceNumber: 'ABZ-2026-000001',
          orderId: 'ord-1',
          grandTotal: 999,
          status: 'generated',
          paymentStatus: 'paid',
          generatedAt: DateTime(2026, 1, 1),
          cgst: 9,
          sgst: 9,
          igst: 0,
          tax: 18,
        ),
      ];
    });
    await seededNotifier.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerInvoicePagerProvider.overrideWith((ref) => seededNotifier),
        ],
        child: const MaterialApp(
          home: InvoiceHistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Invoice History'), findsOneWidget);
    expect(find.textContaining('ABZ-2026-000001'), findsOneWidget);
  });
}
