import 'package:abzio/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('copyWith helpers', () {
    test('AppUser copyWith preserves existing location and metadata', () {
      final user = AppUser(
        id: 'u1',
        name: 'Riya',
        email: 'riya@example.com',
        phone: '+911234567890',
        address: 'Anna Nagar, Chennai',
        latitude: 13.08,
        longitude: 80.27,
        createdAt: '2026-03-26T10:00:00.000Z',
        role: 'user',
        isActive: true,
        storeId: null,
        walletBalance: 0,
      );

      final updated = user.copyWith(role: 'vendor', storeId: 's1');

      expect(updated.latitude, 13.08);
      expect(updated.longitude, 80.27);
      expect(updated.createdAt, '2026-03-26T10:00:00.000Z');
      expect(updated.role, 'vendor');
      expect(updated.storeId, 's1');
    });

    test('Store copyWith preserves geo fields and category', () {
      final store = Store(
        id: 's1',
        storeId: 's1',
        ownerId: 'u1',
        name: 'Mizaj',
        description: 'Luxury tailoring',
        imageUrl: 'https://example.com/logo.jpg',
        rating: 4.8,
        reviewCount: 10,
        address: 'Bangalore',
        isApproved: true,
        isActive: true,
        isFeatured: true,
        logoUrl: 'https://example.com/logo.jpg',
        bannerImageUrl: 'https://example.com/banner.jpg',
        tagline: 'Bespoke wear',
        commissionRate: 0.12,
        walletBalance: 5000,
        latitude: 12.97,
        longitude: 77.59,
        category: 'Tailoring',
      );

      final updated = store.copyWith(walletBalance: 7000);

      expect(updated.storeId, 's1');
      expect(updated.latitude, 12.97);
      expect(updated.longitude, 77.59);
      expect(updated.category, 'Tailoring');
      expect(updated.walletBalance, 7000);
    });
  });
}
