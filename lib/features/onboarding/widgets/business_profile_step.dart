import 'package:flutter/material.dart';

class BusinessProfileStep extends StatelessWidget {
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

  static const List<String> _businessTypeOptions = [
    'Individual Seller',
    'Registered Company',
    'Boutique',
    'Manufacturing Unit',
    'Freelance Designer',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          title: 'Business Information',
          children: [
            _buildField(storeNameController, 'Store Name', hint: 'Abianzo Tailors'),
            _buildDropdown('Business Type', businessType, _businessTypeOptions, onBusinessTypeChanged),
            _buildField(ownerNameController, 'Owner Name', hint: 'A. Rahman', readOnly: true),
            _buildField(phoneController, 'Phone', hint: '9876543210', readOnly: true),
            _buildField(emailController, 'Email', hint: 'owner@store.com', readOnly: true),
            _buildField(gstNumberController, 'GST Number (Optional)', hint: '22AAAAA0000A1Z5'),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Location Verification',
          children: [
            _buildField(addressController, 'Address', hint: 'Street, area, landmark', maxLines: 2),
            _buildField(cityController, 'City', hint: 'Chennai', readOnly: true),
            const SizedBox(height: 16),
            if (hasLocation)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location Verified Securely',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDetectLocation,
                  icon: const Icon(Icons.my_location, color: Colors.white),
                  label: const Text('Detect Current Location', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? Colors.white54 : Colors.white,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          hintText: hint.isEmpty ? null : hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: readOnly ? Colors.white.withValues(alpha: 0.02) : Colors.black26,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.black26,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
        dropdownColor: const Color(0xFF1E1E1E),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: onSelect,
      ),
    );
  }
}
