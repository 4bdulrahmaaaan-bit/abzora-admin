import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/rider_signup_model.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../core/utils/rider_validators.dart';

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
      children: [
        Wrap(
          spacing: 8,
          children: VehicleType.values.map((v) {
            final selected = model.vehicleType == v;
            return ChoiceChip(
              label: Text(v.name),
              selected: selected,
              selectedColor: const Color(0xFFD4AF37),
              onSelected: (selected) => onUpdate(model.copyWith(vehicleType: v)),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        RiderValidatedTextField(
          initialValue: model.vehicleNumber,
          label: 'Vehicle Number',
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
          helperText: 'Format: TN01AB1234 or KA05MK9090',
          validator: AppValidators.vehicleNumber,
          onChanged: (v) => onUpdate(model.copyWith(vehicleNumber: v)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: model.licenseNumber,
          decoration: inputDecorationBuilder('Driving License Number'),
          onChanged: (v) => onUpdate(model.copyWith(licenseNumber: v)),
        ),
        const SizedBox(height: 10),
        uploadRowBuilder(
          'RC Book',
          model.rcPath,
          (p) => onUpdate(model.copyWith(rcPath: p)),
        ),
        uploadRowBuilder(
          'Insurance',
          model.insurancePath,
          (p) => onUpdate(model.copyWith(insurancePath: p)),
        ),
      ],
    );
  }
}
