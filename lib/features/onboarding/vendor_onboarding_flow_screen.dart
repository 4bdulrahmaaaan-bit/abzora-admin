import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/services/vendor_telemetry.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/state_views.dart';

class VendorOnboardingFlowScreen extends StatefulWidget {
  const VendorOnboardingFlowScreen({super.key});

  @override
  State<VendorOnboardingFlowScreen> createState() =>
      _VendorOnboardingFlowScreenState();
}

class _VendorOnboardingFlowScreenState
    extends State<VendorOnboardingFlowScreen> {
  final _pageController = PageController();
  final _onboarding = OnboardingService();
  final _db = DatabaseService();
  final _location = LocationService();
  final _picker = ImagePicker();
  int _step = 0;
  bool _submitting = false;

  final _storeName = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _experienceYears = TextEditingController();
  final _startingPrice = TextEditingController();
  final _upperPrice = TextEditingController();
  final _productionDays = TextEditingController(text: '7');
  final _payout = TextEditingController();

  final Set<String> _specializations = <String>{};
  XFile? _ownerPhoto;
  XFile? _storePhoto;
  XFile? _aadhaarPhoto;
  XFile? _panPhoto;
  final List<String> _portfolioPaths = <String>[];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _ownerName.text = user.name;
      _phone.text = user.phone ?? '';
      _email.text = user.email;
      _address.text = user.address ?? '';
      _city.text = user.city ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _storeName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _experienceYears.dispose();
    _startingPrice.dispose();
    _upperPrice.dispose();
    _productionDays.dispose();
    _payout.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile) onPicked) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => onPicked(file));
  }

  Future<void> _pickPortfolio() async {
    final files = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (files == null) return;
    setState(() {
      for (final f in files.files) {
        final path = f.path;
        if (path != null && _portfolioPaths.length < 10) {
          _portfolioPaths.add(path);
        }
      }
    });
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_storeName.text.trim().isEmpty) return 'Store name is required';
      if (_ownerName.text.trim().isEmpty) return 'Owner name is required';
      if (_phone.text.trim().length < 10) return 'Valid phone is required';
      final email = _email.text.trim();
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        return 'Valid email is required';
      }
      if (_address.text.trim().isEmpty) return 'Address is required';
      if (_city.text.trim().isEmpty) return 'City is required';
    }
    if (_step == 1 && _specializations.isEmpty) {
      return 'Choose at least one specialization';
    }
    if (_step == 2 && _portfolioPaths.length < 5) {
      return 'Upload at least 5 portfolio samples';
    }
    if (_step == 3) {
      final start = double.tryParse(_startingPrice.text.trim()) ?? 0;
      final upper = double.tryParse(_upperPrice.text.trim()) ?? 0;
      final days = int.tryParse(_productionDays.text.trim()) ?? 0;
      if (start <= 0) {
        return 'Starting price must be greater than zero';
      }
      if (upper < start) {
        return 'Upper range must be greater than starting price';
      }
      if (days <= 0 || days > 60) {
        return 'Production days must be between 1 and 60';
      }
    }
    if (_step == 4 &&
        (_ownerPhoto == null ||
            _storePhoto == null ||
            _aadhaarPhoto == null ||
            _panPhoto == null)) {
      return 'Owner, store, Aadhaar and PAN images are required';
    }
    return null;
  }

  void _next() {
    final error = _validateStep();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_step < 5) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      VendorTelemetry.event('submit_started', data: {'userId': user.id});
      final ownerPhotoUrl = await _onboarding.uploadVendorOwnerPhoto(
        file: _ownerPhoto!,
        ownerId: user.id,
      );
      final storePhotoUrl = await _onboarding.uploadVendorStoreImage(
        file: _storePhoto!,
        ownerId: user.id,
      );
      final aadhaarUrl = await _onboarding.uploadVendorDocument(
        file: _aadhaarPhoto!,
        ownerId: user.id,
        label: 'aadhaar',
      );
      final panUrl = await _onboarding.uploadVendorDocument(
        file: _panPhoto!,
        ownerId: user.id,
        label: 'pan',
      );
      final portfolioUrls = <String>[];
      for (var i = 0; i < _portfolioPaths.length; i++) {
        final url = await _onboarding.uploadVendorDocument(
          file: XFile(_portfolioPaths[i]),
          ownerId: user.id,
          label: 'portfolio-$i',
        );
        portfolioUrls.add(url);
      }

      final nowIso = DateTime.now().toIso8601String();
      var latitude = user.latitude;
      var longitude = user.longitude;
      if (latitude == null || longitude == null) {
        final geo = await _location.geocodeAddress(_address.text.trim());
        if (geo.status == AddressLookupStatus.success &&
            geo.latitude != null &&
            geo.longitude != null) {
          latitude = geo.latitude;
          longitude = geo.longitude;
        }
      }

      await _onboarding.submitVendorRequest(
        actor: user,
        request: VendorKycRequest(
          id: 'vendor-${user.id}',
          userId: user.id,
          storeName: _storeName.text.trim(),
          ownerName: _ownerName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          latitude: latitude ?? 0,
          longitude: longitude ?? 0,
          vendorType: 'custom_vendor',
          experienceYears: int.tryParse(_experienceYears.text.trim()) ?? 0,
          specializations: _specializations.toList(),
          portfolioImageUrls: portfolioUrls,
          startingPrice: double.tryParse(_startingPrice.text.trim()) ?? 0,
          typicalPriceUpper: double.tryParse(_upperPrice.text.trim()) ?? 0,
          productionTimeDays: int.tryParse(_productionDays.text.trim()) ?? 7,
          payoutSetupLabel: _payout.text.trim(),
          kyc: KycDocuments(
            ownerPhotoUrl: ownerPhotoUrl,
            storeImageUrl: storePhotoUrl,
            aadhaarUrl: aadhaarUrl,
            panUrl: panUrl,
          ),
          metadata: {
            'submittedAt': nowIso,
            'source': 'vendor_flow_v2',
            'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
            'specializations': _specializations.toList(),
            'startingPrice': double.tryParse(_startingPrice.text.trim()) ?? 0,
            'typicalPriceUpper': double.tryParse(_upperPrice.text.trim()) ?? 0,
            'productionTimeDays':
                int.tryParse(_productionDays.text.trim()) ?? 7,
          },
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );

      if (_payout.text.trim().isNotEmpty) {
        final value = _payout.text.trim();
        if (!value.contains('@') && value.length < 8) {
          throw StateError('Enter a valid UPI ID or bank account number');
        }
        try {
          await _db.saveVendorPayoutProfile(
            actor: user,
            methodType: value.contains('@') ? 'upi' : 'bank',
            accountHolderName: _ownerName.text.trim(),
            upiId: value.contains('@') ? value : '',
            bankAccountNumber: value.contains('@') ? '' : value,
            bankIfsc: '',
            bankName: '',
          );
        } catch (error) {
          VendorTelemetry.event(
            'payout_save_failed_post_submit',
            data: {'error': error.toString()},
          );
        }
      }
      await auth.refreshCurrentUser();
      VendorTelemetry.event('submit_success', data: {'userId': user.id});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const _VendorOnboardingSuccessScreen(),
        ),
      );
    } catch (error) {
      VendorTelemetry.event('submit_failed', data: {'error': error.toString()});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      appBar: AppBar(title: Text('Vendor Onboarding ${_step + 1}/6')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LinearProgressIndicator(value: (_step + 1) / 6),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _card('Business Basics', [
                  _field(_storeName, 'Store Name'),
                  _field(_ownerName, 'Owner Name'),
                  _field(_phone, 'Phone'),
                  _field(_email, 'Email'),
                  _field(_address, 'Address', maxLines: 2),
                  _field(_city, 'City'),
                ]),
                _card('Craft & Expertise', [
                  _field(_experienceYears, 'Experience (years)'),
                  Wrap(
                    spacing: 8,
                    children: ['Shirts', 'Blazers', 'Dresses', 'Ethnic']
                        .map(
                          (item) => FilterChip(
                            label: Text(item),
                            selected: _specializations.contains(item),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _specializations.add(item);
                                } else {
                                  _specializations.remove(item);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ]),
                _card('Portfolio Uploads', [
                  Text('Uploaded: ${_portfolioPaths.length}/10'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickPortfolio,
                    child: const Text('Add Portfolio Files'),
                  ),
                ]),
                _card('Pricing & Capacity', [
                  _field(_startingPrice, 'Starting Price (Rs)'),
                  _field(_upperPrice, 'Typical Upper Range (Rs)'),
                  _field(_productionDays, 'Production Days'),
                  _field(_payout, 'UPI or Bank Account Number'),
                ]),
                _card('KYC Documents', [
                  _uploadTile(
                    'Owner Photo',
                    _ownerPhoto != null,
                    () => _pickImage((x) => _ownerPhoto = x),
                  ),
                  _uploadTile(
                    'Store Photo',
                    _storePhoto != null,
                    () => _pickImage((x) => _storePhoto = x),
                  ),
                  _uploadTile(
                    'Aadhaar',
                    _aadhaarPhoto != null,
                    () => _pickImage((x) => _aadhaarPhoto = x),
                  ),
                  _uploadTile(
                    'PAN',
                    _panPhoto != null,
                    () => _pickImage((x) => _panPhoto = x),
                  ),
                ]),
                _card('Review & Submit', [
                  Text('Store: ${_storeName.text.trim()}'),
                  Text('City: ${_city.text.trim()}'),
                  Text('Specializations: ${_specializations.join(', ')}'),
                  Text('Portfolio: ${_portfolioPaths.length} files'),
                  const SizedBox(height: 10),
                  const Text(
                    'Your application will be reviewed after document checks.',
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _next,
                child: Text(
                  _step == 5
                      ? (_submitting ? 'Submitting...' : 'Submit Application')
                      : 'Continue',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _uploadTile(String label, bool done, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(done ? 'Uploaded' : 'Not uploaded'),
      trailing: TextButton(onPressed: onTap, child: const Text('Upload')),
    );
  }
}

class _VendorOnboardingSuccessScreen extends StatelessWidget {
  const _VendorOnboardingSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Vendor Application Submitted',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'We will notify you after KYC and quality review.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/ops', (route) => false),
                child: const Text('Go to Vendor Workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
