import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import '../../../models/models.dart';
import 'product_form_controller.dart';

class ProductPublishBar extends StatelessWidget {
  final VoidCallback onSaveDraft;
  final VoidCallback onPreview;
  final VoidCallback onPublish;

  const ProductPublishBar({
    super.key,
    required this.onSaveDraft,
    required this.onPreview,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();
    final isDraft = controller.status == ProductStatus.draft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AbzioTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onSaveDraft,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AbzioTheme.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isDraft ? 'Save Draft' : 'Unpublish to Draft',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AbzioTheme.accentColor.withOpacity(0.5)),
                  backgroundColor: const Color(0xFFF9FAFB),
                  foregroundColor: AbzioTheme.accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: Text(
                  'Preview',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: onPublish,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AbzioTheme.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Publish Product',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
