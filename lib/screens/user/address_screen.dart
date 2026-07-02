import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_error_text.dart';
import '../../widgets/abzio_motion.dart';
import '../../theme.dart';
import '../../widgets/address_form_widget.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  static const String _fixedState = '';

  final DatabaseService _database = DatabaseService();
  final LocationService _locationService = LocationService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _pincodeFocusNode = FocusNode();
  final FocusNode _houseFocusNode = FocusNode();
  final FocusNode _landmarkFocusNode = FocusNode();
  final FocusNode _localityFocusNode = FocusNode();

  List<UserAddress> _savedAddresses = const [];
  bool _isSaving = false;
  bool _isGpsLoading = false;
  bool _isAutoFilling = false;
  bool _isPincodeLookupLoading = false;
  bool _nameAutoFilled = false;
  bool _addressAutoFilled = false;
  bool _isExpanded = false;
  String _addressType = 'home';
  double? _latitude;
  double? _longitude;
  Timer? _pincodeDebounce;
  bool _prefilledFromProfile = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilledFromProfile) {
      return;
    }
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _applyUserProfileDefaults(user);
      _prefilledFromProfile = true;
    }
  }

  void _applyUserProfileDefaults(AppUser user) {
    final name = user.name.trim();
    if (name.isNotEmpty && _nameController.text.trim().isEmpty) {
      _nameController.text = name;
      _nameAutoFilled = true;
    }
    final phone = (user.phone ?? '').trim();
    if (phone.isNotEmpty && _phoneController.text.trim().isEmpty) {
      _phoneController.text = phone;
    }
    final address = (user.address ?? '').trim();
    if (address.isNotEmpty && _addressController.text.trim().isEmpty) {
      _addressController.text = address;
      _addressAutoFilled = true;
    }
    final city = (user.city ?? '').trim();
    if (city.isNotEmpty && _cityController.text.trim().isEmpty) {
      _cityController.text = city;
    }
    if (_stateController.text.trim().isEmpty) {
      _stateController.text = _fixedState;
    }
  }

  Future<void> _loadSavedAddresses() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    try {
      final addresses = await _database.getUserAddresses(user.id);
      if (!mounted) return;
      setState(() => _savedAddresses = addresses);
    } catch (_) {
      return;
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isGpsLoading || _isAutoFilling) return;

    setState(() {
      _isGpsLoading = true;
      _isAutoFilling = true;
    });

    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;

    final address = result.address;
    if (result.status == LocationStatus.success && address != null) {
      _applyResolvedAddress(
        address: address,
        latitude: result.position?.latitude,
        longitude: result.position?.longitude,
        markAutoFilled: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Address fields updated from your current location'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            result.message ?? 'Unable to fetch your location right now.',
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isGpsLoading = false;
      _isAutoFilling = false;
    });
  }

  void _applyResolvedAddress({
    required LocationAddress address,
    required double? latitude,
    required double? longitude,
    required bool markAutoFilled,
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _addressController.text = _cleanAddressLine(address.address);
    _cityController.text = address.city.trim();
    _stateController.text = address.state.trim();
    _pincodeController.text = address.postalCode.trim();
    if (_localityController.text.trim().isEmpty &&
        address.area.trim().isNotEmpty) {
      _localityController.text = address.area.trim();
    }
    if (markAutoFilled) {
      _addressAutoFilled = true;
      _isExpanded = true;
    }
    _lookupPincode(_pincodeController.text.trim());
    setState(() {});
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
    _isExpanded =
        address.houseDetails.isNotEmpty ||
        address.landmark.isNotEmpty ||
        address.locality.isNotEmpty;
    _lookupPincode(address.pincode);
    setState(() {});
  }

  void _lookupPincode(String pincode) {
    final trimmed = pincode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return;
    }

    _pincodeDebounce?.cancel();
    _pincodeDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      setState(() => _isPincodeLookupLoading = true);
      try {
        final lookup = await _locationService.lookupByPincode(trimmed);
        if (!mounted) return;
        if (lookup != null) {
          _cityController.text = lookup.city.trim();
          _stateController.text = lookup.state.trim();
        }
      } catch (_) {
        // Keep the user flow intact if lookup services are unavailable.
      } finally {
        if (mounted) {
          setState(() => _isPincodeLookupLoading = false);
        }
      }
    });
  }

  String _cleanAddressLine(String raw) {
    return raw
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .join(', ');
  }

  Future<void> _saveAddress() async {
    if (_isSaving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save your address.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
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
        createdAt: DateTime.now().toIso8601String(),
      );

      final fullAddress = [
        address.houseDetails,
        address.addressLine,
        address.locality,
        address.city,
        address.state,
        address.pincode,
      ].where((value) => value.trim().isNotEmpty).join(', ');

      await _database.saveUserAddress(address);
      await _database.updateUserProfile(
        userId: user.id,
        address: fullAddress,
        city: address.city,
      );
      await _loadSavedAddresses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved successfully')),
      );
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('AddressScreen: save address failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    try {
      await _database.deleteUserAddress(address.userId, address.id);
      await _loadSavedAddresses();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    }
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final areaLabel = _cityController.text.trim().isEmpty && _stateController.text.trim().isEmpty
        ? 'Delivery area will be confirmed'
        : [
            _cityController.text.trim(),
            _stateController.text.trim(),
          ].where((value) => value.isNotEmpty).join(', ');

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Add Address')),
        bottomNavigationBar: AnimatedPadding(
          duration: AbzioMotion.medium,
          curve: AbzioMotion.curve,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: context.abzioBorder.withValues(alpha: 0.65),
                  ),
                ),
              ),
              child: SizedBox(
                height: 60,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAddress,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Save Address'),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AbzioTheme.screenHorizontalPadding,
              20,
              AbzioTheme.screenHorizontalPadding,
              132,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Address',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user == null
                      ? 'Sign in to personalize delivery and tailoring across devices.'
                      : 'Used for delivery and personalized tailoring.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.abzioSecondaryText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AbzioTheme.sectionGap),
                _LocationCard(
                  isLoading: _isGpsLoading || _isAutoFilling,
                  onTap: _useCurrentLocation,
                ),
                const SizedBox(height: AbzioTheme.sectionGap),
                _ServiceAreaCard(
                  cityStateLabel: areaLabel,
                  isLoading: _isPincodeLookupLoading,
                ),
                const SizedBox(height: AbzioTheme.sectionGap),
                AddressFormWidget(
                  formKey: _formKey,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  addressController: _addressController,
                  pincodeController: _pincodeController,
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
                  isPincodeLookupLoading: _isPincodeLookupLoading,
                  nameAutoFilled: _nameAutoFilled,
                  addressAutoFilled: _addressAutoFilled,
                  onToggleExpanded: () =>
                      setState(() => _isExpanded = !_isExpanded),
                  onAddressTypeChanged: (value) =>
                      setState(() => _addressType = value),
                ),
                if (_savedAddresses.isNotEmpty) ...[
                  const SizedBox(height: AbzioTheme.sectionGap),
                  Text(
                    'Saved addresses',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._savedAddresses.map(
                    (address) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SavedAddressCard(
                        address: address,
                        onUse: () => _applySavedAddress(address),
                        onDelete: () => _deleteAddress(address),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF191411),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        boxShadow: AbzioTheme.shadowFor(Brightness.light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0D99B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: Color(0xFFF3D88F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Address',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use your current location to autofill your address details.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isLoading ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: const Color(0xFFF0D99B).withValues(alpha: 0.35),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.03),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Use Current Location'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceAreaCard extends StatelessWidget {
  const _ServiceAreaCard({
    required this.cityStateLabel,
    required this.isLoading,
  });

  final String cityStateLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E9),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: const Color(0xFFBFE0C3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2F7A3D).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF2F7A3D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Available',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF2F7A3D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cityStateLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF315438),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isLoading ? 'Checking...' : 'Estimated delivery:',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF52715A)),
              ),
              const SizedBox(height: 2),
              Text(
                '2-4 business days',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF315438),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final addressTypeLabel = switch (address.type) {
      'office' => 'Office',
      'other' => 'Other',
      _ => 'Home',
    };

    final subtitle = [
      address.addressLine,
      address.locality,
      address.city,
      address.state,
      address.pincode,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F1E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  addressTypeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8D6C22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: 'Delete address',
              ),
            ],
          ),
          Text(
            address.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF161616),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.abzioSecondaryText,
              height: 1.45,
            ),
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
