import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/rider_signup_model.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../core/utils/rider_validators.dart';

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
      children: [
        TextFormField(
          initialValue: model.accountHolder,
          decoration: inputDecorationBuilder('Account Holder Name'),
          onChanged: (v) => onUpdate(model.copyWith(accountHolder: v)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: model.bankName,
          decoration: inputDecorationBuilder('Bank Name'),
          onChanged: (v) => onUpdate(model.copyWith(bankName: v)),
        ),
        const SizedBox(height: 10),
        RiderValidatedTextField(
          initialValue: model.accountNumber,
          label: 'Account Number',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 18,
          helperText: '9 to 18 digits',
          validator: AppValidators.bankAccount,
          onChanged: (v) => onUpdate(model.copyWith(accountNumber: v)),
        ),
        const SizedBox(height: 10),
        RiderValidatedTextField(
          initialValue: model.ifsc,
          label: 'IFSC Code',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(11),
          ],
          helperText: '11 character IFSC',
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
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (ifscLookupMessage.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ifscLookupMessage,
              style: const TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.78),
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 10),
        RiderValidatedTextField(
          initialValue: model.upi,
          label: 'UPI ID (optional)',
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          helperText: 'Format: username@bank',
          validator: AppValidators.upi,
          onChanged: (v) => onUpdate(model.copyWith(upi: v)),
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Icon(Icons.lock_rounded, color: Colors.greenAccent, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Encrypted payout details. Stored securely for settlement only.',
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.78),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
