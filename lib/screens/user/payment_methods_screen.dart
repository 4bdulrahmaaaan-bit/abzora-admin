import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/card_vault_service.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/abzio_motion.dart';
import '../../widgets/global_skeletons.dart';
import '../../widgets/tap_scale.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final DatabaseService _database = DatabaseService();
  final CardVaultService _cardVaultService = CardVaultService();

  bool _loading = true;
  bool _saving = false;
  String? _selectedMethod;
  @override
  void initState() {
    super.initState();
    _loadPreferredMethod();
  }

  Future<void> _loadPreferredMethod() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final preferred = await _database.getPreferredPaymentMethod(user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedMethod = preferred ?? 'UPI';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedMethod = 'UPI';
        _loading = false;
      });
    }
  }

  Future<void> _openAddCard() async {
    final result = await Navigator.pushNamed(context, '/add-card');
    if (result == true && mounted) {
      _loadPreferredMethod();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Card added to your payment preferences.'),
        ),
      );
    }
  }

  Future<void> _selectMethod(String method) async {
    if (_saving) {
      return;
    }
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    setState(() {
      _selectedMethod = method;
      _saving = true;
    });
    try {
      await _database.savePreferredPaymentMethod(user.id, method);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Preferred payment method updated.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Payment preference could not be saved right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        appBar: AppBar(
          title: const Text('Payment Methods'),
        ),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCard(height: 92),
                    SizedBox(height: 16),
                    ShimmerListItem(),
                    SizedBox(height: 12),
                    ShimmerListItem(),
                    SizedBox(height: 12),
                    ShimmerListItem(),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AbzioStaggerItem(
                      index: 0,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFF8E7),
                              AbzioTheme.accentColor.withValues(alpha: 0.14),
                              Colors.white,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose your preferred checkout method',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ABZORA will preselect this at checkout for a faster, smoother payment flow.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: context.abzioSecondaryText,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AbzioStaggerItem(
                      index: 1,
                      child: _PaymentOptionTile(
                        icon: Icons.qr_code_2_rounded,
                        title: 'UPI',
                        subtitle: 'Google Pay, PhonePe, Paytm',
                        badge: 'Recommended',
                        selected: _selectedMethod == 'UPI',
                        onTap: () => _selectMethod('UPI'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AbzioStaggerItem(
                      index: 2,
                      child: StreamBuilder<List<SavedCardSummary>>(
                        stream: context.read<AuthProvider>().user == null
                            ? const Stream<List<SavedCardSummary>>.empty()
                            : _cardVaultService.watchSavedCards(context.read<AuthProvider>().user!.id),
                        builder: (context, snapshot) {
                          final cards = snapshot.data ?? const <SavedCardSummary>[];
                          if (cards.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final card = cards.first;
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1811),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.credit_card_rounded,
                                    color: Color(0xFFFFE3A0),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.maskedLabel,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Saved with Razorpay tokenization',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.72),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    AbzioStaggerItem(
                      index: 3,
                      child: _PaymentOptionTile(
                        icon: Icons.credit_card_rounded,
                        title: 'Cards',
                        subtitle: 'Credit and debit cards',
                        selected: _selectedMethod == 'CARDS',
                        onTap: () => _selectMethod('CARDS'),
                        actionLabel: 'Add card',
                        onActionTap: _openAddCard,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AbzioStaggerItem(
                      index: 4,
                      child: _PaymentOptionTile(
                        icon: Icons.payments_outlined,
                        title: 'Cash on Delivery',
                        subtitle: 'Pay when your order arrives',
                        selected: _selectedMethod == 'COD',
                        onTap: () => _selectMethod('COD'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AbzioStaggerItem(
                      index: 5,
                      child: _PaymentOptionTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'ABZORA Credit',
                        subtitle: 'Wallet checkout will be available soon',
                        selected: _selectedMethod == 'WALLET',
                        enabled: false,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 18),
                    AbzioStaggerItem(
                      index: 6,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.abzioBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8EA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: AbzioTheme.accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your selected payment method will be used only as a preference. Payments remain secure and are confirmed at checkout.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: context.abzioSecondaryText,
                                      height: 1.45,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        color: AbzioTheme.accentColor,
                        backgroundColor: Color(0xFFF3E7BE),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
    this.enabled = true,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool enabled;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: TapScale(
        onTap: enabled ? onTap : null,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFFBF0) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? AbzioTheme.accentColor : context.abzioBorder,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? AbzioTheme.accentColor.withValues(alpha: 0.16)
                        : const Color(0xFFF7F3EA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AbzioTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.abzioSecondaryText,
                            ),
                      ),
                      if (actionLabel != null && enabled) ...[
                        const SizedBox(height: 10),
                        TapScale(
                          onTap: onActionTap,
                          child: InkWell(
                            onTap: onActionTap,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                actionLabel!,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AbzioTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
