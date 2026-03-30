import '../../models/models.dart';

enum KycRequestFilterTab {
  all,
  vendor,
  rider,
  pending,
  approved,
  rejected,
  highPriority,
}

class KycReviewEntry {
  const KycReviewEntry.vendor(this.vendorRequest)
      : riderRequest = null,
        roleLabel = 'Vendor';

  const KycReviewEntry.rider(this.riderRequest)
      : vendorRequest = null,
        roleLabel = 'Rider';

  final VendorKycRequest? vendorRequest;
  final RiderKycRequest? riderRequest;
  final String roleLabel;

  String get id => vendorRequest?.id ?? riderRequest!.id;
  String get status => vendorRequest?.status ?? riderRequest!.status;
  String get name => vendorRequest?.ownerName ?? riderRequest!.name;
  String get phone => vendorRequest?.phone ?? riderRequest!.phone;
  String get city => vendorRequest?.city ?? riderRequest!.city;
  String get updatedAt => vendorRequest?.updatedAt ?? riderRequest!.updatedAt;
  List<String> get missingDocuments {
    if (vendorRequest != null) {
      final kyc = vendorRequest!.kyc;
      return [
        if (kyc.ownerPhotoUrl.trim().isEmpty) 'Missing photo',
        if (kyc.storeImageUrl.trim().isEmpty) 'Missing store image',
        if (kyc.aadhaarUrl.trim().isEmpty) 'Missing Aadhaar',
        if (kyc.panUrl.trim().isEmpty) 'Missing PAN',
      ];
    }
    final kyc = riderRequest!.kyc;
    return [
      if (kyc.profilePhotoUrl.trim().isEmpty) 'Missing photo',
      if (kyc.aadhaarUrl.trim().isEmpty) 'Missing Aadhaar',
      if (kyc.licenseUrl.trim().isEmpty) 'Missing license',
    ];
  }

  bool hasMissingDocuments() => missingDocuments.isNotEmpty;
}

List<KycReviewEntry> filterKycReviewEntries({
  required List<VendorKycRequest> vendors,
  required List<RiderKycRequest> riders,
  required KycRequestFilterTab tab,
  String searchQuery = '',
  String cityQuery = '',
  bool todaysOnly = false,
  bool missingDocumentsOnly = false,
}) {
  final query = searchQuery.trim().toLowerCase();
  final normalizedCity = cityQuery.trim().toLowerCase();

  bool matchesTab({required String role, required String status}) {
    switch (tab) {
      case KycRequestFilterTab.all:
        return true;
      case KycRequestFilterTab.vendor:
        return role == 'Vendor';
      case KycRequestFilterTab.rider:
        return role == 'Rider';
      case KycRequestFilterTab.pending:
        return status == 'pending';
      case KycRequestFilterTab.approved:
        return status == 'approved';
      case KycRequestFilterTab.rejected:
        return status == 'rejected';
      case KycRequestFilterTab.highPriority:
        return status == 'pending';
    }
  }

  bool isToday(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final today = DateTime.now().toIso8601String().split('T').first;
    return normalized.startsWith(today);
  }

  bool matchesCommon({
    required String role,
    required String status,
    required String name,
    required String phone,
    required String city,
  }) {
    final haystack = '$name $phone $city'.toLowerCase();
    final matchesSearch = query.isEmpty || haystack.contains(query);
    final matchesCity = normalizedCity.isEmpty || city.toLowerCase().contains(normalizedCity);
    return matchesTab(role: role, status: status) && matchesSearch && matchesCity;
  }

  final items = <KycReviewEntry>[
    ...vendors
        .where(
          (request) => matchesCommon(
            role: 'Vendor',
            status: request.status,
            name: request.ownerName,
            phone: request.phone,
            city: request.city,
          ),
        )
        .map(KycReviewEntry.vendor)
        .where((entry) {
          final duplicates = [...vendors.map((item) => item.phone), ...riders.map((item) => item.phone)]
                  .where((phone) => phone.trim() == entry.phone.trim())
                  .length >
              1;
          final highPriorityMatch = tab != KycRequestFilterTab.highPriority ||
              entry.hasMissingDocuments() ||
              duplicates ||
              requestRejectedRecently(entry);
          final todayMatch = !todaysOnly || isToday(entry.updatedAt);
          final missingMatch = !missingDocumentsOnly || entry.hasMissingDocuments();
          return highPriorityMatch && todayMatch && missingMatch;
        }),
    ...riders
        .where(
          (request) => matchesCommon(
            role: 'Rider',
            status: request.status,
            name: request.name,
            phone: request.phone,
            city: request.city,
          ),
        )
        .map(KycReviewEntry.rider)
        .where((entry) {
          final duplicates = [...vendors.map((item) => item.phone), ...riders.map((item) => item.phone)]
                  .where((phone) => phone.trim() == entry.phone.trim())
                  .length >
              1;
          final highPriorityMatch = tab != KycRequestFilterTab.highPriority ||
              entry.hasMissingDocuments() ||
              duplicates ||
              requestRejectedRecently(entry);
          final todayMatch = !todaysOnly || isToday(entry.updatedAt);
          final missingMatch = !missingDocumentsOnly || entry.hasMissingDocuments();
          return highPriorityMatch && todayMatch && missingMatch;
        }),
  ];

  items.sort((a, b) {
    final aPriority = _priorityScore(a, vendors: vendors, riders: riders);
    final bPriority = _priorityScore(b, vendors: vendors, riders: riders);
    final priorityCompare = bPriority.compareTo(aPriority);
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    final pendingCompare = (a.status == 'pending' ? 1 : 0).compareTo(b.status == 'pending' ? 1 : 0);
    if (pendingCompare != 0) {
      return -pendingCompare;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return items;
}

bool requestRejectedRecently(KycReviewEntry entry) => entry.status == 'rejected';

int _priorityScore(
  KycReviewEntry entry, {
  required List<VendorKycRequest> vendors,
  required List<RiderKycRequest> riders,
}) {
  final duplicatePhone = [...vendors.map((item) => item.phone), ...riders.map((item) => item.phone)]
          .where((phone) => phone.trim() == entry.phone.trim())
          .length >
      1;
  var score = 0;
  if (entry.status == 'pending') {
    score += 4;
  }
  if (entry.hasMissingDocuments()) {
    score += 3;
  }
  if (duplicatePhone) {
    score += 2;
  }
  if (requestRejectedRecently(entry)) {
    score += 1;
  }
  return score;
}
