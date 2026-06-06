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
      initialValue: initialValue,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.always,
      onChanged: onChanged,
      validator: validator,
      cursorColor: const Color(0xFFC8A86B),
      style: const TextStyle(
        color: Color(0xFF111111),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: mergedHelper,
        errorText: error,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF9F7F2),
        labelStyle: const TextStyle(color: Color(0xFF666666)),
        hintStyle: const TextStyle(color: Color(0xFF7A7366)),
        floatingLabelStyle: const TextStyle(color: Color(0xFFC8A86B)),
        suffixIcon: isValid
            ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: error != null ? Colors.redAccent : const Color(0xFFE8DCC2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: error != null ? Colors.redAccent : const Color(0xFFC8A86B),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}
