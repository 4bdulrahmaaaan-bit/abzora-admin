import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountStoreControlScreen extends StatelessWidget {
  const AccountStoreControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F3E9);
    const gold = Color(0xFFD0A84F);
    const text = Color(0xFF1D1B17);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: bg,
        title: Text(
          'Account',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: text),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh_rounded, color: text),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: text),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Louis Vuitton',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _badge(
                      'Active',
                      const Color(0xFF1C8C4E),
                      const Color(0xFFE7F6ED),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _kv('Address', 'Mumbai, Maharashtra'),
                _kv('Commission', '12%'),
                _kv(
                  'Payout Status',
                  'Pending',
                  valueColor: const Color(0xFFC03C2E),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _actionButton('Edit Store', gold)),
                    const SizedBox(width: 10),
                    Expanded(child: _ghostButton('View Public Store', gold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Store Health'),
                const SizedBox(height: 10),
                _healthRow(
                  'Orders Processing',
                  'Good',
                  Icons.check_circle,
                  const Color(0xFF1C8C4E),
                ),
                _healthRow(
                  'Low Stock',
                  '3 products',
                  Icons.warning_amber_rounded,
                  const Color(0xFFB27A1D),
                ),
                _healthRow(
                  'Payout Verification',
                  'Not verified',
                  Icons.cancel_rounded,
                  const Color(0xFFC03C2E),
                ),
                const SizedBox(height: 12),
                Text(
                  '78% Healthy',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    value: 0.78,
                    minHeight: 10,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4BAA54)),
                    backgroundColor: Color(0xFFF0E8D8),
                  ),
                ),
                const SizedBox(height: 12),
                _actionButton('Fix Issues', gold),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Finance Overview'),
                const SizedBox(height: 10),
                _kv('Available Balance', '₹0'),
                _kv('Pending Settlement', '₹0'),
                _kv('Commission Rate', '12%'),
                const SizedBox(height: 12),
                _actionButton('Go to Earnings', gold),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Management Actions'),
                const SizedBox(height: 6),
                _rowAction(
                  Icons.inventory_2_outlined,
                  'Product Management',
                  'Manage products, inventory tracking',
                ),
                _rowAction(
                  Icons.storefront_outlined,
                  'Store Controls',
                  'Branding, delivery settings, availability',
                ),
                _rowAction(
                  Icons.sell_outlined,
                  'Pricing Control',
                  'Prices, discounts, AI suggestions',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Alerts'),
                const SizedBox(height: 10),
                _alertRow(
                  'Payout details missing',
                  'High',
                  const Color(0xFFC03C2E),
                ),
                _alertRow(
                  'Low stock on 3 products',
                  'Medium',
                  const Color(0xFFB27A1D),
                ),
                _alertRow(
                  'High return rate detected',
                  'Medium',
                  const Color(0xFFB27A1D),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Color(0xFF8A1F2D)),
            title: Text(
              'Log out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8A1F2D),
              ),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DFCF)),
      ),
      child: child,
    );
  }

  Widget _title(String value) => Text(
    value,
    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
  );

  Widget _badge(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: fg,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _kv(
    String key,
    String value, {
    Color valueColor = const Color(0xFF1D1B17),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: GoogleFonts.inter(color: const Color(0xFF6D6659)),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.inter())),
          Text(
            value,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _rowAction(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFFD0A84F)),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: const Color(0xFF6D6659)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {},
    );
  }

  Widget _alertRow(String title, String priority, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          _badge(priority, color, color.withValues(alpha: 0.14)),
          const SizedBox(width: 8),
          TextButton(onPressed: () {}, child: const Text('Quick Fix')),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _ghostButton(String label, Color color) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
