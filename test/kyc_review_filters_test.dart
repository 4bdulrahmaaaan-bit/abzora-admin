import 'package:abzio/models/models.dart';
import 'package:abzio/screens/admin/kyc_review_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VendorKycRequest vendor({
    required String id,
    required String name,
    required String city,
    required String status,
    required String updatedAt,
  }) {
    return VendorKycRequest(
      id: id,
      userId: 'u-$id',
      storeName: 'Store $id',
      ownerName: name,
      phone: '9999999999',
      address: 'Address $id',
      city: city,
      latitude: 12.0,
      longitude: 80.0,
      kyc: const KycDocuments(),
      status: status,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  RiderKycRequest rider({
    required String id,
    required String name,
    required String city,
    required String status,
    required String updatedAt,
  }) {
    return RiderKycRequest(
      id: id,
      userId: 'u-$id',
      name: name,
      phone: '8888888888',
      vehicle: 'Bike',
      city: city,
      kyc: const KycDocuments(),
      status: status,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  test('filters vendor and rider requests by tab', () {
    final results = filterKycReviewEntries(
      vendors: [
        vendor(
          id: 'vendor-1',
          name: 'Ayaan',
          city: 'Chennai',
          status: 'pending',
          updatedAt: '2026-03-27T10:00:00.000Z',
        ),
      ],
      riders: [
        rider(
          id: 'rider-1',
          name: 'Kabir',
          city: 'Bengaluru',
          status: 'approved',
          updatedAt: '2026-03-27T09:00:00.000Z',
        ),
      ],
      tab: KycRequestFilterTab.vendor,
    );

    expect(results, hasLength(1));
    expect(results.first.roleLabel, 'Vendor');
    expect(results.first.name, 'Ayaan');
  });

  test('filters requests by status, search, and city', () {
    final results = filterKycReviewEntries(
      vendors: [
        vendor(
          id: 'vendor-1',
          name: 'Ayaan Kumar',
          city: 'Chennai',
          status: 'pending',
          updatedAt: '2026-03-27T10:00:00.000Z',
        ),
        vendor(
          id: 'vendor-2',
          name: 'Riya',
          city: 'Mumbai',
          status: 'approved',
          updatedAt: '2026-03-27T08:00:00.000Z',
        ),
      ],
      riders: [
        rider(
          id: 'rider-1',
          name: 'Kabir',
          city: 'Chennai',
          status: 'pending',
          updatedAt: '2026-03-27T09:00:00.000Z',
        ),
      ],
      tab: KycRequestFilterTab.pending,
      searchQuery: 'ayaan',
      cityQuery: 'chen',
    );

    expect(results, hasLength(1));
    expect(results.first.id, 'vendor-1');
  });

  test('sorts newest requests first across roles', () {
    final results = filterKycReviewEntries(
      vendors: [
        vendor(
          id: 'vendor-1',
          name: 'Older Vendor',
          city: 'Chennai',
          status: 'pending',
          updatedAt: '2026-03-27T08:00:00.000Z',
        ),
      ],
      riders: [
        rider(
          id: 'rider-1',
          name: 'New Rider',
          city: 'Delhi',
          status: 'pending',
          updatedAt: '2026-03-27T11:00:00.000Z',
        ),
      ],
      tab: KycRequestFilterTab.all,
    );

    expect(results, hasLength(2));
    expect(results.first.id, 'rider-1');
    expect(results.last.id, 'vendor-1');
  });
}
