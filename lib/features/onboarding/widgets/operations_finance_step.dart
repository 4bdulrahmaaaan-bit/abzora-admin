import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

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
          context: context,
          title: 'Pricing & Capacity',
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    startingPriceController,
                    'Starting Price (Rs)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    upperPriceController,
                    'Typical Upper (Rs)',
                    icon: Icons.currency_rupee,
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
                    icon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    monthlyCapacityController,
                    'Monthly Capacity',
                    icon: Icons.inventory_2_outlined,
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
          context: context,
          title: 'Finance & Payouts',
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: VendorTheme.onboardingSuccess.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                border: Border.all(color: VendorTheme.onboardingSuccess.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: VendorTheme.onboardingSuccess, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank-grade security',
                          style: TextStyle(color: VendorTheme.onboardingSuccess, fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your payout information is encrypted and securely stored for automatic weekly settlements.',
                          style: TextStyle(color: VendorTheme.onboardingSuccess, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildDropdown(
              'Settlement Schedule',
              settlementPreference,
              ['Weekly', 'Bi-Weekly', 'Monthly'],
              onSettlementChanged,
              icon: Icons.event_repeat_outlined,
            ),
            _buildDropdown(
              'Preferred Payment Method',
              preferredPaymentMethod,
              ['Bank Transfer', 'UPI'],
              onPaymentMethodChanged,
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 16),
            if (preferredPaymentMethod == 'Bank Transfer') ...[
              _buildField(
                bankAccountController,
                'Bank Account Number',
                icon: Icons.numbers_outlined,
                hint: '1234567890',
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              _buildField(
                confirmBankAccountController,
                'Confirm Bank Account Number',
                icon: Icons.password_outlined,
                hint: '1234567890',
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              _buildField(
                ifscController,
                'IFSC Code',
                icon: Icons.account_balance_wallet_outlined,
                hint: 'HDFC0001234',
              ),
            ] else ...[
              _buildField(
                upiController,
                'UPI ID',
                icon: Icons.qr_code_2_outlined,
                hint: 'user@upi',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required BuildContext context, required String title, required List<Widget> children}) {
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: VendorTheme.onboardingPrimaryText,
                  fontWeight: FontWeight.w700,
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
    IconData? icon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(color: VendorTheme.onboardingPrimaryText, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: VendorTheme.onboardingSecondaryText),
          hintText: hint.isEmpty ? null : hint,
          hintStyle: TextStyle(color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.3)),
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
        onChanged: (_) => onChanged(),
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
        items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (val) {
          onSelect(val);
          onChanged();
        },
      ),
    );
  }
}
