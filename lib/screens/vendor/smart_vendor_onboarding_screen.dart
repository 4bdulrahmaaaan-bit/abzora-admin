import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartVendorOnboardingScreen extends StatefulWidget {
  const SmartVendorOnboardingScreen({super.key});

  @override
  State<SmartVendorOnboardingScreen> createState() => _SmartVendorOnboardingScreenState();
}

class _SmartVendorOnboardingScreenState extends State<SmartVendorOnboardingScreen> {
  final PageController _controller = PageController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  final TextEditingController _productStockController = TextEditingController();
  final TextEditingController _productCategoryController = TextEditingController();
  final TextEditingController _productImageController = TextEditingController();
  final TextEditingController _deliveryZoneController = TextEditingController();
  final TextEditingController _deliveryRadiusController = TextEditingController();
  int _step = 0;
  bool _sameDay = false;

  static const List<String> _steps = <String>[
    'Store Info',
    'Bank Details',
    'Add Products',
    'Enable Delivery',
  ];

  IconData _stepIcon(int index) {
    switch (index) {
      case 0:
        return Icons.storefront_outlined;
      case 1:
        return Icons.account_balance_outlined;
      case 2:
        return Icons.inventory_2_outlined;
      case 3:
        return Icons.local_shipping_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  static const List<String> _stepCompletionMessages = <String>[
    'Store info completed',
    'Payout setup verified',
    'First product added',
    'Delivery enabled',
  ];

  Future<void> _next() async {
    if (_step < 3) {
      final completedStep = _step;
      setState(() => _step++);
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stepCompletionMessages[completedStep])),
      );
      return;
    }

    setState(() => _step = 4);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are live on Abianzo')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _storeNameController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _productPriceController.dispose();
    _productStockController.dispose();
    _productCategoryController.dispose();
    _productImageController.dispose();
    _deliveryZoneController.dispose();
    _deliveryRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F4EC);
    const gold = Color(0xFFC9A24A);
    const ink = Color(0xFF1A1A1A);
    final progress = _step >= 4 ? 1.0 : (_step + 1) / _steps.length;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, elevation: 0, surfaceTintColor: bg),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_step < 4) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Setup your store - ${((progress) * 100).round()}% complete',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  valueColor: const AlwaysStoppedAnimation(gold),
                  backgroundColor: const Color(0xFFECE2CF),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_steps.length, (i) {
                  final done = i < _step;
                  final active = i == _step;
                  final chipIcon = done
                      ? const Icon(Icons.check_circle, size: 16, color: Color(0xFF1C8C4E))
                      : Icon(
                          _stepIcon(i),
                          size: 16,
                          color: active ? const Color(0xFF7A5A00) : const Color(0xFF8A8376),
                        );
                  return Chip(
                    avatar: chipIcon,
                    label: Text(
                      _steps[i],
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: active ? const Color(0xFF5E4800) : const Color(0xFF4B463E),
                      ),
                    ),
                    backgroundColor: done
                        ? const Color(0xFFEAF5EC)
                        : active
                            ? const Color(0xFFFFF7E5)
                            : Colors.white,
                  );
                }),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _step >= 4
                  ? _finalState()
                  : PageView(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _stepCard(
                          title: 'Store Info',
                          subtitle: 'Auto-fill where possible',
                          fields: const ['Store Name', 'Address (auto-detect GPS)', 'Category'],
                          controllers: [
                            _storeNameController,
                            _addressController,
                            _categoryController,
                          ],
                          tips: const ['Stores with complete profiles are approved faster.'],
                        ),
                        _stepCard(
                          title: 'Payout Setup',
                          subtitle: 'Secure payouts powered by Razorpay',
                          fields: const ['Bank Account', 'IFSC'],
                          controllers: [
                            _bankAccountController,
                            _ifscController,
                          ],
                          tips: const ['Trusted payout rails increase vendor confidence.'],
                        ),
                        _stepCard(
                          title: 'Add First Product',
                          subtitle: 'Add your first product to go live',
                          fields: const ['Image Upload (camera shortcut)', 'Price', 'Stock', 'Category'],
                          controllers: [
                            _productImageController,
                            _productPriceController,
                            _productStockController,
                            _productCategoryController,
                          ],
                          tips: const ['Stores with 5+ products get 3x more orders.'],
                        ),
                        _deliveryStep(),
                      ],
                    ),
            ),
            if (_step < 4)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_step == 3 ? 'Go Live' : 'Save & Continue'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String title,
    required String subtitle,
    required List<String> fields,
    required List<TextEditingController> controllers,
    required List<String> tips,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DFCF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView(
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(color: const Color(0xFF6D6659))),
          const SizedBox(height: 14),
          for (int idx = 0; idx < fields.length; idx++) ...[
            TextField(
              controller: controllers[idx],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: fields[idx],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final tip in tips) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAD7AA)),
              ),
              child: Text(
                tip,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A5A00),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Step completion auto-saves instantly',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1C8C4E)),
          ),
        ],
      ),
    );
  }

  Widget _deliveryStep() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DFCF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView(
        children: [
          Text('Enable Delivery', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Auto-detect zone and suggest radius', style: GoogleFonts.inter(color: const Color(0xFF6D6659))),
          const SizedBox(height: 14),
          TextField(
            controller: _deliveryZoneController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Delivery Zone',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deliveryRadiusController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Delivery Radius (km)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _sameDay,
            onChanged: (value) => setState(() => _sameDay = value),
            contentPadding: EdgeInsets.zero,
            title: Text('Enable same-day delivery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAD7AA)),
            ),
            child: Text(
              'Enable same-day delivery to increase conversions.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF7A5A00)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step completion auto-saves instantly',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1C8C4E)),
          ),
        ],
      ),
    );
  }

  Widget _finalState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DFCF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFC9A24A),
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            "You're live on Abianzo",
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A84F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}
