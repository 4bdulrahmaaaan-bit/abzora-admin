import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import 'product_form_controller.dart';

class ProductAiSection extends StatefulWidget {
  const ProductAiSection({super.key});

  @override
  State<ProductAiSection> createState() => _ProductAiSectionState();
}

class _ProductAiSectionState extends State<ProductAiSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.lightBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: 24,
          ),
          onExpansionChanged: (val) => setState(() => _expanded = val),
          title: Text(
            'Advanced Fashion Assets',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AbzioTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'For AR, AI Styling and Virtual Try-On',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AbzioTheme.textSecondary,
            ),
          ),
          trailing: Icon(
            _expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: AbzioTheme.textSecondary,
          ),
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These fields are for technical integration with Abianzo 3D engine. Leave blank if you are not uploading 3D assets.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              label: 'GLB Model URL',
              controller: controller.glbModelController,
              hint: 'https://...',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: '3D Asset Bundle URL',
              controller: controller.assetBundleUrlController,
              hint: 'https://...',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Rig Profile',
                    controller: controller.rigProfileController,
                    hint: 'e.g. humanoid_v2',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'Material Profile',
                    controller: controller.materialProfileController,
                    hint: 'e.g. standard_pbr',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Avatar Mapping Metadata',
              controller: controller.avatarMappingController,
              hint: 'JSON mapping data',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Physics Metadata',
              controller: controller.physicsMetadataController,
              hint: 'JSON physics data',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'AR Metadata',
              controller: controller.arMetadataController,
              hint: 'JSON AR data',
              maxLines: 2,
            ),
          ],
        ),
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
            fontSize: 13,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: AbzioTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: AbzioTheme.textSecondary.withValues(alpha: 0.5),
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
}
