import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/kyc_selfie_service.dart';
import '../../services/location_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/kyc_upload_widget.dart';
import '../../widgets/state_views.dart';
import 'live_selfie_verification_screen.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _picker = ImagePicker();
  final _onboardingService = OnboardingService();
  final _locationService = LocationService();
  final _kycSelfieService = const KycSelfieService();

  XFile? _ownerPhoto;
  XFile? _storePhoto;
  XFile? _aadhaarPhoto;
  XFile? _panPhoto;
  XFile? _selfiePhoto;
  double? _latitude;
  double? _longitude;
  bool _submitting = false;
  bool _detectingLocation = false;
  bool _verifyingSelfie = false;
  VendorKycRequest? _latestSubmission;
  KycVerificationSummary? _selfieVerification;
  String? _selfieUrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _ownerNameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
      _cityController.text = user.city ?? '';
      _latitude = user.latitude;
      _longitude = user.longitude;
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, void Function(XFile file) onPicked) async {
    final file = await _picker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
    if (file == null || !mounted) {
      return;
    }
    setState(() => onPicked(file));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _detectingLocation = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final location = await _locationService.getCurrentLocation(forceRefresh: true);
      if (location.status != LocationStatus.success || location.position == null) {
        throw StateError('Could not fetch current location. Please enter manually.');
      }
      final position = location.position!;
      final address = location.address ?? await _locationService.reverseGeocode(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address.address;
        _cityController.text = address.city;
      });
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  Future<void> _startLiveSelfieVerification() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || _ownerPhoto == null || _aadhaarPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Add owner photo and Aadhaar before starting live selfie verification.'),
        ),
      );
      return;
    }

    final result = await Navigator.push<LiveSelfieCheckResult>(
      context,
      MaterialPageRoute(builder: (_) => const LiveSelfieVerificationScreen()),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _verifyingSelfie = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final selfieFile = XFile(result.imagePath);
      final ownerPhotoUrl = await _onboardingService.uploadVendorOwnerPhoto(
        file: _ownerPhoto!,
        ownerId: user.id,
      );
      final aadhaarUrl = await _onboardingService.uploadVendorDocument(
        file: _aadhaarPhoto!,
        ownerId: user.id,
        label: 'aadhaar-face-ref',
      );
      final selfieUrl = await _onboardingService.uploadVendorSelfie(
        file: selfieFile,
        ownerId: user.id,
      );
      final verification = await _kycSelfieService.verifyLiveSelfie(
        selfieUrl: selfieUrl,
        ownerPhotoUrl: ownerPhotoUrl,
        aadhaarUrl: aadhaarUrl,
        livenessPassed: result.livenessPassed,
        livenessMode: result.livenessMode,
        retryCount: result.retryCount,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selfiePhoto = selfieFile;
        _selfieUrl = selfieUrl;
        _selfieVerification = verification;
      });
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            verification.faceVerified
                ? 'Live selfie verified successfully.'
                : verification.reviewSummary,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _verifyingSelfie = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_ownerPhoto == null || _storePhoto == null || _aadhaarPhoto == null || _panPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Owner photo, store image, Aadhaar, and PAN are all required.'),
        ),
      );
      return;
    }
    if (!(_selfieVerification?.livenessPassed ?? false) ||
        !(_selfieVerification?.faceVerified ?? false) ||
        _selfiePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Complete live selfie verification before submitting KYC.'),
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (_latitude == null || _longitude == null) {
        final geo = await _locationService.geocodeAddress(_addressController.text.trim());
        if (geo.status != AddressLookupStatus.success || geo.latitude == null || geo.longitude == null) {
          throw StateError('Please use a clearer address or current location to verify store coordinates.');
        }
        _latitude = geo.latitude;
        _longitude = geo.longitude;
      }

      final ownerPhotoUrl = await _onboardingService.uploadVendorOwnerPhoto(
        file: _ownerPhoto!,
        ownerId: user.id,
      );
      final storeImageUrl = await _onboardingService.uploadVendorStoreImage(
        file: _storePhoto!,
        ownerId: user.id,
      );
      final aadhaarUrl = await _onboardingService.uploadVendorDocument(
        file: _aadhaarPhoto!,
        ownerId: user.id,
        label: 'aadhaar',
      );
      final panUrl = await _onboardingService.uploadVendorDocument(
        file: _panPhoto!,
        ownerId: user.id,
        label: 'pan',
      );
      final selfieUrl = _selfieUrl ??
          await _onboardingService.uploadVendorSelfie(
            file: _selfiePhoto!,
            ownerId: user.id,
          );

      final nowIso = DateTime.now().toIso8601String();
      final submitted = await _onboardingService.submitVendorRequest(
        actor: user,
        request: VendorKycRequest(
          id: 'vendor-${user.id}',
          userId: user.id,
          storeName: _storeNameController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          kyc: KycDocuments(
            ownerPhotoUrl: ownerPhotoUrl,
            storeImageUrl: storeImageUrl,
            aadhaarUrl: aadhaarUrl,
            panUrl: panUrl,
            selfieUrl: selfieUrl,
          ),
          verification: _selfieVerification ?? const KycVerificationSummary(),
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );
      _latestSubmission = submitted;
      await auth.refreshCurrentUser();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            submitted.verification.autoReviewStatus == 'auto_verified'
                ? 'Documents verified with strong confidence. Your application is queued for fast approval.'
                : submitted.verification.autoReviewStatus == 'fraud_flagged'
                    ? 'Documents uploaded, but the system flagged them for manual review.'
                    : 'Your application is under review. We will notify you after KYC verification.',
          ),
        ),
      );
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening vendor onboarding',
          subtitle: 'Preparing your partner application.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Vendor KYC Onboarding')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Build your storefront with verified KYC.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit your store details, location, and KYC documents once. Our team will review and activate your vendor role.',
              style: TextStyle(color: Color(0xFF666666), height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5C56C)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB78610)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI-powered KYC check',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _latestSubmission == null
                              ? 'After upload, ABZORA extracts your Aadhaar and PAN details, validates formats, and fast-tracks strong submissions automatically.'
                              : _latestSubmission!.verification.reviewSummary,
                          style: const TextStyle(color: Color(0xFF6F6F6F), height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _detectingLocation ? null : _useCurrentLocation,
              icon: _detectingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(_detectingLocation ? 'Fetching location...' : 'Use Current Location'),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _storeNameController,
              decoration: const InputDecoration(labelText: 'Store name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Store name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ownerNameController,
              decoration: const InputDecoration(labelText: 'Owner name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Owner name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) => RegExp(r'^\+?\d{10,15}$').hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter a valid phone number',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 24),
            KycUploadWidget(
              title: 'Owner Photo',
              subtitle: 'Capture a clear portrait of the store owner.',
              file: _ownerPhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _ownerPhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _ownerPhoto = file),
            ),
            const SizedBox(height: 16),
            KycUploadWidget(
              title: 'Store Image',
              subtitle: 'Upload a clear storefront or in-store photo.',
              file: _storePhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _storePhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _storePhoto = file),
            ),
            const SizedBox(height: 16),
            KycUploadWidget(
              title: 'Aadhaar',
              subtitle: 'Upload the Aadhaar image for AI identity extraction and verification.',
              file: _aadhaarPhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _aadhaarPhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _aadhaarPhoto = file),
            ),
            const SizedBox(height: 16),
            KycUploadWidget(
              title: 'PAN',
              subtitle: 'Upload the PAN image for AI business KYC extraction and review.',
              file: _panPhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _panPhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _panPhoto = file),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8E8E8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live selfie verification',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Use the front camera only. Blink or turn your head slightly so ABZORA Partner can confirm you are the same person as the uploaded KYC documents.',
                    style: TextStyle(color: Color(0xFF6F6F6F), height: 1.4),
                  ),
                  if (_selfieVerification != null) ...[
                    const SizedBox(height: 12),
                    _ReviewBadge(
                      status: _selfieVerification!.faceVerified
                          ? 'auto_verified'
                          : 'pending_review',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Liveness: ${_selfieVerification!.livenessPassed ? 'Passed' : 'Failed'}'
                      ' • Match: ${_selfieVerification!.matchScore.toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selfieVerification!.reviewSummary,
                      style: const TextStyle(color: Color(0xFF6F6F6F)),
                    ),
                    if (_selfieVerification!.flags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _selfieVerification!.flags.join(' | '),
                        style: const TextStyle(color: Color(0xFF8A5A00), height: 1.45),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _verifyingSelfie ? null : _startLiveSelfieVerification,
                      icon: _verifyingSelfie
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _selfieVerification?.faceVerified == true
                                  ? Icons.verified_rounded
                                  : Icons.face_retouching_natural_rounded,
                            ),
                      label: Text(
                        _selfieVerification?.faceVerified == true
                            ? 'Retake Live Selfie'
                            : 'Start Live Selfie Check',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_latestSubmission != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Latest AI verification',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _ReviewBadge(status: _latestSubmission!.verification.autoReviewStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Name: ${_latestSubmission!.verification.extractedName.isEmpty ? 'Not extracted' : _latestSubmission!.verification.extractedName}'),
                    const SizedBox(height: 4),
                    Text('Aadhaar: ${_maskDocument(_latestSubmission!.verification.aadhaarNumber)}'),
                    const SizedBox(height: 4),
                    Text('PAN: ${_maskDocument(_latestSubmission!.verification.panNumber)}'),
                    const SizedBox(height: 4),
                    Text('Confidence: ${_latestSubmission!.verification.confidenceScore.toStringAsFixed(0)}%'),
                    if (_latestSubmission!.verification.flags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _latestSubmission!.verification.flags.join(' | '),
                        style: const TextStyle(color: Color(0xFF8A5A00), height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Vendor KYC'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskDocument(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Not extracted';
    }
    if (trimmed.length <= 4) {
      return trimmed;
    }
    return '${'*' * (trimmed.length - 4)}${trimmed.substring(trimmed.length - 4)}';
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'auto_verified' => ('Fast-track', const Color(0xFF1F8B4C)),
      'fraud_flagged' => ('Flagged', const Color(0xFFC13B2A)),
      _ => ('Review', const Color(0xFFB78610)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
