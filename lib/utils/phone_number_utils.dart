String normalizeIndianMobileNumber(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    return digits.substring(1);
  }
  return digits;
}

bool isValidIndianMobileNumber(String input) {
  return normalizeIndianMobileNumber(input).length == 10;
}
