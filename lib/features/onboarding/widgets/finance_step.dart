import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/rider_signup_model.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../core/utils/rider_validators.dart';
import '../../../../core/theme/rider_theme.dart';

class FinanceStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final InputDecoration Function(String) inputDecorationBuilder;
  final bool ifscLookupLoading;
  final String ifscLookupMessage;
  final ValueChanged<String> onIfscChanged;

  const FinanceStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.inputDecorationBuilder,
    required this.ifscLookupLoading,
    required this.ifscLookupMessage,
    required this.onIfscChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderTheme.onboardingSuccess.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
            border: Border.all(color: RiderTheme.onboardingSuccess.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: RiderTheme.onboardingSuccess, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Secure Payments',
                      style: TextStyle(
                        color: RiderTheme.onboardingSuccess,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your payout details are encrypted and stored securely for weekly settlements.',
                      style: TextStyle(
                        color: RiderTheme.onboardingSuccess.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Bank Details',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: model.accountHolder,
          decoration: inputDecorationBuilder('Account Holder Name'),
          style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
          onChanged: (v) => onUpdate(model.copyWith(accountHolder: v)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: model.bankName,
          decoration: inputDecorationBuilder('Bank Name'),
          style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
          onChanged: (v) => onUpdate(model.copyWith(bankName: v)),
        ),
        const SizedBox(height: 16),
        RiderValidatedTextField(
          initialValue: model.accountNumber,
          label: 'Account Number',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 18,
          validator: AppValidators.bankAccount,
          onChanged: (v) => onUpdate(model.copyWith(accountNumber: v)),
        ),
        const SizedBox(height: 16),
        RiderValidatedTextField(
          initialValue: model.ifsc,
          label: 'IFSC Code',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(11),
          ],
          validator: AppValidators.ifsc,
          onChanged: onIfscChanged,
        ),
        const SizedBox(height: 6),
        if (ifscLookupLoading)
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: RiderTheme.onboardingGold),
            ),
          ),
        if (ifscLookupMessage.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: RiderTheme.onboardingGold),
                const SizedBox(width: 6),
                Text(
                  ifscLookupMessage,
                  style: const TextStyle(
                    color: RiderTheme.onboardingGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 32),
        const Text(
          'Fast Payouts (Optional)',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        RiderValidatedTextField(
          initialValue: model.upi,
          label: 'UPI ID',
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          validator: AppValidators.upi,
          onChanged: (v) => onUpdate(model.copyWith(upi: v)),
        ),
      ],
    );
  }
}
