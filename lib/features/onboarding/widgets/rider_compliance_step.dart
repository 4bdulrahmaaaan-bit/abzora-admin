import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/rider_signup_model.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../core/utils/rider_validators.dart';

class RiderComplianceStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final Widget Function(String, String?, void Function(String)) uploadRowBuilder;

  const RiderComplianceStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.uploadRowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RiderValidatedTextField(
          initialValue: model.aadhaar,
          label: 'Aadhaar Number',
          keyboardType: TextInputType.number,
          inputFormatters: [AadhaarInputFormatter()],
          helperText: '12 digits in XXXX XXXX XXXX format',
          validator: AppValidators.aadhaar,
          onChanged: (v) => onUpdate(model.copyWith(aadhaar: v)),
        ),
        const SizedBox(height: 10),
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
          helperText: 'Format: AAAAA9999A',
          validator: AppValidators.pan,
          onChanged: (v) => onUpdate(model.copyWith(pan: v)),
        ),
        const SizedBox(height: 10),
        uploadRowBuilder(
          'Driving License Upload',
          model.licenseDocPath,
          (p) => onUpdate(model.copyWith(licenseDocPath: p)),
        ),
        uploadRowBuilder(
          'Selfie Verification',
          model.selfiePath,
          (p) => onUpdate(model.copyWith(selfiePath: p)),
        ),
        const SizedBox(height: 10),
        const LinearProgressIndicator(value: 0.75, color: Color(0xFFD4AF37)),
        const SizedBox(height: 8),
        const Text(
          'Secure encrypted verification in progress',
          style: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.78)),
        ),
      ],
    );
  }
}
