import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartVendorOnboardingScreen extends StatefulWidget {
  const SmartVendorOnboardingScreen({super.key});

  @override
  State<SmartVendorOnboardingScreen> createState() => _SmartVendorOnboardingScreenState();
}

class _SmartVendorOnboardingScreenState extends State<SmartVendorOnboardingScreen> {
  final PageController _controller = PageController();
  int _step = 0;
  bool _sameDay = false;

  static const List<String> _steps = <String>[
    'Store Info',
    'Bank Details',
    'Add Products',
    'Enable Delivery',
  ];

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
      const SnackBar(content: Text('You are live on ABZORA')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F3E9);
    const gold = Color(0xFFD0A84F);
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
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
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
                  return Chip(
                    label: Text('${done ? '?' : active ? '?' : '?'} ${_steps[i]}'),
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
                          tips: const ['Stores with complete profiles are approved faster.'],
                        ),
                        _stepCard(
                          title: 'Payout Setup',
                          subtitle: 'Secure payouts powered by Razorpay',
                          fields: const ['Bank Account', 'IFSC'],
                          tips: const ['Trusted payout rails increase vendor confidence.'],
                        ),
                        _stepCard(
                          title: 'Add First Product',
                          subtitle: 'Add your first product to go live',
                          fields: const ['Image Upload (camera shortcut)', 'Price', 'Stock', 'Category'],
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
    required List<String> tips,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DFCF)),
      ),
      child: ListView(
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(color: const Color(0xFF6D6659))),
          const SizedBox(height: 14),
          for (final field in fields) ...[
            TextField(
              decoration: InputDecoration(
                labelText: field,
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
            '? Step completed will auto-save instantly',
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DFCF)),
      ),
      child: ListView(
        children: [
          Text('Enable Delivery', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Auto-detect zone and suggest radius', style: GoogleFonts.inter(color: const Color(0xFF6D6659))),
          const SizedBox(height: 14),
          TextField(
            decoration: InputDecoration(
              labelText: 'Delivery Zone',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
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
            '? Step completed will auto-save instantly',
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
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("?? You're live on ABZORA", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800)),
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
