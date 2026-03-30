import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class AddressFormWidget extends StatelessWidget {
  const AddressFormWidget({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.pincodeController,
    required this.cityController,
    required this.stateController,
    required this.houseController,
    required this.landmarkController,
    required this.localityController,
    required this.nameFocusNode,
    required this.phoneFocusNode,
    required this.addressFocusNode,
    required this.pincodeFocusNode,
    required this.houseFocusNode,
    required this.landmarkFocusNode,
    required this.localityFocusNode,
    required this.addressType,
    required this.isExpanded,
    required this.isGpsLoading,
    required this.isAutoFilling,
    required this.isPincodeLookupLoading,
    required this.nameAutoFilled,
    required this.addressAutoFilled,
    required this.onUseCurrentLocation,
    required this.onToggleExpanded,
    required this.onAddressTypeChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController pincodeController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController houseController;
  final TextEditingController landmarkController;
  final TextEditingController localityController;
  final FocusNode nameFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode addressFocusNode;
  final FocusNode pincodeFocusNode;
  final FocusNode houseFocusNode;
  final FocusNode landmarkFocusNode;
  final FocusNode localityFocusNode;
  final String addressType;
  final bool isExpanded;
  final bool isGpsLoading;
  final bool isAutoFilling;
  final bool isPincodeLookupLoading;
  final bool nameAutoFilled;
  final bool addressAutoFilled;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onAddressTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF181514),
                  Color(0xFF0D0B0B),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE1B64A),
                            Color(0xFFB8861B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AbzioTheme.accentColor.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.content_cut_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete your profile for perfect fit ✨',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We’ll use this to personalize your fit and delivery',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on_outlined,
                              color: AbzioTheme.accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery address',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Auto-detected via GPS',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AbzioTheme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Use your current location for faster delivery setup and a more tailored fit experience.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (isGpsLoading || isAutoFilling) ? null : onUseCurrentLocation,
                          icon: (isGpsLoading || isAutoFilling)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text((isGpsLoading || isAutoFilling) ? 'Fetching location...' : 'Use Current Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: AbzioTheme.accentColor.withValues(alpha: 0.44)),
                            backgroundColor: Colors.white.withValues(alpha: 0.03),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildField(
            context,
            controller: nameController,
            focusNode: nameFocusNode,
            label: 'Full Name',
            hintText: 'Enter recipient name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(phoneFocusNode),
            autoFilled: nameAutoFilled,
          ),
          const SizedBox(height: 16),
          _buildField(
            context,
            controller: phoneController,
            focusNode: phoneFocusNode,
            label: 'Mobile Number',
            hintText: '10-digit mobile number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Mobile number is required';
              }
              if (!RegExp(r'^\d{10}$').hasMatch(trimmed)) {
                return 'Enter a valid 10-digit mobile number';
              }
              return null;
            },
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(addressFocusNode),
          ),
          const SizedBox(height: 16),
          _buildField(
            context,
            controller: addressController,
            focusNode: addressFocusNode,
            label: 'Address Line',
            hintText: 'House name, street, road',
            icon: Icons.location_on_outlined,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.next,
            minLines: 3,
            maxLines: 4,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(pincodeFocusNode),
            autoFilled: addressAutoFilled,
          ),
          const SizedBox(height: 16),
          _buildField(
            context,
            controller: pincodeController,
            focusNode: pincodeFocusNode,
            label: 'Pincode',
            hintText: '6-digit pincode',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: isExpanded ? TextInputAction.next : TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            suffixIcon: isPincodeLookupLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Pincode is required';
              }
              if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
                return 'Enter a valid 6-digit pincode';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (isExpanded) {
                FocusScope.of(context).requestFocus(houseFocusNode);
              } else {
                FocusScope.of(context).unfocus();
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  context,
                  controller: cityController,
                  label: 'City',
                  hintText: 'Auto-filled city',
                  icon: Icons.location_city_outlined,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  context,
                  controller: stateController,
                  label: 'State',
                  hintText: 'Auto-filled state',
                  icon: Icons.map_outlined,
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: AbzioTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpanded ? 'Hide additional details' : 'Add more details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AbzioTheme.accentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: isExpanded
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildField(
                        context,
                        controller: houseController,
                        focusNode: houseFocusNode,
                        label: 'House No / Flat / Block',
                        hintText: 'Apartment, floor, or block',
                        icon: Icons.apartment_outlined,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(landmarkFocusNode),
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        context,
                        controller: landmarkController,
                        focusNode: landmarkFocusNode,
                        label: 'Landmark (Optional)',
                        hintText: 'Nearby well-known place',
                        icon: Icons.place_outlined,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(localityFocusNode),
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        context,
                        controller: localityController,
                        focusNode: localityFocusNode,
                        label: 'Locality / Area',
                        hintText: 'Neighborhood or area',
                        icon: Icons.map_rounded,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text(
            'Address Type',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _typeChip(context, value: 'home', label: 'Home', icon: Icons.home_outlined),
              _typeChip(context, value: 'office', label: 'Office', icon: Icons.business_center_outlined),
              _typeChip(context, value: 'other', label: 'Other', icon: Icons.bookmark_border_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = addressType == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onAddressTypeChanged(value),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: AbzioTheme.accentColor,
      side: BorderSide(
        color: selected ? AbzioTheme.accentColor : context.abzioBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      showCheckmark: false,
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onFieldSubmitted,
    int minLines = 1,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
    bool autoFilled = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      minLines: minLines,
      maxLines: maxLines,
      readOnly: readOnly,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        hintText: hintText,
        prefixIcon: Icon(icon, color: context.abzioSecondaryText),
        suffixIcon: suffixIcon ??
            (autoFilled
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Auto-filled',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AbzioTheme.accentColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  )
                : null),
        filled: true,
        fillColor: const Color(0xFFF6F3EC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.abzioBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: context.abzioBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AbzioTheme.accentColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.4),
        ),
      ),
    );
  }
}
