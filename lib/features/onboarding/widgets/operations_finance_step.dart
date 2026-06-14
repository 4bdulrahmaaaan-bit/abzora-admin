import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OperationsFinanceStep extends StatelessWidget {
  final TextEditingController startingPriceController;
  final TextEditingController upperPriceController;
  final TextEditingController productionDaysController;
  final TextEditingController monthlyCapacityController;
  
  final String preferredPaymentMethod;
  final String settlementPreference;
  final ValueChanged<String?> onPaymentMethodChanged;
  final ValueChanged<String?> onSettlementChanged;
  
  final TextEditingController bankAccountController;
  final TextEditingController confirmBankAccountController;
  final TextEditingController ifscController;
  final TextEditingController upiController;
  
  final VoidCallback onChanged;

  const OperationsFinanceStep({
    super.key,
    required this.startingPriceController,
    required this.upperPriceController,
    required this.productionDaysController,
    required this.monthlyCapacityController,
    required this.preferredPaymentMethod,
    required this.settlementPreference,
    required this.onPaymentMethodChanged,
    required this.onSettlementChanged,
    required this.bankAccountController,
    required this.confirmBankAccountController,
    required this.ifscController,
    required this.upiController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          title: 'Pricing & Capacity',
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    startingPriceController,
                    'Starting Price (Rs)',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    upperPriceController,
                    'Typical Upper (Rs)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    productionDaysController,
                    'Production Days',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    monthlyCapacityController,
                    'Monthly Capacity',
                    hint: 'Items/mo',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Finance & Payouts',
          children: [
            _buildDropdown(
              'Preferred Payment Method',
              preferredPaymentMethod,
              ['Bank Transfer', 'UPI'],
              onPaymentMethodChanged,
            ),
            _buildDropdown(
              'Settlement Schedule',
              settlementPreference,
              ['Weekly', 'Bi-Weekly', 'Monthly'],
              onSettlementChanged,
            ),
            const SizedBox(height: 16),
            if (preferredPaymentMethod == 'Bank Transfer') ...[
              _buildField(
                bankAccountController,
                'Bank Account Number',
                hint: '1234567890',
                keyboardType: TextInputType.number,
              ),
              _buildField(
                confirmBankAccountController,
                'Confirm Bank Account Number',
                hint: '1234567890',
                keyboardType: TextInputType.number,
              ),
              _buildField(
                ifscController,
                'IFSC Code',
                hint: 'HDFC0001234',
              ),
            ] else ...[
              _buildField(
                upiController,
                'UPI ID',
                hint: 'user@upi',
              ),
            ],
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
    String hint = '',
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          hintText: hint.isEmpty ? null : hint,
          hintStyle: const TextStyle(color: Colors.white24),
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
        onChanged: (val) {
          onSelect(val);
          onChanged();
        },
      ),
    );
  }
}
