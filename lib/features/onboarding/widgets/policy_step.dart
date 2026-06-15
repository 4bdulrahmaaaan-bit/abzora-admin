import 'package:flutter/material.dart';
import '../../../models/rider_signup_model.dart';
import '../../../../core/theme/rider_theme.dart';

class PolicyStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final InputDecoration Function(String) inputDecorationBuilder;

  const PolicyStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.inputDecorationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
            border: Border.all(color: RiderTheme.onboardingElevatedSurface),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rider Partner Agreement',
                style: TextStyle(
                  color: RiderTheme.onboardingPrimaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'By joining Abianzo Rider, you agree to service standards, customer safety policies, payout terms, and data processing clauses for verification and operations.',
                style: TextStyle(
                  color: RiderTheme.onboardingSecondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: RiderTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
            border: Border.all(
              color: model.acceptedTerms ? RiderTheme.onboardingSuccess.withValues(alpha: 0.5) : RiderTheme.onboardingElevatedSurface,
            ),
          ),
          child: CheckboxListTile(
            value: model.acceptedTerms,
            onChanged: (v) => onUpdate(model.copyWith(acceptedTerms: v ?? false)),
            title: const Text(
              'I agree to all terms and policies',
              style: TextStyle(color: RiderTheme.onboardingPrimaryText, fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: RiderTheme.onboardingSuccess,
            checkColor: RiderTheme.onboardingBackground,
            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: model.signature,
          decoration: inputDecorationBuilder(
            'Digital Signature (type full name)',
          ),
          style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
          onChanged: (v) => onUpdate(model.copyWith(signature: v)),
        ),
      ],
    );
  }
}
