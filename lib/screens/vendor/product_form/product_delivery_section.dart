import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import 'product_form_controller.dart';

class ProductDeliverySection extends StatefulWidget {
  const ProductDeliverySection({super.key});

  @override
  State<ProductDeliverySection> createState() => _ProductDeliverySectionState();
}

class _ProductDeliverySectionState extends State<ProductDeliverySection> {
  final _etaOptions = ['Same Day', '1 Day', '2 Days', '3-5 Days', '1 Week'];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Settings',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AbzioTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildToggleChip(
                label: 'Same Day',
                icon: Icons.bolt_rounded,
                isActive: controller.sameDayDelivery,
                onToggle: controller.toggleSameDayDelivery,
              ),
              _buildToggleChip(
                label: 'COD',
                icon: Icons.payments_outlined,
                isActive: controller.cashOnDelivery,
                onToggle: controller.toggleCashOnDelivery,
              ),
              _buildToggleChip(
                label: 'Free Returns',
                icon: Icons.assignment_return_outlined,
                isActive: controller.freeReturns,
                onToggle: controller.toggleFreeReturns,
              ),
              _buildToggleChip(
                label: 'Try Before You Buy',
                icon: Icons.checkroom_outlined,
                isActive: controller.tryBeforeYouBuy,
                onToggle: controller.toggleTryBeforeYouBuy,
              ),
              _buildToggleChip(
                label: 'Express Delivery',
                icon: Icons.rocket_launch_outlined,
                isActive: controller.expressDelivery,
                onToggle: controller.toggleExpressDelivery,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Delivery Time (Standard)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: controller.etaDropdown,
                onChanged: (val) {
                  if (val != null) {
                    controller.updateEtaDropdown(val);
                  }
                },
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AbzioTheme.textSecondary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AbzioTheme.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AbzioTheme.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AbzioTheme.accentColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: _etaOptions.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: GoogleFonts.inter(color: AbzioTheme.textPrimary),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? const Color(0xFF16A34A) : AbzioTheme.lightBorder,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle_rounded : icon,
              size: 16,
              color: isActive ? const Color(0xFF16A34A) : AbzioTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFF16A34A) : AbzioTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
