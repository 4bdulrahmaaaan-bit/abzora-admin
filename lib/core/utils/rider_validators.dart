import 'package:flutter/material.dart';

class AppValidators {
  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? phone(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (v.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email';
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

extension RiderSnack on BuildContext {
  void showRiderSnack(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
