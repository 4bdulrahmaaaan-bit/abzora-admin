import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _reels = [
    {'image': 'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=600&q=80', 'product': 'Classic Linen Blazer', 'store': 'Zyla Fashion', 'price': 'Rs 4,999', 'likes': '12.4K', 'tag': 'MEN\'S ESSENTIALS'},
    {'image': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=80', 'product': 'Satin Evening Dress', 'store': 'Elite Threads', 'price': 'Rs 2,499', 'likes': '8.7K', 'tag': 'WOMEN\'S COLLECTION'},
    {'image': 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=600&q=80', 'product': 'Embroidered Sherwani', 'store': 'Moda Casa', 'price': 'Rs 12,999', 'likes': '21.3K', 'tag': 'WEDDING SPECIAL'},
    {'image': 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=600&q=80', 'product': 'Floral Summer Dress', 'store': 'Urban Vogue', 'price': 'Rs 1,599', 'likes': '5.2K', 'tag': 'SUMMER VIBES'},
  ];

  final Set<int> _wishlistedIndices = {};
  final Set<int> _likedIndices = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TRENDING REELS',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => _buildReelCard(index),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.4,
            child: Column(
              children: List.generate(
                _reels.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  width: 4,
                  height: index == _currentIndex ? 22 : 8,
                  decoration: BoxDecoration(
                    color: index == _currentIndex ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelCard(int index) {
    final width = MediaQuery.of(context).size.width;
    final reel = _reels[index];
    final isLiked = _likedIndices.contains(index);
    final isWishlisted = _wishlistedIndices.contains(index);

    return Stack(
      fit: StackFit.expand,
      children: [
        AbzioNetworkImage(
          imageUrl: reel['image'] as String,
          fallbackLabel: reel['product'] as String,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.86)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.4, 1],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 72,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              reel['tag'] as String,
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 140,
          child: Column(
            children: [
              _reelAction(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                reel['likes'] as String,
                isLiked ? Colors.red : Colors.white,
                () => setState(() => isLiked ? _likedIndices.remove(index) : _likedIndices.add(index)),
              ),
              const SizedBox(height: 24),
              _reelAction(
                isWishlisted ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                'Save',
                isWishlisted ? AbzioTheme.accentColor : Colors.white,
                () => setState(() => isWishlisted ? _wishlistedIndices.remove(index) : _wishlistedIndices.add(index)),
              ),
              const SizedBox(height: 24),
              _reelAction(
                Icons.shopping_bag_outlined,
                'Bag',
                Colors.white,
                () => Navigator.pushNamed(context, '/cart'),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: width < 360 ? 20 : 86,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reel['store'] as String,
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: AbzioTheme.accentColor, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                reel['product'] as String,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    reel['price'] as String,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      final cleanPrice = (reel['price'] as String).replaceAll('Rs', '').replaceAll(',', '').trim();
                      final product = Product(
                        id: 'reel-$index',
                        storeId: 'reel-store-$index',
                        name: reel['product'] as String,
                        description: 'Featured from the trending reels collection.',
                        price: double.tryParse(cleanPrice) ?? 0,
                        images: [reel['image'] as String],
                        sizes: const ['Free Size'],
                        stock: 10,
                        category: 'Trending',
                      );
                      context.read<CartProvider>().addToCart(product, 'Free Size');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.white,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          content: Text(
                            '${reel['product']} added to your bag.',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 13),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.black),
                          const SizedBox(width: 6),
                          Text(
                            'ADD TO BAG',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reelAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
