import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme.dart';
import '../../../services/storage_service.dart';
import 'product_form_controller.dart';

class ProductMediaSection extends StatefulWidget {
  const ProductMediaSection({super.key});

  @override
  State<ProductMediaSection> createState() => _ProductMediaSectionState();
}

class _ProductMediaSectionState extends State<ProductMediaSection> {
  final StorageService _storage = StorageService();
  bool _uploading = false;

  Future<void> _pickImages(
    BuildContext context,
    ProductFormController controller,
  ) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty || _uploading) {
      return;
    }

    setState(() => _uploading = true);
    try {
      for (final image in images) {
        final uploadedUrl = await _storage.uploadPickedImage(
          file: image,
          folder: 'product_images',
          ownerId: controller.storeId,
          fileName: 'product_${DateTime.now().millisecondsSinceEpoch}',
        );
        controller.addImage(uploadedUrl);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed: $error'),
          backgroundColor: const Color(0xFFC03C2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
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
        border: Border.all(color: AbzioTheme.lightBorder),
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
                  onPressed: _uploading
                      ? null
                      : () => _pickImages(context, controller),
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Add More',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
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
              onTap: _uploading ? null : () => _pickImages(context, controller),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AbzioTheme.lightMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AbzioTheme.lightBorder,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _uploading
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              color: AbzioTheme.accentColor,
                            ),
                          )
                        : const Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: AbzioTheme.textSecondary,
                          ),
                    const SizedBox(height: 12),
                    Text(
                      _uploading ? 'Uploading to Cloudinary...' : 'Tap to Upload Images',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG, WEBP up to 5MB',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AbzioTheme.textSecondary,
                      ),
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
                onReorderItem: (oldIndex, newIndex) =>
                    controller.reorderImages(oldIndex, newIndex),
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final url = controller.imageUrls[index];
                  final isCover = index == 0;
                  return ReorderableDragStartListener(
                    key: ValueKey(url),
                    index: index,
                    child: Container(
                      width: 224,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (isCover)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
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
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: AbzioTheme.accentColor,
                                    ),
                                    onPressed: () =>
                                        controller.markAsCover(index),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFC03C2E),
                                  ),
                                  onPressed: () =>
                                      controller.removeImage(index),
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
