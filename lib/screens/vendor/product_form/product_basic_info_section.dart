import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import '../../../config/product_attribute_config.dart';
import 'product_form_controller.dart';

class ProductBasicInfoSection extends StatelessWidget {
  const ProductBasicInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();
    final categories = productAttributeConfig.keys.toList();

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
            'Basic Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AbzioTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Product Name',
            controller: controller.nameController,
            hint: 'E.g. Premium Silk Blend Maxi Dress',
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Brand',
            controller: controller.brandController,
            hint: 'E.g. Abianzo Atelier',
            required: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Category',
                  value: controller.selectedCategory,
                  items: categories,
                  onChanged: (val) {
                    if (val != null) {
                      controller.updateCategory(val);
                    }
                  },
                  required: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Subcategory',
                  controller: TextEditingController(
                    text: controller.selectedSubcategory,
                  ), // Quick fix, usually binds to state better
                  hint: 'E.g. Party Wear',
                  onChanged: (val) => controller.updateSubcategory(val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Collection (Optional)',
            controller: controller.collectionController,
            hint: 'E.g. Festive Collection, New Arrivals',
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    Function(String)? onChanged,
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
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: AbzioTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 14,
            ),
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
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          onChanged: onChanged,
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
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                humanizeAttributeLabel(item),
                style: GoogleFonts.inter(color: AbzioTheme.textPrimary),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
