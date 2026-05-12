import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppValidators {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
  static final RegExp _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final RegExp _vehicleRegex = RegExp(
    r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$',
  );
  static final RegExp _upiRegex = RegExp(
    r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$',
  );
  static final RegExp _accountRegex = RegExp(r'^[0-9]{9,18}$');

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? phone(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (!_phoneRegex.hasMatch(v)) return 'Enter valid mobile number';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? aadhaar(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
      return 'Enter valid 12-digit Aadhaar number';
    }
    return null;
  }

  static String? pan(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (!_panRegex.hasMatch(v)) {
      return 'Enter valid PAN number';
    }
    return null;
  }

  static String? ifsc(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (!_ifscRegex.hasMatch(v)) {
      return 'Enter valid IFSC code';
    }
    return null;
  }

  static String? vehicleNumber(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (!_vehicleRegex.hasMatch(v)) {
      return 'Enter valid vehicle number';
    }
    return null;
  }

  static String? upi(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return null;
    }
    if (!_upiRegex.hasMatch(v) || v.contains(' ')) {
      return 'Enter valid UPI ID';
    }
    return null;
  }

  static String? bankAccount(String? value) {
    final v = (value ?? '').trim();
    if (!_accountRegex.hasMatch(v)) {
      return 'Enter valid account number';
    }
    return null;
  }

  static String? minLength(String? value, String label, int min) {
    if ((value ?? '').trim().length < min) {
      return '$label must be at least $min characters';
    }
    return null;
  }
}

class AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digits.length > 12 ? digits.substring(0, 12) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < clipped.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(clipped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

extension RiderSnack on BuildContext {
  void showRiderSnack(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
