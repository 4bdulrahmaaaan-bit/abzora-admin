import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/delivery_service.dart';
import 'address_form_widget.dart';
import '../utils/phone_number_utils.dart';
import '../screens/user/map_location_picker_screen.dart';

class LocationSelectionSheet extends StatefulWidget {
  const LocationSelectionSheet({
    super.key,
    this.product,
  });

  final Product? product;

  static Future<dynamic> show(BuildContext context, {Product? product}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSelectionSheet(product: product),
    );
  }

  @override
  State<LocationSelectionSheet> createState() => _LocationSelectionSheetState();
}

class _LocationSelectionSheetState extends State<LocationSelectionSheet> {
  final _database = DatabaseService();
  final _locationService = LocationService();
  final _deliveryService = DeliveryService();

  final _pincodeController = TextEditingController();
  
  // Inline address form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _inlinePincodeController = TextEditingController();
  final _houseController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _localityController = TextEditingController();
  
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _inlinePincodeFocusNode = FocusNode();
  final _houseFocusNode = FocusNode();
  final _landmarkFocusNode = FocusNode();
  final _localityFocusNode = FocusNode();

  String _addressType = 'home';
  bool _isExpanded = false;

  List<UserAddress> _savedAddresses = [];
  String? _selectedAddressId;
  
  bool _isLoadingAddresses = true;
  bool _isCheckingEstimate = false;
  
  bool _isDeliverable = false;
  String _deliveryEstimate = '';
  
  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _inlinePincodeController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _localityController.dispose();
    
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _inlinePincodeFocusNode.dispose();
    _houseFocusNode.dispose();
    _landmarkFocusNode.dispose();
    _localityFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
      return;
    }

    // Idempotent dedup — fire-and-forget, never blocks UI.
    _database.deduplicateUserAddresses(user.id).ignore();

    try {
      final addresses = await _database.getUserAddresses(user.id);
      if (mounted) {
        setState(() {
          _savedAddresses = addresses;
          _isLoadingAddresses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _checkServiceability(String pincode) async {
    if (pincode.length != 6) {
      setState(() {
        _isDeliverable = false;
        _deliveryEstimate = '';
      });
      return;
    }

    setState(() => _isCheckingEstimate = true);

    final AuthProvider authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    final CartProvider cartProvider = context.read<CartProvider>();
    final cartItems = cartProvider.items;

    try {
      final lookup = await _locationService.lookupByPincode(pincode);
      if (lookup == null) {
        if (mounted) {
          setState(() {
            _isDeliverable = false;
            _deliveryEstimate = '';
          });
        }
        return;
      }

      final dummyAddress = UserAddress(
        id: '',
        userId: user?.id ?? '',
        name: '',
        phone: '',
        addressLine: '',
        city: lookup.city,
        state: lookup.state,
        pincode: pincode,
        houseDetails: '',
        landmark: '',
        locality: '',
        type: 'home',
        createdAt: '',
        latitude: null,
        longitude: null,
      );

      String maxEstimate = '';
      bool deliverable = true;

      if (widget.product != null) {
        final service = await _deliveryService.getServiceability(
          product: widget.product!,
          address: dummyAddress,
        );
        deliverable = service.isDeliverable;
        maxEstimate = service.estimatedDeliveryDate;
      } else {
        // Cart / Checkout multi-product fallback
        if (cartItems.isNotEmpty) {
          final serviceabilities = await Future.wait(cartItems.map((item) {
            return _deliveryService.getServiceability(
              product: item.product,
              address: dummyAddress,
            );
          }));
          deliverable = serviceabilities.every((s) => s.isDeliverable);
          maxEstimate = DeliveryService.getMaxDeliveryEstimate(serviceabilities);
        } else {
          maxEstimate = '2-4 days'; 
        }
      }

      if (mounted) {
        setState(() {
          _isDeliverable = deliverable;
          _deliveryEstimate = maxEstimate;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDeliverable = false;
          _deliveryEstimate = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingEstimate = false);
      }
    }
  }

  void _onPincodeChanged(String value) {
    if (value.length == 6) {
      _checkServiceability(value);
    } else {
      setState(() {
        _isDeliverable = false;
        _deliveryEstimate = '';
      });
    }
  }

  void _onAddressSelected(UserAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _pincodeController.text = address.pincode;
    });
    _checkServiceability(address.pincode);
  }

  Future<void> _handleConfirm() async {
    final user = context.read<AuthProvider>().user;
    
    if (user != null && _savedAddresses.isEmpty) {
      final valid = _formKey.currentState?.validate() ?? false;
      if (!valid) return;
      
      var address = UserAddress(
        id: '',
        userId: user.id,
        name: _nameController.text.trim(),
        phone: normalizeIndianMobileNumber(_phoneController.text.trim()),
        addressLine: _addressController.text.trim(),
        city: '',
        state: '',
        pincode: _inlinePincodeController.text.trim(),
        houseDetails: _houseController.text.trim(),
        landmark: _landmarkController.text.trim(),
        locality: _localityController.text.trim(),
        type: _addressType,
        createdAt: DateTime.now().toIso8601String(),
        latitude: null,
        longitude: null,
      );

      final lookup = await _locationService.lookupByPincode(address.pincode);
      if (lookup != null) {
        address = UserAddress(
          id: address.id,
          userId: address.userId,
          name: address.name,
          phone: address.phone,
          addressLine: address.addressLine,
          city: lookup.city,
          state: lookup.state,
          pincode: address.pincode,
          houseDetails: address.houseDetails,
          landmark: address.landmark,
          locality: address.locality,
          type: address.type,
          createdAt: address.createdAt,
          latitude: address.latitude,
          longitude: address.longitude,
        );
      }

      await _database.saveUserAddress(address);
      if (mounted) {
        Navigator.of(context).pop(address);
      }
      return;
    }
    
    if (user != null && _selectedAddressId != null) {
      final selected = _savedAddresses.firstWhere((a) => a.id == _selectedAddressId);
      Navigator.of(context).pop(selected);
      return;
    }

    Navigator.of(context).pop(_pincodeController.text.trim());
  }

  bool get _isConfirmValid {
    if (_isCheckingEstimate) return false;
    
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      if (_savedAddresses.isNotEmpty) {
        return _selectedAddressId != null && _isDeliverable;
      } else {
        return _inlinePincodeController.text.length == 6 && _isDeliverable;
      }
    }
    return _pincodeController.text.length == 6 && _isDeliverable;
  }

  bool _isUsingCurrentLocation = false;

  Future<void> _useCurrentLocation() async {
    if (_isUsingCurrentLocation) return;
    setState(() => _isUsingCurrentLocation = true);
    try {
      final result = await _locationService.getCurrentLocation();
      if (result.status == LocationStatus.success && result.address != null) {
        final postalCode = result.address!.postalCode.trim();
        if (postalCode.isNotEmpty) {
          _pincodeController.text = postalCode;
          _onPincodeChanged(postalCode);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not determine pincode for your location.')),
            );
          }
        }
      } else if (result.status == LocationStatus.permissionDeniedForever || result.status == LocationStatus.serviceDisabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.message ?? 'Location access is unavailable.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                if (result.status == LocationStatus.serviceDisabled) {
                  await _locationService.openSystemLocationSettings();
                } else {
                  await _locationService.openSystemAppSettings();
                }
              },
            ),
          ));
        }
      } else if (result.status != LocationStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Unable to fetch your location right now.')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUsingCurrentLocation = false);
      }
    }
  }

  Future<void> _searchLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapLocationPickerScreen()),
    );
    
    if (result is LocationAddress && mounted) {
      final postalCode = result.postalCode.trim();
      if (postalCode.isNotEmpty) {
        _pincodeController.text = postalCode;
        _onPincodeChanged(postalCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine pincode from selected location.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Delivery Location',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111111),
                  fontSize: 20,
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.topRight,
                  child: const Icon(Icons.close, size: 24, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user == null || _savedAddresses.isNotEmpty) ...[
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEDE6D8)),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Color(0xFFB08D2B)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              onChanged: _onPincodeChanged,
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                hintText: 'Enter Pincode',
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _checkServiceability(_pincodeController.text),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Check',
                              style: TextStyle(
                                color: Color(0xFFB08D2B),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _isUsingCurrentLocation ? null : _useCurrentLocation,
                      child: Row(
                        children: [
                          const Icon(Icons.my_location, size: 18, color: Colors.black),
                          const SizedBox(width: 12),
                          Text(
                            'Use my current location',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: _isUsingCurrentLocation ? Colors.grey : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          if (_isUsingCurrentLocation)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _searchLocation,
                      child: Row(
                        children: [
                          const Icon(Icons.map_outlined, size: 18, color: Colors.black),
                          const SizedBox(width: 12),
                          Text(
                            'Search location',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isDeliverable && _deliveryEstimate.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 20, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery Available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Delivery by $_deliveryEstimate',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4A4A4A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Estimated delivery:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _deliveryEstimate,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (user != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: const Color(0xFFEDE6D8))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Or', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ),
                        Expanded(child: Container(height: 1, color: const Color(0xFFEDE6D8))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Saved Address',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoadingAddresses)
                      const Center(child: CircularProgressIndicator())
                    else if (_savedAddresses.isEmpty)
                      AddressFormWidget(
                        formKey: _formKey,
                        nameController: _nameController,
                        phoneController: _phoneController,
                        addressController: _addressController,
                        pincodeController: _inlinePincodeController,
                        houseController: _houseController,
                        landmarkController: _landmarkController,
                        localityController: _localityController,
                        nameFocusNode: _nameFocusNode,
                        phoneFocusNode: _phoneFocusNode,
                        addressFocusNode: _addressFocusNode,
                        pincodeFocusNode: _inlinePincodeFocusNode,
                        houseFocusNode: _houseFocusNode,
                        landmarkFocusNode: _landmarkFocusNode,
                        localityFocusNode: _localityFocusNode,
                        addressType: _addressType,
                        isExpanded: _isExpanded,
                        isPincodeLookupLoading: false,
                        nameAutoFilled: false,
                        addressAutoFilled: false,
                        showFullForm: true,
                        onToggleExpanded: () => setState(() => _isExpanded = !_isExpanded),
                        onAddressTypeChanged: (v) => setState(() => _addressType = v),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _savedAddresses.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final address = _savedAddresses[index];
                          final isSelected = address.id == _selectedAddressId;

                          // Tag pill — fall back to 'HOME' for legacy entries.
                          final tagLabel = switch (address.type.trim().toLowerCase()) {
                            'office' => 'OFFICE',
                            'other'  => 'OTHER',
                            _        => 'HOME',
                          };

                          final rawAddressParts = [
                            address.houseDetails.trim(),
                            address.addressLine.trim(),
                            address.locality.trim(),
                            address.city.trim(),
                            address.state.trim(),
                            address.pincode.trim(),
                          ].where((s) => s.isNotEmpty).toList();

                          final seen = <String>{};
                          final deduped = rawAddressParts.where((s) => seen.add(s.toLowerCase())).toList();
                          final fullAddress = deduped.join(', ');

                          final displayName = address.name.trim().isNotEmpty
                              ? address.name.trim()
                              : 'Saved Address';

                          return GestureDetector(
                            onTap: () => _onAddressSelected(address),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFB08D2B)
                                      : const Color(0xFFEDE6D8),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                color: isSelected
                                    ? const Color(0xFFFAF5E9)
                                    : Colors.white,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Pin icon
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB08D2B).withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        size: 17,
                                        color: Color(0xFFB08D2B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Text content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Row 1: Name + pincode + tag
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text.rich(
                                                TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: displayName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13.5,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    if (address.pincode.trim().isNotEmpty) ...[
                                                      const TextSpan(text: '  '),
                                                      TextSpan(
                                                        text: address.pincode.trim(),
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 13,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFB08D2B).withValues(alpha: 0.10),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: const Color(0xFFB08D2B).withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Text(
                                                tagLabel,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFB08D2B),
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Row 2: full address, 2 lines max
                                        if (fullAddress.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            fullAddress,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF8A8272),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Selector circle
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, left: 8),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFFB08D2B) : Colors.grey.shade300,
                                          width: isSelected ? 6 : 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isConfirmValid ? _handleConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB08D2B),
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
