import 'package:flutter/material.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class BusinessProfileStep extends StatefulWidget {
  final TextEditingController storeNameController;
  final TextEditingController ownerNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController gstNumberController;
  final String businessType;
  final ValueChanged<String?> onBusinessTypeChanged;
  
  final TextEditingController addressController;
  final TextEditingController cityController;
  final bool hasLocation;
  final VoidCallback onDetectLocation;
  final VoidCallback onChanged;

  const BusinessProfileStep({
    super.key,
    required this.storeNameController,
    required this.ownerNameController,
    required this.phoneController,
    required this.emailController,
    required this.gstNumberController,
    required this.businessType,
    required this.onBusinessTypeChanged,
    required this.addressController,
    required this.cityController,
    required this.hasLocation,
    required this.onDetectLocation,
    required this.onChanged,
  });

  @override
  State<BusinessProfileStep> createState() => _BusinessProfileStepState();
}

class _BusinessProfileStepState extends State<BusinessProfileStep> {
  static const List<String> _businessTypeOptions = [
    'Individual Seller',
    'Registered Company',
    'Boutique',
    'Manufacturing Unit',
    'Freelance Designer',
  ];

  bool _detectingLocation = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          title: 'Business Information',
          children: [
            _buildField(widget.storeNameController, 'Store Name', icon: Icons.storefront_outlined, hint: 'Abianzo Tailors'),
            _buildDropdown('Business Type', widget.businessType, _businessTypeOptions, widget.onBusinessTypeChanged, icon: Icons.business_outlined),
            _buildField(widget.ownerNameController, 'Owner Name', icon: Icons.person_outline, hint: 'A. Rahman'),
            _buildField(
              widget.phoneController, 
              'Phone', 
              icon: Icons.phone_outlined, 
              hint: '9876543210', 
              readOnly: true,
              trailing: const Icon(Icons.verified, color: VendorTheme.onboardingSuccess, size: 20),
            ),
            _buildField(widget.emailController, 'Business Email Address', icon: Icons.email_outlined, hint: 'owner@store.com'),
            _buildField(widget.gstNumberController, 'GST Number (Optional)', icon: Icons.receipt_long_outlined, hint: '22AAAAA0000A1Z5'),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Location Verification Card',
          children: [
            if (widget.hasLocation) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VendorTheme.onboardingSuccess.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                  border: Border.all(color: VendorTheme.onboardingSuccess.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: VendorTheme.onboardingSuccess, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Verified',
                            style: TextStyle(color: VendorTheme.onboardingSuccess, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.cityController.text.isNotEmpty ? widget.cityController.text : 'Location Saved',
                            style: const TextStyle(color: VendorTheme.onboardingSuccess, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: VendorTheme.onboardingSuccess),
                      onPressed: () async {
                        setState(() => _detectingLocation = true);
                        widget.onDetectLocation();
                        await Future.delayed(const Duration(seconds: 2));
                        if (mounted) setState(() => _detectingLocation = false);
                      },
                      tooltip: 'Refresh Location',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _detectingLocation ? null : () async {
                    setState(() => _detectingLocation = true);
                    widget.onDetectLocation();
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) setState(() => _detectingLocation = false);
                  },
                  icon: _detectingLocation 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VendorTheme.onboardingGold))
                      : const Icon(Icons.my_location, color: VendorTheme.onboardingGold),
                  label: Text(_detectingLocation ? 'Detecting...' : 'Detect Current Location', style: const TextStyle(color: VendorTheme.onboardingGold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VendorTheme.onboardingGold),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VendorTheme.radiusSmall)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildField(widget.addressController, 'Address', icon: Icons.map_outlined, hint: 'Street, area, landmark', maxLines: 2),
            _buildField(widget.cityController, 'City', icon: Icons.location_city_outlined, hint: 'Chennai'),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VendorTheme.onboardingSurface,
        borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
        border: Border.all(color: VendorTheme.onboardingElevatedSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VendorTheme.onboardingPrimaryText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String hint = '',
    bool readOnly = false,
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? VendorTheme.onboardingSecondaryText : VendorTheme.onboardingPrimaryText,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: VendorTheme.onboardingSecondaryText),
          hintText: hint.isEmpty ? null : hint,
          hintStyle: TextStyle(color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.3)),
          filled: true,
          fillColor: readOnly ? VendorTheme.onboardingElevatedSurface.withValues(alpha: 0.5) : VendorTheme.onboardingElevatedSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: icon != null ? Icon(icon, color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.7), size: 20) : null,
          suffixIcon: trailing,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: const BorderSide(color: VendorTheme.onboardingGold, width: 1.5),
          ),
        ),
        onChanged: (_) => widget.onChanged(),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onSelect, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: VendorTheme.onboardingSecondaryText),
          filled: true,
          fillColor: VendorTheme.onboardingElevatedSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: icon != null ? Icon(icon, color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.7), size: 20) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: const BorderSide(color: VendorTheme.onboardingGold, width: 1.5),
          ),
        ),
        dropdownColor: VendorTheme.onboardingElevatedSurface,
        style: const TextStyle(color: VendorTheme.onboardingPrimaryText, fontSize: 15),
        items: options.map((e) {
          return DropdownMenuItem(value: e, child: Text(e));
        }).toList(),
        onChanged: (val) {
          onSelect(val);
          widget.onChanged();
        },
      ),
    );
  }
}
