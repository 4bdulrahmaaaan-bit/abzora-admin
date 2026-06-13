import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/trial_session.dart';
import '../../../theme.dart';
import '../../../providers/trial_home_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/payment_service.dart';
import '../home_screen.dart';

class TbybFinalBillScreen extends StatefulWidget {
  const TbybFinalBillScreen({
    super.key,
    required this.session,
    required this.keptItems,
    required this.returnedItems,
  });

  final TrialSession session;
  final List<String> keptItems;
  final List<String> returnedItems;

  @override
  State<TbybFinalBillScreen> createState() => _TbybFinalBillScreenState();
}

class _TbybFinalBillScreenState extends State<TbybFinalBillScreen> {
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;
  bool _isSuccess = false;

  double get _subtotal {
    double total = 0;
    for (final id in widget.keptItems) {
      final item = widget.session.items.firstWhere((i) => i.productId == id);
      total += item.price;
    }
    return total;
  }

  double get _finalAmount {
    // If they kept something, the subtotal is >= 0. Deduct ₹99 fee if kept anything.
    if (_subtotal > 0) {
      return (_subtotal - 99) > 0 ? (_subtotal - 99) : 0;
    }
    return 0; // If they kept nothing, final amount is 0, fee is retained.
  }

  Future<void> _processPayment() async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to complete payment.')),
      );
      return;
    }

    final amountToPay = _finalAmount;
    String? paymentId;
    String? orderId;

    setState(() => _isProcessing = true);

    if (amountToPay > 0) {
      if (_selectedPaymentMethod == 'COD') {
        paymentId = 'COD_PENDING';
        orderId = 'COD_PENDING';
      } else {
        final paymentResult = await PaymentService().processCheckout(
          context: context,
          userId: currentUser.id,
          name: currentUser.name.trim().isEmpty
              ? 'Abianzo Member'
              : currentUser.name.trim(),
          amount: amountToPay,
          email: currentUser.email.isEmpty
              ? 'guest@abianzo.app'
              : currentUser.email,
          contact: currentUser.phone ?? '9999999999',
          description: 'Try Before You Buy Final Bill',
        );

        if (!mounted) return;

        if (!paymentResult.success) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment cancelled or failed.')),
          );
          return;
        }
        paymentId = paymentResult.paymentId;
        orderId = paymentResult.orderId;
      }
    }

    try {
      final provider = context.read<TrialHomeProvider>();
      await provider.completeTrial(
        trialId: widget.session.id,
        keptItems: widget.keptItems,
        returnedItems: widget.returnedItems,
        paymentMethod: _selectedPaymentMethod == 'COD' ? 'cod' : 'online',
        finalPaymentId: paymentId,
        finalOrderId: orderId,
        finalAmount: amountToPay,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete order: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Final Order Summary'),
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
                const Text(
                  'Products Kept',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
                      if (widget.keptItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No items kept. The rider will take all items back.',
                          ),
                        ),
                      ...widget.keptItems.map((id) {
                        final item = widget.session.items.firstWhere(
                          (i) => i.productId == id,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text('₹${item.price.toStringAsFixed(0)}'),
                            ],
                          ),
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text('₹${_subtotal.toStringAsFixed(0)}'),
                        ],
                      ),
                      if (_subtotal > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '₹99 Trial Booking Fee. Adjusted on purchase.',
                              style: TextStyle(color: Colors.green),
                            ),
                            const Text(
                              '-₹99',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Final Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₹${_finalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_subtotal > 0) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'Payment Methods',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AbzioTheme.eliteShadow,
                    ),
                    child: Column(
                      children: [
                        _PaymentMethodTile(
                          title: 'UPI',
                          icon: Icons.qr_code_scanner,
                          selected: _selectedPaymentMethod == 'UPI',
                          onTap: () =>
                              setState(() => _selectedPaymentMethod = 'UPI'),
                        ),
                        const Divider(height: 1),
                        _PaymentMethodTile(
                          title: 'Credit Card',
                          icon: Icons.credit_card,
                          selected: _selectedPaymentMethod == 'Credit Card',
                          onTap: () => setState(
                            () => _selectedPaymentMethod = 'Credit Card',
                          ),
                        ),
                        const Divider(height: 1),
                        _PaymentMethodTile(
                          title: 'Debit Card',
                          icon: Icons.credit_card,
                          selected: _selectedPaymentMethod == 'Debit Card',
                          onTap: () => setState(
                            () => _selectedPaymentMethod = 'Debit Card',
                          ),
                        ),
                        const Divider(height: 1),
                        _PaymentMethodTile(
                          title: 'Wallet',
                          icon: Icons.account_balance_wallet,
                          selected: _selectedPaymentMethod == 'Wallet',
                          onTap: () =>
                              setState(() => _selectedPaymentMethod = 'Wallet'),
                        ),
                        const Divider(height: 1),
                        _PaymentMethodTile(
                          title: 'Cash On Delivery',
                          icon: Icons.money,
                          selected: _selectedPaymentMethod == 'COD',
                          onTap: () =>
                              setState(() => _selectedPaymentMethod = 'COD'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
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
              onPressed: _isProcessing ? null : _processPayment,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AbzioTheme.accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _subtotal > 0
                          ? 'Pay ₹${_finalAmount.toStringAsFixed(0)}'
                          : 'Confirm Return',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                'Order Confirmed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for shopping with ABZORA.\nThe products you selected have been confirmed.\nReturned products have been handed back to the rider.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AbzioTheme.grey600,
                  height: 1.5,
                ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Purchased'),
                        Text(
                          '${widget.keptItems.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Returned'),
                        Text(
                          '${widget.returnedItems.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Paid'),
                        Text(
                          '₹${_finalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AbzioTheme.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Continue Shopping',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Mock view order
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'View Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AbzioTheme.grey600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AbzioTheme.grey600),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AbzioTheme.accentColor : AbzioTheme.grey400,
            ),
          ],
        ),
      ),
    );
  }
}
