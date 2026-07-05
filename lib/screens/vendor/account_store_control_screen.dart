import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/business_health_api.dart';
import '../../models/models.dart';

class AccountStoreControlScreen extends StatefulWidget {
  const AccountStoreControlScreen({super.key});

  @override
  State<AccountStoreControlScreen> createState() => _AccountStoreControlScreenState();
}

class _AccountStoreControlScreenState extends State<AccountStoreControlScreen> {
  Store? _store;
  WalletSummary? _wallet;
  Map<String, dynamic>? _health;
  PayoutProfileSummary? _payoutProfile;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) _loadData();
  }

  Future<void> _loadData() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final db = DatabaseService();
    final storeId = actor.storeId;

    Store? store;
    WalletSummary? wallet;
    Map<String, dynamic>? health;
    PayoutProfileSummary? payoutProfile;

    try {
      store = storeId != null
          ? await db.getStore(storeId)
          : await db.getStoreByOwner(actor.id);
    } catch (error) {
      debugPrint('AccountControl: failed to load store: $error');
    }

    try {
      wallet = await db.getVendorWallet(actor: actor);
    } catch (error) {
      debugPrint('AccountControl: failed to load wallet: $error');
    }

    try {
      health = await BusinessHealthApi().getHealth();
    } catch (error) {
      debugPrint('AccountControl: failed to load health: $error');
    }

    try {
      payoutProfile = await db.getVendorPayoutProfile(actor: actor);
    } catch (error) {
      debugPrint('AccountControl: failed to load payout profile: $error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _store = store;
      _wallet = wallet;
      _health = health;
      _payoutProfile = payoutProfile;
      _isLoading = false;
    });
  }

  String _money(double value) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);

  int _healthScore() {
    final score = _health?['score'];
    if (score is num) {
      return score.round();
    }
    return 70;
  }

  bool get _isHealthy => _healthScore() >= 60;
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
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        _store?.name.isNotEmpty == true ? _store!.name : 'Your Store',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _badge(
                      _store?.isActive == true ? 'Active' : 'Inactive',
                      _store?.isActive == true ? const Color(0xFF1C8C4E) : const Color(0xFFC03C2E),
                      _store?.isActive == true ? const Color(0xFFE7F6ED) : const Color(0xFFFDE8E8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _kv('Address', _store?.city.isNotEmpty == true ? _store!.city : 'Address not set'),
                _kv('Commission', '${_store?.commissionRate ?? _wallet?.commissionRate ?? 12}%'),
                _kv(
                  'Payout Status',
                  _payoutProfile?.isConfigured == true ? 'Verified' : 'Pending',
                  valueColor: _payoutProfile?.isConfigured == true ? const Color(0xFF1C8C4E) : const Color(0xFFC03C2E),
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
                  _health?['ordersHealthy'] == true ? 'Good' : 'Needs attention',
                  _health?['ordersHealthy'] == true ? Icons.check_circle : Icons.warning_amber_rounded,
                  _health?['ordersHealthy'] == true ? const Color(0xFF1C8C4E) : const Color(0xFFB27A1D),
                ),
                _healthRow(
                  'Stock Levels',
                  'Stable',
                  Icons.check_circle,
                  const Color(0xFF1C8C4E),
                ),
                _healthRow(
                  'Payout Verification',
                  _payoutProfile?.isConfigured == true ? 'Verified' : 'Not verified',
                  _payoutProfile?.isConfigured == true ? Icons.check_circle : Icons.cancel_rounded,
                  _payoutProfile?.isConfigured == true ? const Color(0xFF1C8C4E) : const Color(0xFFC03C2E),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_healthScore()}% Healthy',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _healthScore() / 100.0,
                    minHeight: 10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4BAA54)),
                    backgroundColor: const Color(0xFFF0E8D8),
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
                _kv('Available Balance', _money(_wallet?.balance ?? 0)),
                _kv('Pending Settlement', _money(_wallet?.pendingAmount ?? 0)),
                _kv('Commission Rate', '${_wallet?.commissionRate ?? _store?.commissionRate ?? 12}%'),
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
                if (_payoutProfile?.isConfigured != true)
                  _alertRow(
                    'Payout details missing',
                    'High',
                    const Color(0xFFC03C2E),
                  ),
                if ((_wallet?.pendingAmount ?? 0) > 0)
                  _alertRow(
                    'Pending settlement',
                    'Medium',
                    const Color(0xFFB27A1D),
                  ),
                if (!_isHealthy)
                  _alertRow(
                    'Low store health score',
                    'Medium',
                    const Color(0xFFB27A1D),
                  ),
                if (_payoutProfile?.isConfigured == true && (_wallet?.pendingAmount ?? 0) == 0 && _isHealthy)
                  Text('No alerts right now.', style: GoogleFonts.inter()),
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
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout', style: TextStyle(color: Color(0xFF8A1F2D))),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
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

