import 'package:flutter/material.dart';

class CreditNoteScreen extends StatelessWidget {
  const CreditNoteScreen({super.key, required this.creditNoteNumber, required this.amount});

  final String creditNoteNumber;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credit Note')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(creditNoteNumber, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Refund Amount: INR ${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Text('GST reversal and refund details are available in this credit note.'),
          ],
        ),
      ),
    );
  }
}
