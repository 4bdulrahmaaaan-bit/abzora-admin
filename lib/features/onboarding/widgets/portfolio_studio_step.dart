import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
          title: 'Portfolio Studio',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Portfolio Score',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '$qualityScore / 100',
                  style: TextStyle(
                    color: qualityScore >= 80 ? Colors.green : (qualityScore > 40 ? Colors.orange : Colors.red),
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
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                  qualityScore >= 80 ? Colors.green : (qualityScore > 40 ? Colors.orange : Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Images Uploaded: ${images.length}/10',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (images.length < 5)
                  const Text(
                    '(Min 5 req.)',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (images.isNotEmpty)
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCover ? Colors.amber : Colors.white12,
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white38),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                            ),
                            if (isCover)
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.all(Radius.circular(4)),
                                  ),
                                  child: Text(
                                    'COVER',
                                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => onRemoveImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8, left: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => onSetCover(index),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isCover ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: isCover ? Colors.amber : Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isCover ? 'Cover' : 'Set Cover',
                                      style: TextStyle(
                                        color: isCover ? Colors.amber : Colors.white70,
                                        fontSize: 12,
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
              ),
            const SizedBox(height: 16),
            if (images.length < 10)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
                  label: const Text('Add Portfolio Files', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
