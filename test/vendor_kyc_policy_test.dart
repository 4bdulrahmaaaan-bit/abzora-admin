import 'package:abzio/core/utils/vendor_kyc_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VendorKycPolicy', () {
    test('requires manual review when confidence is below threshold', () {
      final verification = <String, dynamic>{
        'status': 'auto_verified',
        'confidenceScore': 72,
      };

      expect(VendorKycPolicy.requiresManualReview(verification), isTrue);
    });

    test('requires manual review when status is manual_review', () {
      final verification = <String, dynamic>{
        'status': 'manual_review',
        'confidenceScore': 93,
      };

      expect(VendorKycPolicy.requiresManualReview(verification), isTrue);
    });

    test(
      'does not require manual review when status and confidence are strong',
      () {
        final verification = <String, dynamic>{
          'status': 'auto_verified',
          'confidenceScore': 90,
        };

        expect(VendorKycPolicy.requiresManualReview(verification), isFalse);
      },
    );
  });
}
