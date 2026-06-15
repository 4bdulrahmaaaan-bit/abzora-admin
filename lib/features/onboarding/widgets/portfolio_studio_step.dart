import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class PortfolioStudioStep extends StatelessWidget {
  final List<String> images;
  final int primaryIndex;
  final VoidCallback onAddImages;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onSetCover;
  final void Function(int oldIndex, int newIndex) onReorder;

  const PortfolioStudioStep({
    super.key,
    required this.images,
    required this.primaryIndex,
    required this.onAddImages,
    required this.onRemoveImage,
    required this.onSetCover,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    int qualityScore = 0;
    if (images.isNotEmpty) {
      qualityScore += (images.length / 10 * 60).clamp(0, 60).toInt();
      qualityScore += 40; // Cover image counts for the rest
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          context: context,
          title: 'Portfolio Studio (Optional)',
          children: [
            const Text(
              'Portfolio images help customers trust your store and improve store visibility.\nYou may upload them now or later from the Vendor Dashboard.',
              style: TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Portfolio Quality Score',
                  style: TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$qualityScore/100',
                  style: TextStyle(
                    color: qualityScore >= 80 ? VendorTheme.onboardingSuccess : (qualityScore > 40 ? VendorTheme.onboardingWarning : VendorTheme.onboardingError),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: qualityScore / 100,
                minHeight: 6,
                backgroundColor: VendorTheme.onboardingElevatedSurface,
                valueColor: AlwaysStoppedAnimation(
                  qualityScore >= 80 ? VendorTheme.onboardingSuccess : (qualityScore > 40 ? VendorTheme.onboardingWarning : VendorTheme.onboardingError),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Images Uploaded: ${images.length}/10',
                  style: const TextStyle(color: VendorTheme.onboardingPrimaryText, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (images.isNotEmpty)
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: VendorTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
                  border: Border.all(color: VendorTheme.onboardingElevatedSurface),
                ),
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: images.length,
                  onReorderItem: onReorder,
                  itemBuilder: (context, index) {
                    final isCover = index == primaryIndex;
                    return Container(
                      key: ValueKey(images[index]),
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                        border: Border.all(
                          color: isCover ? VendorTheme.onboardingGold : VendorTheme.onboardingElevatedSurface,
                          width: isCover ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: VendorTheme.onboardingGold),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error, color: VendorTheme.onboardingSecondaryText),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.8),
                                  ],
                                ),
                              ),
                            ),
                            if (isCover)
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: VendorTheme.onboardingGold,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'COVER',
                                    style: TextStyle(color: VendorTheme.onboardingBackground, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => onRemoveImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12, left: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => onSetCover(index),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isCover ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: isCover ? VendorTheme.onboardingGold : Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCover ? 'Cover' : 'Set Cover',
                                      style: TextStyle(
                                        color: isCover ? VendorTheme.onboardingGold : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isCover ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: VendorTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
                  border: Border.all(color: VendorTheme.onboardingElevatedSurface, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No portfolio images yet', style: TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Add up to 10 images to showcase your work.', style: TextStyle(color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (images.length < 10)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined, color: VendorTheme.onboardingGold),
                  label: const Text('Add Portfolio Files', style: TextStyle(color: VendorTheme.onboardingGold, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VendorTheme.onboardingGold),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VendorTheme.radiusSmall)),
                  ),
                ),
              ),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VendorTheme.onboardingPrimaryText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
