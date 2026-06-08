import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import '../../../config/product_attribute_config.dart';
import 'product_form_controller.dart';

class ProductDetailsSection extends StatelessWidget {
  const ProductDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();
    final template = getProductAttributeTemplate(controller.selectedCategory, controller.selectedSubcategory);

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
            'Product Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AbzioTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Attributes dynamically generated for ${controller.selectedCategory}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AbzioTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Description',
            controller: controller.descriptionController,
            hint: 'Tell the story of your product...',
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          ...template.sections.map((section) {
            final validFields = section.fields.where((key) => template.fields.containsKey(key)).toList();
            if (validFields.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  section.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...validFields.map((fieldKey) {
                  final config = template.fields[fieldKey]!;
                  final textCtrl = controller.attributeControllers[fieldKey];
                  if (textCtrl == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: config.type == ProductAttributeFieldType.dropdown && config.options.isNotEmpty
                        ? _buildDropdown(
                            label: config.label,
                            value: textCtrl.text,
                            items: config.options,
                            onChanged: (val) {
                              if (val != null) {
                                textCtrl.text = val;
                              }
                            },
                          )
                        : _buildTextField(
                            label: config.label,
                            controller: textCtrl,
                            hint: 'Enter ${config.label.toLowerCase()}',
                          ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AbzioTheme.textSecondary.withValues(alpha: 0.5), fontSize: 14),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          onChanged: onChanged,
          hint: Text('Select $label', style: GoogleFonts.inter(color: AbzioTheme.textSecondary.withValues(alpha: 0.5))),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AbzioTheme.textSecondary),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items.map((item) {
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
    );
  }
}
