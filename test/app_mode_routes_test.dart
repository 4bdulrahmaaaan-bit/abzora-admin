import 'package:abzio/app_shell.dart';
import 'package:abzio/models/models.dart';
import 'package:abzio/utils/app_mode_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppUser buildUser(String role) {
    return AppUser(
      id: 'u1',
      name: 'Test User',
      email: 'test@example.com',
      role: role,
    );
  }

  group('routeForUserInMode', () {
    test('routes customer user to shop in unified mode', () {
      expect(routeForUserInMode(buildUser('user'), AbzioAppMode.unified), '/shop');
    });

    test('routes vendor and rider to ops in unified mode', () {
      expect(routeForUserInMode(buildUser('vendor'), AbzioAppMode.unified), '/ops');
      expect(routeForUserInMode(buildUser('rider'), AbzioAppMode.unified), '/ops');
    });

    test('routes admin to admin entry in unified mode', () {
      expect(routeForUserInMode(buildUser('admin'), AbzioAppMode.unified), '/admin');
      expect(routeForUserInMode(buildUser('super_admin'), AbzioAppMode.unified), '/admin');
    });
  });

  group('accessRestrictionMessage', () {
    test('blocks vendor from customer-only build', () {
      expect(
        accessRestrictionMessage(buildUser('vendor'), AbzioAppMode.customer),
        isNotNull,
      );
    });

    test('blocks customer from operations-only build', () {
      expect(
        accessRestrictionMessage(buildUser('user'), AbzioAppMode.operations),
        isNotNull,
      );
    });

    test('allows admin in unified mode and defers route gating to admin shell', () {
      expect(
        accessRestrictionMessage(buildUser('admin'), AbzioAppMode.unified),
        isNull,
      );
    });

    test('allows valid role in matching build', () {
      expect(accessRestrictionMessage(buildUser('user'), AbzioAppMode.customer), isNull);
      expect(accessRestrictionMessage(buildUser('vendor'), AbzioAppMode.operations), isNull);
    });
  });
}
