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
      activeRole: role,
    );
  }

  AppUser buildCapabilityUser({
    required String role,
    required String activeRole,
    required Map<String, bool> roles,
  }) {
    return AppUser(
      id: 'u2',
      name: 'Capability User',
      email: 'capability@example.com',
      role: role,
      activeRole: activeRole,
      roles: roles,
    );
  }

  group('routeForUserInMode', () {
    test('routes customer user to shop in unified mode', () {
      expect(routeForUserInMode(buildUser('user'), AbzioAppMode.unified), '/shop');
    });

    test('routes vendor and rider to onboarding in unified mode', () {
      expect(routeForUserInMode(buildUser('vendor'), AbzioAppMode.unified), '/vendor-onboarding');
      expect(routeForUserInMode(buildUser('rider'), AbzioAppMode.unified), '/rider-onboarding');
    });

    test('routes admin to admin entry in unified mode', () {
      expect(routeForUserInMode(buildUser('admin'), AbzioAppMode.unified), '/admin');
      expect(routeForUserInMode(buildUser('super_admin'), AbzioAppMode.unified), '/admin');
    });

    test('respects role capabilities from roles map and activeRole', () {
      final vendorUser = buildCapabilityUser(
        role: 'customer',
        activeRole: 'vendor',
        roles: const {'vendor': true},
      );
      final riderUser = buildCapabilityUser(
        role: 'customer',
        activeRole: 'rider',
        roles: const {'rider': true},
      );

      expect(hasVendorOperationsAccess(vendorUser), isTrue);
      expect(hasRiderOperationsAccess(riderUser), isTrue);
      expect(routeForUserInMode(vendorUser, AbzioAppMode.vendor), '/vendor-onboarding');
      expect(routeForUserInMode(riderUser, AbzioAppMode.rider), '/rider-onboarding');
    });

    test('routes rejected rider to rejected screen', () {
      final rejectedRider = AppUser(
        id: 'u3',
        name: 'Rejected Rider',
        email: 'rejected@example.com',
        role: 'rider',
        activeRole: 'rider',
        riderApprovalStatus: 'rejected',
        riderOnboarding: const {'status': 'rejected'},
      );

      expect(routeForUserInMode(rejectedRider, AbzioAppMode.rider), '/rider-rejected');
    });

    test('routes rejected vendor to rejected screen even with a store id', () {
      final rejectedVendor = AppUser(
        id: 'u4',
        name: 'Rejected Vendor',
        email: 'vendor@example.com',
        role: 'vendor',
        activeRole: 'vendor',
        storeId: 'store-1',
        vendorOnboarding: const {'status': 'rejected'},
      );

      expect(routeForUserInMode(rejectedVendor, AbzioAppMode.vendor), '/vendor-rejected');
      expect(routeForUserInMode(rejectedVendor, AbzioAppMode.operations), '/vendor-rejected');
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
      expect(accessRestrictionMessage(buildUser('customer'), AbzioAppMode.customer), isNull);
      expect(accessRestrictionMessage(buildUser('vendor'), AbzioAppMode.operations), isNull);
    });
  });
}
