import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../theme.dart';
import '../../../providers/trial_home_provider.dart';
import '../../../providers/trial_cart_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/payment_service.dart';
import 'tbyb_success_screen.dart';

class TbybBookingSummaryScreen extends StatefulWidget {
  const TbybBookingSummaryScreen({
    super.key,
    required this.selectedItems,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.trialDurationMinutes,
    required this.addressLabel,
  });

  final List<Product> selectedItems;
  final String deliveryDate;
  final String deliveryTime;
  final int trialDurationMinutes;
  final String addressLabel;

  @override
  State<TbybBookingSummaryScreen> createState() => _TbybBookingSummaryScreenState();
}

class _TbybBookingSummaryScreenState extends State<TbybBookingSummaryScreen> {
  bool _isProcessing = false;

  Future<void> _processBooking() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to book a trial.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final paymentResult = await PaymentService().processCheckout(
        context: context,
        userId: currentUser.id,
        name: currentUser.name.trim().isEmpty ? 'Abianzo Member' : currentUser.name.trim(),
        amount: 99.0, // Booking Fee
        email: currentUser.email.isEmpty ? 'guest@abianzo.app' : currentUser.email,
        contact: currentUser.phone ?? '9999999999',
        description: 'Try Before You Buy Booking Fee',
      );

      if (!mounted) return;

      if (!paymentResult.success) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled or failed.')),
        );
        return;
      }

      final provider = context.read<TrialHomeProvider>();

      final session = await provider.bookTrial(
        items: widget.selectedItems,
        addressLabel: widget.addressLabel,
        deliverySlot: '${widget.deliveryDate} | ${widget.deliveryTime}',
        trialDurationMinutes: widget.trialDurationMinutes,
        bookingPaymentId: paymentResult.paymentId,
        bookingOrderId: paymentResult.orderId,
      );

      if (!mounted) return;

      context.read<TrialCartProvider>().clear();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => TbybSuccessScreen(
            session: session,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to book trial: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Confirm Your Trial'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader(title: 'Selected Products (${widget.selectedItems.length})'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Column(
                    children: widget.selectedItems.map((product) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 50,
                                height: 60,
                                color: AbzioTheme.grey200,
                                child: product.images.isNotEmpty
                                    ? Image.network(product.images.first, fit: BoxFit.cover)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  Text('Size: M', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AbzioTheme.grey500)),
                                ],
                              ),
                            ),
                            Text(
                              '₹${product.effectivePrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Delivery Details'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Column(
                    children: [
                      _DetailRow(icon: Icons.calendar_today, title: 'Date', value: widget.deliveryDate),
                      const Divider(height: 24),
                      _DetailRow(icon: Icons.access_time, title: 'Time Window', value: widget.deliveryTime),
                      const Divider(height: 24),
                      _DetailRow(icon: Icons.timer_outlined, title: 'Trial Duration', value: '${widget.trialDurationMinutes} Minutes'),
                      const Divider(height: 24),
                      _DetailRow(icon: Icons.location_on_outlined, title: 'Address', value: widget.addressLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Pricing Summary'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Try At Home Fee'),
                          Text('₹99'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Adjusted On Purchase', style: TextStyle(color: Colors.green.shade700)),
                          Text('-₹99', style: TextStyle(color: Colors.green.shade700)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount Payable', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('₹99', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: AbzioTheme.accentColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pay ₹99 now. If you purchase any item, ₹99 will be deducted from your final bill.',
                          style: TextStyle(color: AbzioTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: _isProcessing ? null : _processBooking,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AbzioTheme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing 
                  ? const SizedBox(
                      width: 24, height: 24, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text(
                      'Pay ₹99 & Confirm Booking',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AbzioTheme.grey500, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AbzioTheme.grey500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
