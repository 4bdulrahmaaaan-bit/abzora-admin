import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/kyc_upload_widget.dart';
import '../../widgets/state_views.dart';

class RiderFormScreen extends StatefulWidget {
  const RiderFormScreen({super.key});

  @override
  State<RiderFormScreen> createState() => _RiderFormScreenState();
}

class _RiderFormScreenState extends State<RiderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController(text: 'Bike');
  final _cityController = TextEditingController();
  final _picker = ImagePicker();
  final _onboardingService = OnboardingService();

  XFile? _profilePhoto;
  XFile? _aadhaarPhoto;
  XFile? _licensePhoto;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _cityController.text = user.riderCity ?? user.city ?? '';
      _vehicleController.text = user.riderVehicleType ?? 'Bike';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_profilePhoto == null || _aadhaarPhoto == null || _licensePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Profile photo, Aadhaar, and driving license are required.'),
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
      final profileUrl = await _onboardingService.uploadRiderProfilePhoto(
        file: _profilePhoto!,
        ownerId: user.id,
      );
      final aadhaarUrl = await _onboardingService.uploadRiderDocument(
        file: _aadhaarPhoto!,
        ownerId: user.id,
        label: 'aadhaar',
      );
      final licenseUrl = await _onboardingService.uploadRiderDocument(
        file: _licensePhoto!,
        ownerId: user.id,
        label: 'license',
      );
      final nowIso = DateTime.now().toIso8601String();
      await _onboardingService.submitRiderRequest(
        actor: user,
        request: RiderKycRequest(
          id: 'rider-${user.id}',
          userId: user.id,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          vehicle: _vehicleController.text.trim(),
          city: _cityController.text.trim(),
          kyc: KycDocuments(
            profilePhotoUrl: profileUrl,
            aadhaarUrl: aadhaarUrl,
            licenseUrl: licenseUrl,
          ),
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );
      await auth.refreshCurrentUser();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Your application is under review. We will notify you after KYC verification.'),
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
          title: 'Opening rider onboarding',
          subtitle: 'Preparing your delivery partner verification flow.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Rider KYC Onboarding')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Get delivery-ready with verified KYC.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit your rider details and documents once. Admin approval unlocks live delivery requests.',
              style: TextStyle(color: Color(0xFF666666), height: 1.45),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Name is required' : null,
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
              controller: _vehicleController,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Vehicle type is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 24),
            KycUploadWidget(
              title: 'Profile Photo',
              subtitle: 'Upload a clear rider profile photo.',
              file: _profilePhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _profilePhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _profilePhoto = file),
            ),
            const SizedBox(height: 16),
            KycUploadWidget(
              title: 'Aadhaar',
              subtitle: 'Upload the Aadhaar image for identity verification.',
              file: _aadhaarPhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _aadhaarPhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _aadhaarPhoto = file),
            ),
            const SizedBox(height: 16),
            KycUploadWidget(
              title: 'Driving License',
              subtitle: 'Upload the driving license image for rider verification.',
              file: _licensePhoto,
              onPickCamera: () => _pickImage(ImageSource.camera, (file) => _licensePhoto = file),
              onPickGallery: () => _pickImage(ImageSource.gallery, (file) => _licensePhoto = file),
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
                    : const Text('Submit Rider KYC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
