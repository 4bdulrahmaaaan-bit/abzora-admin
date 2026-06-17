import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/rider_signup_model.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../core/utils/rider_validators.dart';
import '../../../../core/theme/rider_theme.dart';

class RiderComplianceStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final Widget Function(String, String, String?, void Function(String)) visualCardBuilder;

  const RiderComplianceStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.visualCardBuilder,
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
            color: RiderTheme.onboardingGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
            border: Border.all(color: RiderTheme.onboardingGold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: RiderTheme.onboardingGold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bank-Grade Security',
                      style: TextStyle(
                        color: RiderTheme.onboardingGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your KYC documents are securely encrypted and used only for identity verification.',
                      style: TextStyle(
                        color: RiderTheme.onboardingGold.withValues(alpha: 0.8),
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
        RiderValidatedTextField(
          initialValue: model.aadhaar,
          label: 'Aadhaar Number',
          keyboardType: TextInputType.number,
          inputFormatters: [AadhaarInputFormatter()],
          validator: AppValidators.aadhaar,
          onChanged: (v) => onUpdate(model.copyWith(aadhaar: v)),
        ),
        const SizedBox(height: 16),
        RiderValidatedTextField(
          initialValue: model.pan,
          label: 'PAN Number',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(10),
            TextInputFormatter.withFunction((oldValue, newValue) {
              final upper = newValue.text.toUpperCase();
              return TextEditingValue(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }),
          ],
          validator: AppValidators.pan,
          onChanged: (v) => onUpdate(model.copyWith(pan: v)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Document Uploads',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        visualCardBuilder(
          'Driving License',
          'Front and back copy of your driving license',
          model.licenseDocPath,
          (p) => onUpdate(model.copyWith(licenseDocPath: p)),
        ),
        visualCardBuilder(
          'Selfie Verification',
          'A clear selfie taken just now for identification',
          model.selfiePath,
          (p) => onUpdate(model.copyWith(selfiePath: p)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: RiderTheme.onboardingElevatedSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: 0.75,
                  valueColor: AlwaysStoppedAnimation(RiderTheme.onboardingGold),
                  backgroundColor: RiderTheme.onboardingElevatedSurface,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Secure encrypted verification in progress',
                style: TextStyle(color: RiderTheme.onboardingPrimaryText.withValues(alpha: 0.78), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
