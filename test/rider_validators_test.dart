import 'package:flutter_test/flutter_test.dart';
import 'package:abzio/core/utils/rider_validators.dart';

void main() {
  test('phone validator rejects invalid values', () {
    expect(AppValidators.phone('123'), isNotNull);
    expect(AppValidators.phone('9876543210'), isNull);
  });

  test('email validator works', () {
    expect(AppValidators.email('bad-email'), isNotNull);
    expect(AppValidators.email('rider@abzora.com'), isNull);
  });
}
