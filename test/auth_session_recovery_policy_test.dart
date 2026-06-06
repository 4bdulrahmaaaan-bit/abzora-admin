import 'package:abzio/providers/auth_session_recovery_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldForceLogoutAfterUnauthorizedRecovery', () {
    test('does not force logout while the session is still restoring', () {
      expect(
        shouldForceLogoutAfterUnauthorizedRecovery(
          isRestoringSession: true,
          firebaseUserPresent: false,
          localUserPresent: false,
        ),
        isFalse,
      );
    });

    test('does not force logout when Firebase still has a user', () {
      expect(
        shouldForceLogoutAfterUnauthorizedRecovery(
          isRestoringSession: false,
          firebaseUserPresent: true,
          localUserPresent: false,
        ),
        isFalse,
      );
    });

    test('forces logout only when no session source remains', () {
      expect(
        shouldForceLogoutAfterUnauthorizedRecovery(
          isRestoringSession: false,
          firebaseUserPresent: false,
          localUserPresent: false,
        ),
        isTrue,
      );
    });
  });
}
