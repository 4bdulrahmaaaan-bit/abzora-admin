import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/address_form_widget.dart';
import '../../widgets/state_views.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _database = DatabaseService();
  final _locationService = LocationService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _houseController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _localityController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _pincodeFocusNode = FocusNode();
  final _houseFocusNode = FocusNode();
  final _landmarkFocusNode = FocusNode();
  final _localityFocusNode = FocusNode();

  List<UserAddress> _savedAddresses = const [];
  Timer? _pincodeDebounce;

  bool _isExpanded = false;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  bool _isAutoFillingProfile = false;
  bool _isLoadingAddresses = true;
  bool _isPincodeLookupLoading = false;
  bool _nameAutoFilled = false;
  bool _addressAutoFilled = false;
  bool _didRunAutoFill = false;
  String _addressType = 'home';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _pincodeController.addListener(_handlePincodeChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _seedFromCurrentUser();
      _loadSavedAddresses();
      unawaited(_autoFillProfileSetup());
    });
  }

  void _seedFromCurrentUser() {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    _nameController.text = _cleanName(user.name);
    _phoneController.text = user.phone ?? '';
    _cityController.text = user.city ?? '';
    _latitude = user.latitude;
    _longitude = user.longitude;

    final parsed = _parseAddress(user.address ?? '');
    _addressController.text = _cleanAddressLine(parsed.addressLine);
    _houseController.clear();
    _landmarkController.clear();
    _localityController.text = _cleanSegment(user.area ?? parsed.locality);
    _stateController.text = _cleanSegment(parsed.state);
    _pincodeController.text = parsed.pincode;

    if (_houseController.text.isNotEmpty || _landmarkController.text.isNotEmpty || _localityController.text.isNotEmpty) {
      _isExpanded = true;
    }
  }

  Future<void> _autoFillProfileSetup() async {
    if (_didRunAutoFill) {
      return;
    }
    _didRunAutoFill = true;
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    if (mounted) {
      setState(() => _isAutoFillingProfile = true);
    }

    final resolvedName = _preferredAutoFillName(user);
    final shouldFillName = _nameController.text.trim().isEmpty || _nameController.text.trim() == user.phone?.trim();
    if (shouldFillName && resolvedName.isNotEmpty) {
      _nameController.text = resolvedName;
      _nameAutoFilled = true;
    }

    final shouldFetchAddress = _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty;

    if (shouldFetchAddress) {
      final result = await _locationService.getCurrentLocation(forceRefresh: false);
      if (!mounted) {
        return;
      }
      if (result.status == LocationStatus.success && result.position != null) {
        final address = result.address ??
            await _locationService.reverseGeocode(
              result.position!.latitude,
              result.position!.longitude,
            );
        _applyResolvedAddress(
          address: address,
          latitude: result.position!.latitude,
          longitude: result.position!.longitude,
          markAutoFilled: true,
        );
      }
    }

    if (mounted) {
      setState(() => _isAutoFillingProfile = false);
    }
  }

  Future<void> _loadSavedAddresses() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoadingAddresses = false);
      return;
    }

    try {
      final addresses = await _database.getUserAddresses(user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses = addresses;
        _isLoadingAddresses = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingAddresses = false);
    }
  }

  void _handlePincodeChange() {
    final pincode = _pincodeController.text.trim();
    _pincodeDebounce?.cancel();
    if (pincode.length != 6) {
      if (_isPincodeLookupLoading) {
        setState(() => _isPincodeLookupLoading = false);
      }
      return;
    }

    _pincodeDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) {
        return;
      }
      setState(() => _isPincodeLookupLoading = true);
      final result = await _locationService.lookupByPincode(pincode);
      if (!mounted) {
        return;
      }
      setState(() => _isPincodeLookupLoading = false);
      if (result == null) {
        return;
      }

      _cityController.text = result.city;
      _stateController.text = result.state;
      if (_localityController.text.trim().isEmpty && result.area.trim().isNotEmpty) {
        _localityController.text = result.area;
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    FocusScope.of(context).unfocus();
    setState(() => _isFetchingLocation = true);

    final result = await _locationService.getCurrentLocation(forceRefresh: true);
    if (!mounted) {
      return;
    }

    setState(() => _isFetchingLocation = false);

    if (result.status != LocationStatus.success || result.position == null || result.address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Couldn\'t fetch location. Please enter manually'),
        ),
      );
      return;
    }

    final address = result.address!;
    final position = result.position!;
    _applyResolvedAddress(
      address: address,
      latitude: position.latitude,
      longitude: position.longitude,
      markAutoFilled: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address fields updated from your current location')),
    );
  }

  void _applyResolvedAddress({
    required LocationAddress address,
    required double latitude,
    required double longitude,
    required bool markAutoFilled,
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _addressController.text = _cleanAddressLine(address.address);
    _cityController.text = _cleanSegment(address.city);
    _stateController.text = _cleanSegment(address.state);
    _pincodeController.text = address.postalCode.trim();
    if (_localityController.text.trim().isEmpty && address.area.trim().isNotEmpty) {
      _localityController.text = _cleanSegment(address.area);
    }
    if (markAutoFilled) {
      _addressAutoFilled = true;
    }
    setState(() {});
  }

  String _preferredAutoFillName(AppUser user) {
    final firebaseName = firebase_auth.FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    if (firebaseName.isNotEmpty) {
      return _cleanName(firebaseName);
    }
    if (user.name.trim().isNotEmpty) {
      return _cleanName(user.name);
    }
    return 'ABZORA Member';
  }

  String _cleanName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _cleanSegment(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^,+|,+$'), '')
        .trim();
  }

  String _cleanAddressLine(String raw) {
    final parts = raw
        .split(',')
        .map(_cleanSegment)
        .where((part) => part.isNotEmpty && part.toLowerCase() != 'location detected')
        .toList();
    final unique = <String>[];
    for (final part in parts) {
      if (!unique.any((existing) => existing.toLowerCase() == part.toLowerCase())) {
        unique.add(part);
      }
    }
    return unique.join(', ');
  }

  Future<void> _saveAddress() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save your address')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_cityController.text.trim().isEmpty || _stateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('City and state are required. Use GPS or valid pincode.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final now = DateTime.now().toIso8601String();
    final address = UserAddress(
      id: '',
      userId: user.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      addressLine: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      houseDetails: _houseController.text.trim(),
      landmark: _landmarkController.text.trim(),
      locality: _localityController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      type: _addressType,
      createdAt: now,
    );

    final fullAddress = [
      if (address.houseDetails.isNotEmpty) address.houseDetails,
      address.addressLine,
      if (address.locality.isNotEmpty) address.locality,
      if (address.landmark.isNotEmpty) address.landmark,
      address.city,
      address.state,
      address.pincode,
    ].join(', ');

    try {
      await _database.saveUserAddress(address);
      if (!mounted) {
        return;
      }
      await context.read<AuthProvider>().saveProfile(
            name: address.name,
            address: fullAddress,
            area: address.locality.isNotEmpty ? address.locality : address.city,
            city: address.city,
            latitude: address.latitude,
            longitude: address.longitude,
          );
      await _loadSavedAddresses();
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved successfully')),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save address right now. Please try again.')),
      );
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    setState(() => _isLoadingAddresses = true);
    try {
      await _database.deleteUserAddress(address.userId, address.id);
      await _loadSavedAddresses();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingAddresses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete address right now.')),
      );
    }
  }

  void _applySavedAddress(UserAddress address) {
    _nameController.text = address.name;
    _phoneController.text = address.phone;
    _addressController.text = address.addressLine;
    _cityController.text = address.city;
    _stateController.text = address.state;
    _pincodeController.text = address.pincode;
    _houseController.text = address.houseDetails;
    _landmarkController.text = address.landmark;
    _localityController.text = address.locality;
    _latitude = address.latitude;
    _longitude = address.longitude;
    _addressType = address.type;
    _isExpanded = address.houseDetails.isNotEmpty || address.landmark.isNotEmpty || address.locality.isNotEmpty;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return AbzioThemeScope.light(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Address'),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFC9A227)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save & Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text(
                'Complete your profile for perfect fit ✨',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                user == null
                    ? 'Sign in to personalize fit, delivery, and styling across devices.'
                    : 'We’ll use this to personalize your fit and delivery.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
              ),
              const SizedBox(height: 20),
              if (_isLoadingAddresses)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: AbzioLoadingView(
                    title: 'Loading addresses',
                    subtitle: 'Checking your saved delivery spots.',
                  ),
                )
              else if (_savedAddresses.isNotEmpty) ...[
                Text(
                  'Saved Addresses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ..._savedAddresses.map((address) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SavedAddressCard(
                        address: address,
                        onUse: () => _applySavedAddress(address),
                        onDelete: () => _deleteAddress(address),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
              AddressFormWidget(
                formKey: _formKey,
                nameController: _nameController,
                phoneController: _phoneController,
                addressController: _addressController,
                pincodeController: _pincodeController,
                cityController: _cityController,
                stateController: _stateController,
                houseController: _houseController,
                landmarkController: _landmarkController,
                localityController: _localityController,
                nameFocusNode: _nameFocusNode,
                phoneFocusNode: _phoneFocusNode,
                addressFocusNode: _addressFocusNode,
                pincodeFocusNode: _pincodeFocusNode,
                houseFocusNode: _houseFocusNode,
                landmarkFocusNode: _landmarkFocusNode,
                localityFocusNode: _localityFocusNode,
                addressType: _addressType,
                isExpanded: _isExpanded,
                isGpsLoading: _isFetchingLocation,
                isAutoFilling: _isAutoFillingProfile,
                isPincodeLookupLoading: _isPincodeLookupLoading,
                nameAutoFilled: _nameAutoFilled,
                addressAutoFilled: _addressAutoFilled,
                onUseCurrentLocation: _useCurrentLocation,
                onToggleExpanded: () => setState(() => _isExpanded = !_isExpanded),
                onAddressTypeChanged: (value) => setState(() => _addressType = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ParsedAddress _parseAddress(String address) {
    final cleaned = address.trim();
    if (cleaned.isEmpty) {
      return const _ParsedAddress();
    }

    final parts = cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    String? pincode;
    for (final part in parts) {
      if (RegExp(r'^\d{6}$').hasMatch(part)) {
        pincode = part;
        break;
      }
    }
    final stateIndex = pincode == null ? parts.length - 1 : parts.length - 2;

    return _ParsedAddress(
      addressLine: parts.isNotEmpty ? parts.first : cleaned,
      locality: parts.length > 2 ? parts[1] : '',
      state: stateIndex >= 0 && stateIndex < parts.length ? parts[stateIndex] : '',
      pincode: pincode ?? '',
    );
  }

  @override
  void dispose() {
    _pincodeDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _localityController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _pincodeFocusNode.dispose();
    _houseFocusNode.dispose();
    _landmarkFocusNode.dispose();
    _localityFocusNode.dispose();
    super.dispose();
  }
}

class _SavedAddressCard extends StatelessWidget {
  const _SavedAddressCard({
    required this.address,
    required this.onUse,
    required this.onDelete,
  });

  final UserAddress address;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final addressTypeLabel = address.type.trim().isEmpty
        ? 'Other'
        : address.type[0].toUpperCase() + address.type.substring(1);
    final title = [
      address.name,
      if (address.locality.isNotEmpty) address.locality,
      address.city,
    ].join(', ');

    final subtitle = [
      if (address.houseDetails.isNotEmpty) address.houseDetails,
      address.addressLine,
      if (address.landmark.isNotEmpty) address.landmark,
      address.state,
      address.pincode,
    ].join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  addressTypeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                tooltip: 'Delete address',
              ),
            ],
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText, height: 1.45),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onUse,
              child: const Text('Use this address'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedAddress {
  final String addressLine;
  final String locality;
  final String state;
  final String pincode;

  const _ParsedAddress({
    this.addressLine = '',
    this.locality = '',
    this.state = '',
    this.pincode = '',
  });
}
