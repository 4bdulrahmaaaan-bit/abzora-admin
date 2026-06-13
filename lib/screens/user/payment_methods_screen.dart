import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/card_vault_service.dart';
import '../../theme.dart';
import '../../widgets/payment_selector.dart';

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
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final preferred = await _database.getPreferredPaymentMethod(user.id);
      if (!mounted) return;
      setState(() {
        _selectedMethod = preferred ?? 'UPI';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedMethod = 'UPI';
        _loading = false;
      });
    }
  }

  Future<void> _openAddCard() async {
    final result = await Navigator.pushNamed(context, '/add-card');
    if (result == true && mounted) {
      await _loadPreferredMethod();
      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Card saved securely.'),
        ),
      );
    }
  }

  Future<void> _saveAndContinue() async {
    if (_saving) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final method = _selectedMethod ?? 'UPI';
    setState(() => _saving = true);
    try {
      await _database.savePreferredPaymentMethod(user.id, method);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment preference saved.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preference: $error')),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Add Payment Method')),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(
                  color: context.abzioBorder.withValues(alpha: 0.65),
                ),
              ),
            ),
            child: SizedBox(
              height: 60,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAndContinue,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Continue'),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AbzioTheme.screenHorizontalPadding,
                    20,
                    AbzioTheme.screenHorizontalPadding,
                    132,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your preferred payment option.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.abzioSecondaryText,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AbzioTheme.sectionGap),
                      _SummaryCard(),
                      const SizedBox(height: AbzioTheme.sectionGap),
                      if (context.read<AuthProvider>().user != null) ...[
                        _CardsSection(
                          cardsStream: _cardVaultService.watchSavedCards(
                            context.read<AuthProvider>().user!.id,
                          ),
                          onAddCard: _openAddCard,
                        ),
                        const SizedBox(height: AbzioTheme.sectionGap),
                      ],
                      PaymentSelector(
                        selectedMethod: _selectedMethod,
                        onChanged: (method) {
                          setState(() => _selectedMethod = method);
                        },
                      ),
                      const SizedBox(height: AbzioTheme.spacing20),
                      _SecurityFooter(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _CardsSection extends StatelessWidget {
  const _CardsSection({required this.cardsStream, required this.onAddCard});

  final Stream<List<SavedCardSummary>> cardsStream;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: context.abzioBorder),
        boxShadow: AbzioTheme.shadowFor(Brightness.light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Cards',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(onPressed: onAddCard, child: const Text('Add card')),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SavedCardSummary>>(
            stream: cardsStream,
            builder: (context, snapshot) {
              final cards = snapshot.data ?? const <SavedCardSummary>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  cards.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (cards.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No saved cards yet.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a card to enable faster checkout.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: cards
                    .take(3)
                    .map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF8F0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.abzioBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F1E2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.credit_card_rounded,
                                  color: AbzioTheme.accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.maskedLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Saved with Razorpay tokenization',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: context.abzioSecondaryText,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: context.abzioBorder),
        boxShadow: AbzioTheme.shadowFor(Brightness.light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Checkout Benefits',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...const [
            _BenefitRow('Faster payments'),
            _BenefitRow('One-tap checkout'),
            _BenefitRow('Change anytime'),
            _BenefitRow('Secure processing'),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF2F7A3D),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AbzioTheme.accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Payments secured by Razorpay',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
