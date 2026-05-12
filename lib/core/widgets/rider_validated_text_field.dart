import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RiderValidatedTextField extends StatelessWidget {
  const RiderValidatedTextField({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onChanged,
    required this.validator,
    this.helperText,
    this.exampleText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
  });

  final String initialValue;
  final String label;
  final void Function(String value) onChanged;
  final String? Function(String? value) validator;
  final String? helperText;
  final String? exampleText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final error = validator(initialValue);
    final isValid = initialValue.trim().isNotEmpty && error == null;
    final mergedHelper = (exampleText != null && exampleText!.isNotEmpty)
        ? [
            if (helperText != null && helperText!.isNotEmpty) helperText!,
            exampleText!,
          ].join('\n')
        : helperText;

    return TextFormField(
      key: ValueKey('$label-$initialValue'),
      initialValue: initialValue,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.always,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: mergedHelper,
        errorText: error,
        counterText: '',
        suffixIcon: isValid
            ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: error != null ? Colors.redAccent : Colors.white24,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: error != null ? Colors.redAccent : const Color(0xFFD4AF37),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}
