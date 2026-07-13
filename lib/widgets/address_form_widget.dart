import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils/phone_number_utils.dart';

class AddressFormWidget extends StatelessWidget {
  const AddressFormWidget({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.pincodeController,
    required this.houseController,
    required this.landmarkController,
    required this.localityController,
    required this.nameFocusNode,
    required this.phoneFocusNode,
    required this.pincodeFocusNode,
    required this.houseFocusNode,
    required this.landmarkFocusNode,
    required this.localityFocusNode,
    required this.addressType,
    required this.isPincodeLookupLoading,
    required this.nameAutoFilled,
    required this.onAddressTypeChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController pincodeController;
  final TextEditingController houseController;
  final TextEditingController landmarkController;
  final TextEditingController localityController;
  final FocusNode nameFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode pincodeFocusNode;
  final FocusNode houseFocusNode;
  final FocusNode landmarkFocusNode;
  final FocusNode localityFocusNode;
  final String addressType;
  final bool isPincodeLookupLoading;
  final bool nameAutoFilled;
  final ValueChanged<String> onAddressTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _floatingField(
            context,
            controller: nameController,
            focusNode: nameFocusNode,
            label: 'Full Name',
            hintText: 'Recipient name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Full name is required';
              if ((value ?? '').trim().length < 2) return 'Enter a valid name';
              return null;
            },
            onFieldSubmitted: (_) => phoneFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          _floatingField(
            context,
            controller: phoneController,
            focusNode: phoneFocusNode,
            label: 'Mobile Number',
            hintText: '10-digit mobile number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]')),
              LengthLimitingTextInputFormatter(15),
            ],
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Mobile number is required';
              }
              if (!isValidIndianMobileNumber(trimmed)) {
                return 'Enter a valid 10-digit number';
              }
              return null;
            },
            onFieldSubmitted: (_) => houseFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          _floatingField(
            context,
            controller: houseController,
            focusNode: houseFocusNode,
            label: 'House / Flat',
            hintText: 'Apartment, floor, building',
            icon: Icons.apartment_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'House/Flat is required';
              return null;
            },
            onFieldSubmitted: (_) => localityFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          _floatingField(
            context,
            controller: localityController,
            focusNode: localityFocusNode,
            label: 'Locality',
            hintText: 'Area, neighborhood, street',
            icon: Icons.location_city_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Locality is required';
              return null;
            },
            onFieldSubmitted: (_) => landmarkFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          _floatingField(
            context,
            controller: landmarkController,
            focusNode: landmarkFocusNode,
            label: 'Landmark',
            hintText: 'Nearby landmark (optional)',
            icon: Icons.place_outlined,
            textInputAction: TextInputAction.next,
            validator: (_) => null,
            onFieldSubmitted: (_) => pincodeFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          _floatingField(
            context,
            controller: pincodeController,
            focusNode: pincodeFocusNode,
            label: 'Pincode',
            hintText: '6 digits',
            icon: Icons.pin_drop_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Pincode is required';
              }
              if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
                return 'Enter a valid pincode';
              }
              return null;
            },
          ),
            const SizedBox(height: AbzioTheme.spacing20),
            Text(
              'Address Type',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'home',
                    icon: Icon(Icons.home_outlined),
                    label: Text('Home'),
                  ),
                  ButtonSegment(
                    value: 'office',
                    icon: Icon(Icons.business_center_outlined),
                    label: Text('Office'),
                  ),
                  ButtonSegment(
                    value: 'other',
                    icon: Icon(Icons.bookmark_border_rounded),
                    label: Text('Other'),
                  ),
                ],
                selected: {addressType},
                onSelectionChanged: (values) {
                  final value = values.isNotEmpty ? values.first : null;
                  if (value != null) {
                    onAddressTypeChanged(value);
                  }
                },
                style: ButtonStyle(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 16),
                  ),
                  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
                  visualDensity: VisualDensity.standard,
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          if (isPincodeLookupLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Looking up service area...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.abzioSecondaryText,
                  ),
                ),
              ],
            ),
          ],
          if (nameAutoFilled) ...[
            const SizedBox(height: 12),
            _StatusPill(
              icon: Icons.auto_awesome_rounded,
              text: 'Location autofill applied',
            ),
          ],
        ],
      ),
    );
  }

  Widget _floatingField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required IconData icon,
    required TextInputAction textInputAction,
    required FormFieldValidator<String> validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter> inputFormatters = const [],
    int minLines = 1,
    int maxLines = 1,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2F7A3D)),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF2F7A3D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
