import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/rider_signup_model.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../core/utils/rider_validators.dart';
import '../../../../core/theme/rider_theme.dart';

class VehicleStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final InputDecoration Function(String) inputDecorationBuilder;
  final Widget Function(String, String?, void Function(String)) uploadRowBuilder;

  const VehicleStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.inputDecorationBuilder,
    required this.uploadRowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: VehicleType.values.map((v) {
            final selected = model.vehicleType == v;
            return ChoiceChip(
              label: Text(
                v.name,
                style: TextStyle(
                  color: selected ? RiderTheme.onboardingBackground : RiderTheme.onboardingPrimaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              selectedColor: RiderTheme.onboardingGold,
              backgroundColor: RiderTheme.onboardingElevatedSurface,
              side: BorderSide(
                color: selected ? RiderTheme.onboardingGold : RiderTheme.onboardingElevatedSurface,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RiderTheme.radiusSmall)),
              onSelected: (selected) => onUpdate(model.copyWith(vehicleType: v)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        RiderValidatedTextField(
          initialValue: model.vehicleNumber,
          label: 'Vehicle Registration Number',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
            TextInputFormatter.withFunction((oldValue, newValue) {
              final normalized = newValue.text
                  .replaceAll(RegExp(r'\s+'), '')
                  .toUpperCase();
              return TextEditingValue(
                text: normalized,
                selection: TextSelection.collapsed(offset: normalized.length),
              );
            }),
          ],
          validator: AppValidators.vehicleNumber,
          onChanged: (v) => onUpdate(model.copyWith(vehicleNumber: v)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: model.licenseNumber,
          decoration: inputDecorationBuilder('Driving License Number'),
          style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) => onUpdate(model.copyWith(licenseNumber: v)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Vehicle Documents',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        uploadRowBuilder(
          'RC Book',
          model.rcPath,
          (p) => onUpdate(model.copyWith(rcPath: p)),
        ),
        uploadRowBuilder(
          'Vehicle Insurance',
          model.insurancePath,
          (p) => onUpdate(model.copyWith(insurancePath: p)),
        ),
      ],
    );
  }
}
