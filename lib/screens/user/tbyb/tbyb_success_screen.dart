import 'package:flutter/material.dart';
import '../../../models/trial_session.dart';
import '../../../theme.dart';
import 'tbyb_active_trial_screen.dart';

class TbybSuccessScreen extends StatelessWidget {
  const TbybSuccessScreen({
    super.key,
    required this.session,
  });

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Trial Booked Successfully',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your Try Before You Buy session is confirmed.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AbzioTheme.grey500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AbzioTheme.eliteShadow,
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Products Selected', value: '${session.items.length}'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                    _InfoRow(label: 'Delivery Slot', value: session.deliverySlot),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                    _InfoRow(label: 'Trial Duration', value: '${session.trialDurationMinutes} Minutes'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                    _InfoRow(label: '₹99 Trial Booking Fee. Adjusted on purchase.', value: '₹99', isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TbybActiveTrialScreen(session: session),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AbzioTheme.accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Track Trial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Back To Home',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AbzioTheme.grey600),
                ),
              ),
            ],
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
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AbzioTheme.grey500,
              ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
