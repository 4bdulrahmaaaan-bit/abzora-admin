import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/card_vault_service.dart';
import '../../services/database_service.dart';
import '../../services/payment_service.dart';
import '../../theme.dart';
import '../../widgets/tap_scale.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _numberFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();

  late final AnimationController _heroController;
  late final Animation<double> _heroScale;
  final PaymentService _paymentService = PaymentService();
  final DatabaseService _database = DatabaseService();
  final CardVaultService _cardVaultService = CardVaultService();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _heroScale = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    );

    _numberController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
    _expiryController.addListener(_onFieldChanged);
    _cvvController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _heroController.dispose();
    _numberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _numberFocus.dispose();
    _nameFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _digitsOnly => _numberController.text.replaceAll(RegExp(r'\D'), '');

  String get _maskedPreviewNumber {
    if (_digitsOnly.isEmpty) {
      return 'XXXX XXXX XXXX XXXX';
    }
    final visible = _digitsOnly.length > 4 ? _digitsOnly.substring(_digitsOnly.length - 4) : _digitsOnly;
    return 'XXXX XXXX XXXX ${visible.padLeft(4, 'X')}';
  }

  String get _previewName {
    final name = _nameController.text.trim();
    return name.isEmpty ? 'CARD HOLDER' : name.toUpperCase();
  }

  String get _previewExpiry {
    final expiry = _expiryController.text.trim();
    return expiry.isEmpty ? 'MM/YY' : expiry;
  }

  String get _cardTypeLabel {
    final digits = _digitsOnly;
    if (digits.startsWith('4')) {
      return 'VISA';
    }
    if (RegExp(r'^(5[1-5])').hasMatch(digits) ||
        RegExp(r'^(222[1-9]|22[3-9]\d|2[3-6]\d{2}|27[01]\d|2720)').hasMatch(digits)) {
      return 'MASTERCARD';
    }
    if (RegExp(r'^(60|65|508|81|82)').hasMatch(digits)) {
      return 'RUPAY';
    }
    return 'CARD';
  }

  bool get _isFormValid {
    return _validateCardNumber(_numberController.text) == null &&
        _validateName(_nameController.text) == null &&
        _validateExpiry(_expiryController.text) == null &&
        _validateCvv(_cvvController.text) == null;
  }

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Enter your card number';
    }
    if (digits.length < 16 || digits.length > 19) {
      return 'Enter a valid card number';
    }
    if (!_passesLuhn(digits)) {
      return 'Card number looks invalid';
    }
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Enter the card holder name';
    }
    if (name.length < 2) {
      return 'Name is too short';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final expiry = value?.trim() ?? '';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      return 'Use MM/YY';
    }
    final month = int.tryParse(expiry.substring(0, 2));
    final year = int.tryParse(expiry.substring(3, 5));
    if (month == null || year == null || month < 1 || month > 12) {
      return 'Enter a valid expiry';
    }
    final now = DateTime.now();
    final fullYear = 2000 + year;
    final lastValidDay = DateTime(fullYear, month + 1, 0);
    if (lastValidDay.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Card has expired';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    final cvv = (value ?? '').trim();
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv)) {
      return 'Enter a valid CVV';
    }
    return null;
  }

  bool _passesLuhn(String input) {
    var sum = 0;
    var alternate = false;
    for (var i = input.length - 1; i >= 0; i--) {
      var digit = int.parse(input[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  Future<void> _saveCard() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (!_formKey.currentState!.validate() || _submitting || user == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _paymentService.tokenizeCard(
        userId: user.id,
        name: _nameController.text.trim(),
        email: user.email,
        contact: user.phone ?? '',
      );
      if (!result.success) {
        throw StateError(result.message ?? 'Payment failed, try again.');
      }
      if (result.card != null) {
        await _cardVaultService.saveCardSummary(result.card!);
      }
      await _database.savePreferredPaymentMethod(user.id, 'CARDS');
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            result.card == null
                ? 'Card saved securely.'
                : '${result.card!.cardType} ending in ${result.card!.last4} saved securely.',
          ),
        ),
      );
      navigator.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            error is StateError ? error.message : 'We could not save the card right now.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  InputDecoration _decoration(BuildContext context, String label, {Widget? suffixIcon, String? hintText}) {
    final borderColor = context.abzioBorder;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AbzioTheme.accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD24B4B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD24B4B), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        appBar: AppBar(
          title: const Text('Add Card'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1).animate(_heroScale),
                    child: FadeTransition(
                      opacity: _heroScale,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1C1610),
                              Color(0xFF332617),
                              Color(0xFF5A431B),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9B7B2D).withValues(alpha: 0.2),
                              blurRadius: 28,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                    _cardTypeLabel,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: const Color(0xFFFFE4A3),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                        ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.lock_outline_rounded, color: Color(0xFFFFE4A3)),
                              ],
                            ),
                            const SizedBox(height: 34),
                            Text(
                              _maskedPreviewNumber,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: _PreviewLabel(
                                    label: 'Card Holder',
                                    value: _previewName,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _PreviewLabel(
                                  label: 'Expires',
                                  value: _previewExpiry,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Card details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your card once for a faster checkout preference. ABZORA never stores raw card details.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.abzioSecondaryText,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _numberController,
                    focusNode: _numberFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      _CardNumberFormatter(),
                    ],
                    decoration: _decoration(
                      context,
                      'Card Number',
                      hintText: '1234 5678 9012 3456',
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            _cardTypeLabel,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AbzioTheme.accentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                    validator: _validateCardNumber,
                    onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(context, 'Card Holder Name', hintText: 'Name on card'),
                    validator: _validateName,
                    onFieldSubmitted: (_) => _expiryFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
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
                          decoration: _decoration(context, 'Expiry Date', hintText: 'MM/YY'),
                          validator: _validateExpiry,
                          onFieldSubmitted: (_) => _cvvFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                          decoration: _decoration(
                            context,
                            'CVV',
                            hintText: '123',
                            suffixIcon: const Icon(Icons.shield_outlined),
                          ),
                          validator: _validateCvv,
                          onFieldSubmitted: (_) => _saveCard(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
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
                            color: const Color(0xFFFFF7E4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: AbzioTheme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your card details are passed only to Razorpay for secure verification. ABZORA stores only a card reference, card type, and the last four digits.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context.abzioSecondaryText,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TapScale(
                    onTap: _isFormValid && !_submitting ? _saveCard : null,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFormValid && !_submitting ? _saveCard : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          backgroundColor: AbzioTheme.accentColor,
                          foregroundColor: AbzioTheme.textPrimary,
                          disabledBackgroundColor: const Color(0xFFE6D8AA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : const Text(
                                'Save Card',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel({
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
                color: Colors.white.withValues(alpha: 0.7),
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

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final next = i + 1;
      if (next % 4 == 0 && next != digits.length) {
        buffer.write(' ');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
