import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import 'database_service.dart';
import 'storage_service.dart';

class PartnerApplicationSnapshot {
  const PartnerApplicationSnapshot({
    this.vendorRequest,
    this.riderRequest,
  });

  final VendorKycRequest? vendorRequest;
  final RiderKycRequest? riderRequest;

  bool get hasPending =>
      vendorRequest?.status == 'pending' || riderRequest?.status == 'pending';
}

class OnboardingService {
  OnboardingService({
    DatabaseService? databaseService,
    StorageService? storageService,
  })  : _db = databaseService ?? DatabaseService(),
        _storage = storageService ?? StorageService();

  final DatabaseService _db;
  final StorageService _storage;

  Future<String> uploadVendorOwnerPhoto({
    required XFile file,
    required String ownerId,
  }) {
    return _storage.uploadPickedImage(
      file: file,
      folder: 'vendor_kyc_owner',
      ownerId: ownerId,
      fileName: 'owner-photo',
    );
  }

  Future<String> uploadVendorStoreImage({
    required XFile file,
    required String ownerId,
  }) {
    return _storage.uploadPickedImage(
      file: file,
      folder: 'vendor_kyc_store',
      ownerId: ownerId,
      fileName: 'store-image',
    );
  }

  Future<String> uploadVendorDocument({
    required XFile file,
    required String ownerId,
    required String label,
  }) {
    return _storage.uploadPickedImage(
      file: file,
      folder: 'vendor_kyc_docs',
      ownerId: ownerId,
      fileName: label,
    );
  }

  Future<String> uploadVendorSelfie({
    required XFile file,
    required String ownerId,
  }) {
    return _storage.uploadPickedImage(
      file: file,
      folder: 'vendor_kyc_selfie',
      ownerId: ownerId,
      fileName: 'selfie-live',
    );
  }

  Future<String> uploadRiderProfilePhoto({
    required XFile file,
    required String ownerId,
  }) {
    return _storage.uploadPickedImage(
      file: file,
      folder: 'rider_kyc_profile',
      ownerId: ownerId,
      fileName: 'profile-photo',
    );
  }

  Future<String> uploadRiderDocument({
    required XFile file,
    required String ownerId,
    required String label,
  }) {
    return _storage.uploadPickedImage(
      file: file,
      folder: 'rider_kyc_docs',
      ownerId: ownerId,
      fileName: label,
    );
  }

  Future<VendorKycRequest> submitVendorRequest({
    required AppUser actor,
    required VendorKycRequest request,
  }) {
    return _db.submitVendorKycRequest(request, actor: actor);
  }

  Future<void> submitRiderRequest({
    required AppUser actor,
    required RiderKycRequest request,
  }) {
    return _db.submitRiderKycRequest(request, actor: actor);
  }

  Future<VendorKycRequest?> getVendorRequestForUser(String userId) {
    return _db.getVendorKycRequestForUser(userId);
  }

  Future<RiderKycRequest?> getRiderRequestForUser(String userId) {
    return _db.getRiderKycRequestForUser(userId);
  }

  Future<PartnerApplicationSnapshot> getSnapshotForUser(String userId) async {
    final vendorRequest = await _db.getVendorKycRequestForUser(userId);
    final riderRequest = await _db.getRiderKycRequestForUser(userId);
    return PartnerApplicationSnapshot(
      vendorRequest: vendorRequest,
      riderRequest: riderRequest,
    );
  }

  Future<List<VendorKycRequest>> getVendorRequests({required AppUser actor}) {
    return _db.getVendorKycRequests(actor: actor);
  }

  Future<List<RiderKycRequest>> getRiderRequests({required AppUser actor}) {
    return _db.getRiderKycRequests(actor: actor);
  }

  Future<void> approveVendorRequest({
    required String requestId,
    required AppUser actor,
  }) {
    return _db.approveVendorKycRequest(requestId: requestId, actor: actor);
  }

  Future<void> rejectVendorRequest({
    required String requestId,
    required String reason,
    required AppUser actor,
  }) {
    return _db.rejectVendorKycRequest(
      requestId: requestId,
      reason: reason,
      actor: actor,
    );
  }

  Future<void> approveRiderRequest({
    required String requestId,
    required AppUser actor,
  }) {
    return _db.approveRiderKycRequest(requestId: requestId, actor: actor);
  }

  Future<void> rejectRiderRequest({
    required String requestId,
    required String reason,
    required AppUser actor,
  }) {
    return _db.rejectRiderKycRequest(
      requestId: requestId,
      reason: reason,
      actor: actor,
    );
  }
}
