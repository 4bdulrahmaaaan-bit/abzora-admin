import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../theme.dart';
import '../../../providers/auth_provider.dart';
import 'tbyb_booking_summary_screen.dart';

class TbybAddressScreen extends StatefulWidget {
  const TbybAddressScreen({
    super.key,
    required this.selectedItems,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.trialDurationMinutes,
  });

  final List<Product> selectedItems;
  final String deliveryDate;
  final String deliveryTime;
  final int trialDurationMinutes;

  @override
  State<TbybAddressScreen> createState() => _TbybAddressScreenState();
}

class _TbybAddressScreenState extends State<TbybAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _landmarkController;
  late TextEditingController _pincodeController;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    
    _nameController = TextEditingController(text: auth.user?.name ?? '');
    _phoneController = TextEditingController(text: auth.user?.phone ?? '');
    
    // Split address if exists
    final fullAddress = auth.user?.address ?? '';
    final parts = fullAddress.split(',');
    
    _addressLine1Controller = TextEditingController(text: parts.isNotEmpty ? parts[0].trim() : '');
    _addressLine2Controller = TextEditingController(text: parts.length > 1 ? parts[1].trim() : '');
    _landmarkController = TextEditingController(text: parts.length > 2 ? parts[2].trim() : '');
    _pincodeController = TextEditingController(text: parts.length > 3 ? parts[3].trim() : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      final addressLabel = '${_addressLine1Controller.text}, ${_addressLine2Controller.text}, ${_landmarkController.text}, ${_pincodeController.text}'.replaceAll(', ,', ',');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TbybBookingSummaryScreen(
            selectedItems: widget.selectedItems,
            deliveryDate: widget.deliveryDate,
            deliveryTime: widget.deliveryTime,
            trialDurationMinutes: widget.trialDurationMinutes,
            addressLabel: addressLabel,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Delivery Address'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Contact Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Full Name', _nameController, TextInputType.name),
                  const SizedBox(height: 16),
                  _buildTextField('Mobile Number', _phoneController, TextInputType.phone),
                  
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Address Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {}, // Mock for "Saved Addresses"
                        child: const Text('Saved Addresses'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Address Line 1 (Flat, House no., Building)', _addressLine1Controller, TextInputType.streetAddress),
                  const SizedBox(height: 16),
                  _buildTextField('Address Line 2 (Area, Street, Sector)', _addressLine2Controller, TextInputType.streetAddress),
                  const SizedBox(height: 16),
                  _buildTextField('Landmark (Optional)', _landmarkController, TextInputType.text, isOptional: true),
                  const SizedBox(height: 16),
                  _buildTextField('Pincode', _pincodeController, TextInputType.number),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: _onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AbzioTheme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType type, {bool isOptional = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (value) {
        if (!isOptional && (value == null || value.trim().isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AbzioTheme.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AbzioTheme.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AbzioTheme.accentColor, width: 2),
        ),
      ),
    );
  }
}
