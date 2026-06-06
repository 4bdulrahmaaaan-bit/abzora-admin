import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/card_vault_service.dart';
import '../../services/database_service.dart';
import '../../services/payment_service.dart';
import '../../theme.dart';
import '../../widgets/abzio_motion.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final FocusNode _numberFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _expiryFocus = FocusNode();
  final FocusNode _cvvFocus = FocusNode();

  final PaymentService _paymentService = PaymentService();
  final DatabaseService _database = DatabaseService();
  final CardVaultService _cardVaultService = CardVaultService();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _numberController.addListener(_onCardChanged);
    _nameController.addListener(_onCardChanged);
    _expiryController.addListener(_onCardChanged);
    _cvvController.addListener(_onCardChanged);
  }

  @override
  void dispose() {
    _numberController.removeListener(_onCardChanged);
    _nameController.removeListener(_onCardChanged);
    _expiryController.removeListener(_onCardChanged);
    _cvvController.removeListener(_onCardChanged);
    _numberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _numberFocus.dispose();
    _nameFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  void _onCardChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _digitsOnlyNumber => _numberController.text.replaceAll(RegExp(r'\D'), '');

  String get _cardBrand => _detectBrand(_digitsOnlyNumber);

  String get _maskedPreviewNumber {
    final digits = _digitsOnlyNumber.padRight(16, 'X');
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  String get _expiryPreview {
    final text = _expiryController.text.trim();
    return text.isEmpty ? 'MM/YY' : text;
  }

  String _detectBrand(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (digits.startsWith('5')) return 'Mastercard';
    if (digits.startsWith('60') || digits.startsWith('65') || digits.startsWith('81')) {
      return 'RuPay';
    }
    if (digits.length >= 2) {
      final firstTwo = int.tryParse(digits.substring(0, 2)) ?? 0;
      if (firstTwo >= 51 && firstTwo <= 55) return 'Mastercard';
      if (firstTwo == 60 || firstTwo == 65) return 'RuPay';
    }
    return 'Card Brand';
  }

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Card number is required';
    if (digits.length < 12) return 'Card number looks invalid';
    return null;
  }

  String? _validateName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Card holder name is required';
    if (trimmed.length < 2) return 'Enter a valid card holder name';
    return null;
  }

  String? _validateExpiry(String? value) {
    final trimmed = (value ?? '').trim();
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(trimmed);
    if (trimmed.isEmpty) return 'Expiry is required';
    if (match == null) return 'Use MM/YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'Card has expired';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'CVV is required';
    if (trimmed.length < 3) return 'CVV looks invalid';
    return null;
  }

  Future<void> _saveCard() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save a card.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _paymentService.tokenizeCard(
        userId: user.id,
        name: _nameController.text.trim(),
        email: user.email.trim().isNotEmpty ? user.email.trim() : '${user.id}@abianzo.app',
        contact: user.phone ?? '',
      );
      if (!result.success || result.card == null) {
        throw StateError(result.message ?? 'Payment failed, try again.');
      }

      await _cardVaultService.saveCardSummary(result.card!);
      await _database.savePreferredPaymentMethod(user.id, 'CARDS');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card verified securely and saved.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save card: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  InputDecoration _fieldDecoration(BuildContext context, String label, {String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Add Card')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AbzioTheme.screenHorizontalPadding,
                16,
                AbzioTheme.screenHorizontalPadding,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardPreview(
                    brand: _cardBrand,
                    number: _maskedPreviewNumber,
                    holder: _nameController.text.trim().isEmpty
                        ? 'CARD HOLDER'
                        : _nameController.text.trim().toUpperCase(),
                    expiry: _expiryPreview,
                  ),
                  const SizedBox(height: AbzioTheme.sectionGap),
                  Text(
                    'Card details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _numberController,
                    focusNode: _numberFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      _CardNumberFormatter(),
                    ],
                    decoration: _fieldDecoration(
                      context,
                      'Card Number',
                      hintText: 'XXXX XXXX XXXX XXXX',
                      suffixIcon: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: Center(
                          widthFactor: 0,
                          child: AnimatedSwitcher(
                            duration: AbzioMotion.medium,
                            child: Text(
                              _cardBrand,
                              key: ValueKey(_cardBrand),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AbzioTheme.accentColor,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    validator: _validateCardNumber,
                    onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(context, 'Card Holder', hintText: 'Name on card'),
                    validator: _validateName,
                    onFieldSubmitted: (_) => _expiryFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          focusNode: _expiryFocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryDateFormatter(),
                          ],
                          decoration: _fieldDecoration(context, 'Expiry', hintText: 'MM/YY'),
                          validator: _validateExpiry,
                          onFieldSubmitted: (_) => _cvvFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          focusNode: _cvvFocus,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: _fieldDecoration(context, 'CVV', hintText: '•••'),
                          validator: _validateCvv,
                          onFieldSubmitted: (_) => _saveCard(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbzioTheme.sectionGap),
                  _SecurityBlock(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: AbzioMotion.medium,
          curve: AbzioMotion.curve,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(color: context.abzioBorder.withValues(alpha: 0.65)),
                ),
              ),
              child: SizedBox(
                height: 60,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _saveCard,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Securely Verify Card'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.brand,
    required this.number,
    required this.holder,
    required this.expiry,
  });

  final String brand;
  final String number;
  final String holder;
  final String expiry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1913),
            Color(0xFF332817),
            Color(0xFF5E461D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B7B2D).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  brand,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFFFE4A3),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFFFE4A3)),
            ],
          ),
          Text(
            number,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
          ),
          Row(
            children: [
              Expanded(
                child: _PreviewField(label: 'Card Holder', value: holder),
              ),
              const SizedBox(width: 18),
              _PreviewField(label: 'Expiry', value: expiry),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SecurityBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AbzioTheme.accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Card Verification',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your card details are sent directly to Razorpay.\n\nAbianzo never stores card numbers or CVV data.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  const _CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  const _ExpiryDateFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
