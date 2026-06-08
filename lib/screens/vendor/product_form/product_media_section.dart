import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme.dart';
import 'product_form_controller.dart';

class ProductMediaSection extends StatelessWidget {
  const ProductMediaSection({super.key});

  Future<void> _pickImages(BuildContext context, ProductFormController controller) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      // In a real app, you would upload to storage here
      // For this UI, we just simulate adding the path
      for (final image in images) {
        controller.addImage(image.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product Media',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.textPrimary,
                ),
              ),
              if (controller.imageUrls.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _pickImages(context, controller),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: Text('Add More', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least 1 image. First image is the cover. 4:5 fashion aspect ratio recommended.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AbzioTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (controller.imageUrls.isEmpty)
            GestureDetector(
              onTap: () => _pickImages(context, controller),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AbzioTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AbzioTheme.borderColor, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: AbzioTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to Upload Images',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AbzioTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG, WEBP up to 5MB',
                      style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 280,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.imageUrls.length,
                onReorder: controller.reorderImages,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final url = controller.imageUrls[index];
                  final isCover = index == 0;
                  return ReorderableDragStartListener(
                    key: ValueKey(url),
                    index: index,
                    child: Container(
                      width: 224, // 4:5 aspect ratio (224x280)
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                          onError: (_, __) => const NetworkImage('https://placehold.co/400x500/png'),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (isCover)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'COVER',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              children: [
                                if (!isCover)
                                  IconButton(
                                    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9)),
                                    icon: const Icon(Icons.star_rounded, size: 18, color: AbzioTheme.accentColor),
                                    onPressed: () => controller.markAsCover(index),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9)),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC03C2E)),
                                  onPressed: () => controller.removeImage(index),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
