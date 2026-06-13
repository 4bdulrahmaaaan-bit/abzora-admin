import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import 'product_form_controller.dart';

class ProductPricingSection extends StatelessWidget {
  const ProductPricingSection({super.key});

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
            'Pricing',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AbzioTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPriceField(
                  label: 'MRP',
                  controller: controller.mrpController,
                  hint: '₹ 0.00',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPriceField(
                  label: 'Selling Price',
                  controller: controller.sellingPriceController,
                  hint: '₹ 0.00',
                  required: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.discountPercentage > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${controller.discountPercentage.toStringAsFixed(0)}% OFF',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'You save ₹${controller.amountSaved.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: controller.taxIncluded,
                onChanged: controller.toggleTaxIncluded,
                activeColor: AbzioTheme.accentColor,
              ),
              Text(
                'Price includes taxes',
                style: GoogleFonts.inter(
                  color: AbzioTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AbzioTheme.textPrimary,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: GoogleFonts.inter(color: const Color(0xFFC03C2E)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: AbzioTheme.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            prefixIcon: const Icon(
              Icons.currency_rupee_rounded,
              size: 18,
              color: AbzioTheme.textSecondary,
            ),
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
        ),
      ],
    );
  }
}
