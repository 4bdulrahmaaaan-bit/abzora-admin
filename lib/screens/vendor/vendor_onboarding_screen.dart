import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/kyc_upload_widget.dart';
import '../../widgets/state_views.dart';

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
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _experienceController = TextEditingController();
  final _startingPriceController = TextEditingController();
  final _typicalPriceController = TextEditingController();
  final _ordersPerDayController = TextEditingController();
  final _productionDaysController = TextEditingController(text: '7');
  final _bankSetupController = TextEditingController();
  final _picker = ImagePicker();
  final _onboardingService = OnboardingService();
  final _locationService = LocationService();

  XFile? _ownerPhoto;
  XFile? _storePhoto;
  XFile? _aadhaarPhoto;
  XFile? _panPhoto;
  final List<XFile> _portfolioFiles = <XFile>[];
  final Set<String> _specializations = <String>{};
  double? _latitude;
  double? _longitude;
  bool _submitting = false;
  bool _detectingLocation = false;
  VendorKycRequest? _latestSubmission;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _ownerNameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email;
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
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _experienceController.dispose();
    _startingPriceController.dispose();
    _typicalPriceController.dispose();
    _ordersPerDayController.dispose();
    _productionDaysController.dispose();
    _bankSetupController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, void Function(XFile file) onPicked) async {
    final file = await _picker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
    if (file == null || !mounted) {
      return;
    }
    setState(() => onPicked(file));
  }

  Future<void> _addPortfolioImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1800);
    if (files.isEmpty || !mounted) {
      return;
    }
    setState(() {
      final remaining = 10 - _portfolioFiles.length;
      _portfolioFiles.addAll(files.take(remaining));
    });
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
    if (_specializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Choose at least one specialization.'),
        ),
      );
      return;
    }
    if (_portfolioFiles.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Upload at least 5 portfolio samples.'),
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
      final portfolioUrls = <String>[];
      for (var i = 0; i < _portfolioFiles.length; i++) {
        final url = await _onboardingService.uploadVendorDocument(
          file: _portfolioFiles[i],
          ownerId: user.id,
          label: 'portfolio-$i',
        );
        portfolioUrls.add(url);
      }

      final nowIso = DateTime.now().toIso8601String();
      final submitted = await _onboardingService.submitVendorRequest(
        actor: user,
        request: VendorKycRequest(
          id: 'vendor-${user.id}',
          userId: user.id,
          storeName: _storeNameController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          vendorType: 'custom_vendor',
          experienceYears: int.tryParse(_experienceController.text.trim()) ?? 0,
          specializations: _specializations.toList(),
          portfolioImageUrls: portfolioUrls,
          startingPrice: double.tryParse(_startingPriceController.text.trim()) ?? 0,
          typicalPriceUpper: double.tryParse(_typicalPriceController.text.trim()) ?? 0,
          ordersPerDay: int.tryParse(_ordersPerDayController.text.trim()) ?? 0,
          productionTimeDays: int.tryParse(_productionDaysController.text.trim()) ?? 7,
          payoutSetupLabel: _bankSetupController.text.trim(),
          kyc: KycDocuments(
            ownerPhotoUrl: ownerPhotoUrl,
            storeImageUrl: storeImageUrl,
            aadhaarUrl: aadhaarUrl,
            panUrl: panUrl,

          ),
          verification: const KycVerificationSummary(),
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
      appBar: AppBar(title: const Text('Custom Designer Onboarding')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Join as a Custom Designer',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create made-to-measure outfits for customers with a premium onboarding flow built for tailoring studios and designers.',
              style: TextStyle(color: Color(0xFF666666), height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START ONBOARDING',
                    style: TextStyle(
                      color: Color(0xFFE3C377),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Luxury boutique + digital tailoring studio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share your craft, portfolio, pricing, production capacity, and bank setup. Customers trust what they can clearly see.',
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
            _sectionTitle('Basic details'),
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
              decoration: const InputDecoration(labelText: 'Store / Designer name'),
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
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
            _sectionTitle('Experience'),
            TextFormField(
              controller: _experienceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years of experience'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['Shirts', 'Blazers', 'Dresses', 'Ethnic wear'].map((item) {
                final selected = _specializations.contains(item);
                return FilterChip(
                  selected: selected,
                  label: Text(item),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _specializations.add(item);
                      } else {
                        _specializations.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Portfolio upload'),
            const Text(
              'Your designs help customers trust you. Upload 5-10 sample works.',
              style: TextStyle(color: Color(0xFF666666), height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _portfolioFiles.length >= 10 ? null : _addPortfolioImages,
              icon: const Icon(Icons.collections_rounded),
              label: Text(
                _portfolioFiles.isEmpty
                    ? 'Upload sample works'
                    : 'Add more samples (${_portfolioFiles.length}/10)',
              ),
            ),
            if (_portfolioFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(_portfolioFiles.length, (index) {
                  return Stack(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFFF5F0E2),
                          border: Border.all(color: const Color(0xFFE5D7B2)),
                        ),
                        child: const Icon(Icons.checkroom_rounded, color: Color(0xFF9C7A2C)),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => setState(() => _portfolioFiles.removeAt(index)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black87,
                            child: Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
            const SizedBox(height: 24),
            _sectionTitle('Pricing range'),
            TextFormField(
              controller: _startingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Starting price (₹)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _typicalPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Typical upper range (₹)'),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Production capacity'),
            TextFormField(
              controller: _ordersPerDayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Orders per day'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productionDaysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Delivery time (days)'),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Bank setup'),
            TextFormField(
              controller: _bankSetupController,
              decoration: const InputDecoration(
                labelText: 'RazorpayX / UPI / Bank details',
                hintText: 'UPI / Bank setup label for approval review',
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Verification documents'),
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
            _sectionTitle('Review'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9EA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5C56C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submit for approval', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Specializations: ${_specializations.isEmpty ? 'Not selected' : _specializations.join(', ')}'),
                  Text('Portfolio uploads: ${_portfolioFiles.length}/10'),
                  Text('Production time: ${_productionDaysController.text.trim().isEmpty ? '-' : _productionDaysController.text.trim()} days'),
                  Text('Payout setup: ${_bankSetupController.text.trim().isEmpty ? 'Pending' : _bankSetupController.text.trim()}'),
                ],
              ),
            ),
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
                    : const Text('Submit for Approval'),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
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

