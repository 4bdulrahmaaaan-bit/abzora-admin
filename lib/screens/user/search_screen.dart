import 'dart:async';

import 'package:flutter/material.dart';
import '../../config/product_attribute_config.dart';

import '../../constants/text_constants.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.allProducts,
    required this.selectedLocation,
    this.initialQuery = '',
  });

  final List<Product> allProducts;
  final String selectedLocation;
  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _recent = <String>[];
  Timer? _debounce;
  String _query = '';
  SearchFilter _filter = const SearchFilter();

  static const _trends = <String>[
    'Wedding Edit',
    'Summer Linen',
    'Luxury Footwear',
    'Boutique Sarees',
    'Evening Wear',
  ];

  static const _categories = <String>[
    'Men',
    'Women',
    'Footwear',
    'Accessories',
    'Beauty',
    'Jewelry',
  ];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _rememberSearch(widget.initialQuery);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final queryMatches = query.isEmpty
        ? const <Product>[]
        : widget.allProducts.where((product) {
            return _searchText(product).contains(query);
          }).toList();
    final results = _applyFilters(queryMatches, _filter);

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5EF),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchHeader(
                selectedLocation: widget.selectedLocation,
                selectedCount: _filter.selectedFiltersCount,
                onBack: () => Navigator.pop(context),
                onFilterTap: () => _openFilterModal(queryMatches),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    _SearchBar(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      onClear: _controller.text.trim().isEmpty
                          ? null
                          : () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                    ),
                    const SizedBox(height: 22),
                    if (query.isEmpty)
                      ..._buildDiscovery()
                    else if (results.isEmpty) ...[
                      const SizedBox(height: 42),
                      const AbzioEmptyCard(
                        title: AbianzoText.searchEmptyTitle,
                        subtitle: AbianzoText.searchEmptySubtitle,
                      ),
                    ] else ...[
                      _ResultsHeader(
                        count: results.length,
                        query: _controller.text.trim(),
                      ),
                      const SizedBox(height: 14),
                      ...results.map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SearchResultCard(
                            product: product,
                            onTap: () {
                              _rememberSearch(_controller.text.trim());
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailScreen(product: product),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDiscovery() {
    return [
      _Section(
        title: 'Recent Searches',
        child: _recent.isEmpty
            ? Text(
                'Your recent searches will appear here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                ),
              )
            : Column(
                children: _recent.take(5).map((item) {
                  return _RecentSearchRow(
                    label: item,
                    onTap: () => _submitSearch(item),
                    onClear: () => setState(() => _recent.remove(item)),
                  );
                }).toList(),
              ),
      ),
      const SizedBox(height: 22),
      _Section(
        title: 'Trending Now',
        child: _TrendRail(
          items: _trends
              .map((label) => _DiscoveryItem(label, _imageFor(label)))
              .toList(),
          onTap: _submitSearch,
        ),
      ),
      const SizedBox(height: 22),
      _Section(
        title: 'Popular Categories',
        child: _CategoryRail(
          items: _categories
              .map((label) => _DiscoveryItem(label, _imageFor(label)))
              .toList(),
          onTap: _submitSearch,
        ),
      ),
      const SizedBox(height: 22),
      _Section(
        title: 'Featured Brands',
        child: _BrandRail(items: _featuredBrands(), onTap: _submitSearch),
      ),
      const SizedBox(height: 22),
      _Section(
        title: 'Boutiques Near You',
        child: _BoutiqueRail(items: _boutiques()),
      ),
    ];
  }

  void _submitSearch(String value) {
    _controller.text = value;
    _focusNode.requestFocus();
    _onQueryChanged(value);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() => _query = value);
      _rememberSearch(value);
    });
  }

  void _rememberSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _recent.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    _recent.insert(0, trimmed);
    if (_recent.length > 5) {
      _recent.removeLast();
    }
  }

  String _searchText(Product product) {
    return [
      product.name,
      product.brand,
      product.description,
      product.category,
      product.subcategory,
      product.store?.name ?? '',
      product.fabric ?? '',
      product.outfitType ?? '',
      product.highlights.join(' '),
      product.attributes.values.join(' '),
    ].join(' ').toLowerCase();
  }

  List<Product> _applyFilters(List<Product> products, SearchFilter filter) {
    final filtered = products.where((product) {
      if (product.effectivePrice < filter.priceRange.start ||
          product.effectivePrice > filter.priceRange.end) {
        return false;
      }
      if (filter.category != 'All' &&
          !_contains(product, filter.category, ['category'])) {
        return false;
      }
      if (filter.gender != 'All' &&
          !_contains(product, filter.gender, ['gender'])) {
        return false;
      }
      if (filter.brand != 'All' &&
          product.brand.toLowerCase() != filter.brand.toLowerCase()) {
        return false;
      }
      if (filter.size != 'All' &&
          !product.sizes
              .map((size) => size.toUpperCase())
              .contains(filter.size.toUpperCase())) {
        return false;
      }
      if (filter.color != 'All' &&
          !_contains(product, filter.color, ['color'])) {
        return false;
      }
      if (filter.occasion != 'All' &&
          !_contains(product, filter.occasion, ['occasion'])) {
        return false;
      }
      if (filter.sameDayAvailable && !product.sameDayAvailable) {
        return false;
      }
      if (filter.tryAtHomeAvailable && !product.tryAtHomeAvailable) {
        return false;
      }
      if (filter.customizable &&
          !(product.isCustomTailoring ||
              product.attributeBool('customizable', fallback: false))) {
        return false;
      }
      if (product.rating < filter.minRating) {
        return false;
      }
      return _matchesAdvancedFilters(product, filter);
    }).toList();

    filtered.sort((left, right) {
      switch (filter.sort) {
        case ProductSortOption.priceLowToHigh:
          return left.effectivePrice.compareTo(right.effectivePrice);
        case ProductSortOption.priceHighToLow:
          return right.effectivePrice.compareTo(left.effectivePrice);
        case ProductSortOption.newest:
          final leftDate =
              DateTime.tryParse(left.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              DateTime.tryParse(right.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return rightDate.compareTo(leftDate);
        case ProductSortOption.popularity:
          return _score(right).compareTo(_score(left));
        case ProductSortOption.sameDayPriority:
          if (left.sameDayAvailable != right.sameDayAvailable) {
            return left.sameDayAvailable ? -1 : 1;
          }
          return _score(right).compareTo(_score(left));
        case ProductSortOption.relevance:
          return _relevance(right).compareTo(_relevance(left));
      }
    });
    return filtered;
  }

  bool _matchesAdvancedFilters(Product product, SearchFilter filter) {
    for (final entry in filter.attributeFilters.entries) {
      final values = entry.value
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isEmpty) {
        continue;
      }
      if (!values.any((value) => _contains(product, value, [entry.key]))) {
        return false;
      }
    }
    for (final entry in filter.attributeFlags.entries) {
      if (!entry.value) {
        continue;
      }
      if (!_flag(product, entry.key)) {
        return false;
      }
    }
    return true;
  }

  bool _contains(Product product, String value, List<String> keys) {
    final candidate = value.toLowerCase().trim();
    final tokens = <String>{
      product.name,
      product.brand,
      product.category,
      product.subcategory,
      product.fabric ?? '',
      product.outfitType ?? '',
      ...product.sizes,
      ...product.colorVariants.map((variant) => variant.colorName),
      ...product.highlights,
    }.map((item) => item.toLowerCase().trim()).where((item) => item.isNotEmpty);

    final allTokens = {...tokens};
    for (final key in keys) {
      final normalized = key.toLowerCase().replaceAll(' ', '_');
      allTokens.addAll(
        product.attributeList(normalized).map((item) => item.toLowerCase()),
      );
      final text = product.attributeText(normalized).toLowerCase().trim();
      if (text.isNotEmpty) {
        allTokens.add(text);
      }
    }
    return allTokens.any(
      (token) =>
          token == candidate ||
          token.contains(candidate) ||
          candidate.contains(token),
    );
  }

  bool _flag(Product product, String key) {
    final normalized = key.toLowerCase().replaceAll(' ', '_');
    if (normalized.contains('ar') || normalized.contains('try_on')) {
      return product.tryOnAvailable;
    }
    if (normalized.contains('custom')) {
      return product.isCustomTailoring || product.attributeBool('customizable');
    }
    if (normalized.contains('try_at_home')) {
      return product.tryAtHomeAvailable;
    }
    return product.attributeBool(normalized);
  }

  int _score(Product product) {
    return (product.demandScore * 100).round() +
        product.viewCount +
        (product.purchaseCount * 4) +
        (product.rating * 10).round();
  }

  int _relevance(Product product) {
    var score = _score(product);
    if (product.sameDayAvailable) {
      score += 30;
    }
    if (product.tryOnAvailable) {
      score += 22;
    }
    if (product.isCustomTailoring) {
      score += 18;
    }
    return score;
  }

  Future<void> _openFilterModal(List<Product> baseMatches) async {
    final result = await Navigator.of(context).push<SearchFilter>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _SearchFilterModal(
          initialFilter: _filter,
          allProducts: widget.allProducts,
          previewCount: (next) => _applyFilters(baseMatches, next).length,
        ),
      ),
    );
    if (result != null) {
      setState(() => _filter = result);
    }
  }

  String _imageFor(String label) {
    final normalized = label.toLowerCase();
    final matched = widget.allProducts.where((product) {
      final text = _searchText(product);
      return text.contains(normalized) ||
          normalized.split(' ').any((part) => text.contains(part));
    });
    for (final product in matched.followedBy(widget.allProducts)) {
      if (product.images.isNotEmpty) {
        return product.images.first;
      }
    }
    return '';
  }

  List<_BrandItem> _featuredBrands() {
    final brands = <String, Product>{};
    for (final product in widget.allProducts) {
      final brand = product.brand.trim();
      if (brand.isNotEmpty) {
        brands.putIfAbsent(brand, () => product);
      }
    }
    final entries = brands.entries.toList()
      ..sort((a, b) => _score(b.value).compareTo(_score(a.value)));
    return entries
        .take(10)
        .map(
          (entry) => _BrandItem(
            entry.key,
            entry.value.images.isNotEmpty ? entry.value.images.first : '',
          ),
        )
        .toList();
  }

  List<_BoutiqueItem> _boutiques() {
    final seen = <String, Product>{};
    for (final product in widget.allProducts) {
      final id = product.storeId.isNotEmpty
          ? product.storeId
          : (product.store?.name ?? product.brand);
      if (id.trim().isNotEmpty) {
        seen.putIfAbsent(id.trim(), () => product);
      }
    }
    final products = seen.values.toList()
      ..sort((a, b) => _score(b).compareTo(_score(a)));
    return products.take(6).map((product) {
      final store = product.store;
      final name = store?.name.trim().isNotEmpty == true
          ? store!.name.trim()
          : (product.boutiqueInfo['name']?.toString().trim().isNotEmpty == true
                ? product.boutiqueInfo['name'].toString().trim()
                : (product.brand.trim().isNotEmpty
                      ? product.brand.trim()
                      : 'Curated Boutique'));
      final imageUrl = store?.bannerImageUrl.trim().isNotEmpty == true
          ? store!.bannerImageUrl
          : (store?.imageUrl.trim().isNotEmpty == true
                ? store!.imageUrl
                : (product.images.isNotEmpty ? product.images.first : ''));
      final index = products.indexOf(product);
      final distance = product.boutiqueInfo['distanceKm'] is num
          ? (product.boutiqueInfo['distanceKm'] as num).toDouble()
          : 2.4 + (index * 0.7);
      final rating = store?.rating != null && store!.rating > 0
          ? store.rating
          : product.rating;
      return _BoutiqueItem(name, imageUrl, distance, rating);
    }).toList();
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.selectedLocation,
    required this.selectedCount,
    required this.onBack,
    required this.onFilterTap,
  });

  final String selectedLocation;
  final int selectedCount;
  final VoidCallback onBack;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14110D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6A6257),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _CircleButton(icon: Icons.tune_rounded, onTap: onFilterTap),
              if (selectedCount > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF17130F),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$selectedCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DDCC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E0904),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search brands, styles, boutiques, designers',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: const Color(0xFF17130F)),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF17130F),
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow({
    required this.label,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF8A6E34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF17130F),
                ),
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendRail extends StatelessWidget {
  const _TrendRail({required this.items, required this.onTap});

  final List<_DiscoveryItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 154,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => onTap(item.label),
            child: Container(
              width: 176,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEDE3D3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AbzioNetworkImage(
                    imageUrl: item.imageUrl,
                    fallbackLabel: item.label,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.46),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.items, required this.onTap});

  final List<_DiscoveryItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => onTap(item.label),
            child: SizedBox(
              width: 82,
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE7D7B8)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AbzioNetworkImage(
                      imageUrl: item.imageUrl,
                      fallbackLabel: item.label,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BrandRail extends StatelessWidget {
  const _BrandRail({required this.items, required this.onTap});

  final List<_BrandItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final source = items.isEmpty
        ? const [_BrandItem('Atelier', ''), _BrandItem('Maison', '')]
        : items;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: source.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = source[index];
          return GestureDetector(
            onTap: () => onTap(item.name),
            child: Container(
              width: 132,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEDE3D3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF4EAD5),
                      border: Border.all(color: const Color(0xFFD8C08A)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.imageUrl.isEmpty
                        ? Text(
                            item.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF8A6E34),
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : AbzioNetworkImage(
                            imageUrl: item.imageUrl,
                            fallbackLabel: item.name,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoutiqueRail extends StatelessWidget {
  const _BoutiqueRail({required this.items});

  final List<_BoutiqueItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Boutiques will appear once products are available nearby.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
      );
    }
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDE3D3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: AbzioNetworkImage(
                    imageUrl: item.imageUrl,
                    fallbackLabel: item.name,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text('${item.distanceKm.toStringAsFixed(1)} km'),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFB38A34),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.rating <= 0
                                ? 'New'
                                : item.rating.toStringAsFixed(1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.query});

  final int count;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count results',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Showing matches for "$query".',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E7C8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('Curated'),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images.isNotEmpty ? product.images.first : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDE3D3)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 108,
                  width: 92,
                  child: AbzioNetworkImage(
                    imageUrl: imageUrl,
                    fallbackLabel: product.name,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.trim().isEmpty
                          ? product.category.toUpperCase()
                          : product.brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9A7A34),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${product.effectivePrice.toInt()}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: context.abzioSecondaryText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFilterModal extends StatefulWidget {
  const _SearchFilterModal({
    required this.initialFilter,
    required this.allProducts,
    required this.previewCount,
  });

  final SearchFilter initialFilter;
  final List<Product> allProducts;
  final int Function(SearchFilter filter) previewCount;

  @override
  State<_SearchFilterModal> createState() => _SearchFilterModalState();
}

class _SearchFilterModalState extends State<_SearchFilterModal> {
  late SearchFilter _draft;
  final TextEditingController _brandSearchController = TextEditingController();
  String _brandSearch = '';

  String? _activeFilterKey;
  final Map<String, Map<String, int>> _cachedCounts = {};

  List<String> _orderedFilterKeys = [];
  Map<String, String> _filterLabels = {};
  Map<String, ProductAttributeFieldConfig> _activeFields = {};

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
    _resolveFilters();
  }

  @override
  void dispose() {
    _brandSearchController.dispose();
    super.dispose();
  }

  void _update(SearchFilter next) {
    setState(() {
      _cachedCounts.clear();
      _draft = next;
      _resolveFilters();
    });
  }

  void _resolveFilters() {
    final Set<String> keys = {};
    _filterLabels = {};
    _activeFields = {};

    final baseLabels = {
      'category': 'Category',
      'gender': 'Gender',
      'brand': 'Brand',
      'price': 'Price',
      'size': 'Size',
      'color': 'Color',
      'availability': 'Availability',
      'rating': 'Rating',
      'sort': 'Sort By',
    };

    final templateKeys = <String>[];
    if (_draft.category != 'All' &&
        productAttributeTemplates.containsKey(_draft.category.toLowerCase())) {
      final template =
          productAttributeTemplates[_draft.category.toLowerCase()]!;
      for (final section in template.sections) {
        templateKeys.addAll(section.fields);
      }
      _activeFields.addAll(template.fields);
    } else {
      for (final template in productAttributeTemplates.values) {
        for (final section in template.sections) {
          for (final f in section.fields) {
            if (!templateKeys.contains(f)) templateKeys.add(f);
          }
        }
        _activeFields.addAll(template.fields);
      }
    }

    for (final k in ['category', 'gender', 'brand', 'price', 'size', 'color']) {
      if (k == 'size' && templateKeys.contains('available_sizes')) continue;
      keys.add(k);
      _filterLabels[k] = baseLabels[k]!;
    }

    for (final k in templateKeys) {
      keys.add(k);
      _filterLabels[k] = _activeFields[k]?.label ?? k;
    }

    for (final k in ['availability', 'rating', 'sort']) {
      keys.add(k);
      _filterLabels[k] = baseLabels[k]!;
    }

    _orderedFilterKeys = keys.toList();

    if (_activeFilterKey == null ||
        !_orderedFilterKeys.contains(_activeFilterKey)) {
      _activeFilterKey = _orderedFilterKeys.first;
    }
  }

  int _getCountForOption(String filterKey, String optionValue) {
    if (_cachedCounts.containsKey(filterKey) &&
        _cachedCounts[filterKey]!.containsKey(optionValue)) {
      return _cachedCounts[filterKey]![optionValue]!;
    }

    SearchFilter testFilter = _draft;
    if (filterKey == 'category') {
      testFilter = testFilter.copyWith(category: optionValue);
    } else if (filterKey == 'gender') {
      testFilter = testFilter.copyWith(gender: optionValue);
    } else if (filterKey == 'brand') {
      testFilter = testFilter.copyWith(brand: optionValue);
    } else if (filterKey == 'size') {
      testFilter = testFilter.copyWith(size: optionValue);
    } else if (filterKey == 'color') {
      testFilter = testFilter.copyWith(color: optionValue);
    } else if (filterKey == 'rating') {
      final rating = optionValue == 'All'
          ? 0.0
          : double.parse(optionValue.replaceAll('+', ''));
      testFilter = testFilter.copyWith(minRating: rating);
    } else {
      final currentList = testFilter.attributeFilters[filterKey] ?? [];
      final nextList = [...currentList];
      if (!nextList.any((e) => e.toLowerCase() == optionValue.toLowerCase())) {
        nextList.add(optionValue);
      }
      testFilter = testFilter.copyWith(
        attributeFilters: {...testFilter.attributeFilters, filterKey: nextList},
      );
    }

    final count = widget.previewCount(testFilter);
    _cachedCounts.putIfAbsent(filterKey, () => {})[optionValue] = count;
    return count;
  }

  int _getSelectedCountForFilter(String key) {
    int count = 0;
    if (key == 'category' && _draft.category != 'All') {
      count = 1;
    } else if (key == 'gender' && _draft.gender != 'All') {
      count = 1;
    } else if (key == 'brand' && _draft.brand != 'All') {
      count = 1;
    } else if (key == 'size' && _draft.size != 'All') {
      count = 1;
    } else if (key == 'color' && _draft.color != 'All') {
      count = 1;
    } else if (key == 'price') {
      if (_draft.priceRange.start > 0 || _draft.priceRange.end < 10000) {
        count = 1;
      }
    } else if (key == 'availability') {
      if (_draft.sameDayAvailable) count++;
      if (_draft.tryAtHomeAvailable) count++;
    } else if (key == 'rating' && _draft.minRating > 0) {
      count = 1;
    } else if (key == 'sort' && _draft.sort != ProductSortOption.relevance) {
      count = 1;
    } else if (_draft.attributeFilters.containsKey(key)) {
      count = _draft.attributeFilters[key]!.length;
    } else if (_draft.attributeFlags.containsKey(key) &&
        _draft.attributeFlags[key] == true) {
      count = 1;
    }
    return count;
  }

  IconData _getIconForFilter(String key) {
    switch (key) {
      case 'category':
        return Icons.category_rounded;
      case 'gender':
        return Icons.wc_rounded;
      case 'brand':
        return Icons.branding_watermark_rounded;
      case 'price':
        return Icons.payments_rounded;
      case 'size':
      case 'available_sizes':
        return Icons.straighten_rounded;
      case 'color':
        return Icons.palette_rounded;
      case 'material':
      case 'fabric':
        return Icons.texture_rounded;
      case 'fit':
        return Icons.accessibility_new_rounded;
      case 'occasion':
        return Icons.event_rounded;
      case 'pattern':
        return Icons.pattern_rounded;
      case 'availability':
        return Icons.inventory_2_rounded;
      case 'rating':
        return Icons.star_rounded;
      case 'sort':
        return Icons.sort_rounded;
      case 'sleeve_length':
      case 'sleeve_type':
        return Icons.checkroom_rounded;
      case 'neck_type':
        return Icons.portrait_rounded;
      default:
        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.previewCount(_draft);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5EF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Text(
              'Filter',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _update(const SearchFilter()),
              child: const Text(
                'Reset',
                style: TextStyle(color: Color(0xFF8C8273)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              child: const Text(
                'Apply',
                style: TextStyle(
                  color: Color(0xFF17130F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEDE3D3))),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF17130F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Show $count Results',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F5EF),
              border: Border(right: BorderSide(color: Color(0xFFEDE3D3))),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _orderedFilterKeys.map((key) {
                final isSelected = _activeFilterKey == key;
                final selectedCount = _getSelectedCountForFilter(key);

                return InkWell(
                  onTap: () => setState(() => _activeFilterKey = key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isSelected
                              ? const Color(0xFFC6A769)
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: selectedCount > 0,
                          label: Text(selectedCount.toString()),
                          backgroundColor: const Color(0xFFC6A769),
                          textColor: Colors.white,
                          child: Icon(
                            _getIconForFilter(key),
                            color: isSelected
                                ? const Color(0xFF17130F)
                                : const Color(0xFF8C8273),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterLabels[key]!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF17130F)
                                : const Color(0xFF8C8273),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_activeFilterKey),
                  child: _buildActiveFilterContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterContent() {
    if (_activeFilterKey == null) return const SizedBox.shrink();
    final key = _activeFilterKey!;

    Widget content;
    switch (key) {
      case 'category':
        content = _chipSelector(
          _categories(),
          _draft.category,
          (value) => _update(_draft.copyWith(category: value)),
          key,
        );
        break;
      case 'gender':
        content = _chipSelector(
          const ['All', 'Men', 'Women', 'Unisex', 'Kids'],
          _draft.gender,
          (value) => _update(_draft.copyWith(gender: value)),
          key,
        );
        break;
      case 'brand':
        content = _brandSelector();
        break;
      case 'price':
        content = _priceSelector();
        break;
      case 'size':
        content = _chipSelector(
          const ['All', 'XS', 'S', 'M', 'L', 'XL', 'XXL'],
          _draft.size,
          (value) => _update(_draft.copyWith(size: value)),
          key,
        );
        break;
      case 'color':
        content = _colorSelector();
        break;
      case 'availability':
        content = _availabilitySelector();
        break;
      case 'rating':
        content = _ratingSelector();
        break;
      case 'sort':
        content = _sortSelector();
        break;
      default:
        if (_activeFields.containsKey(key)) {
          final field = _activeFields[key]!;
          if (field.type == ProductAttributeFieldType.boolean) {
            content = _flagSelector(key, field.label);
          } else {
            final options = field.options.isNotEmpty
                ? field.options
                : _getDynamicOptions(key);
            content = _attributeSelector(key, options);
          }
        } else {
          content = const SizedBox.shrink();
        }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _filterLabels[key] ?? '',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Expanded(child: content),
      ],
    );
  }

  Widget _chipSelector(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
    String filterKey,
  ) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: values.map((value) {
          final isSelected = selected.toLowerCase() == value.toLowerCase();
          final count = _getCountForOption(filterKey, value);

          if (count == 0 && !isSelected) return const SizedBox.shrink();

          return _LuxuryChip(
            label: value == 'All' ? value : '$value ($count)',
            selected: isSelected,
            onTap: () => onChanged(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _brandSelector() {
    final brands = _brands()
        .where(
          (brand) => brand.toLowerCase().contains(_brandSearch.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _brandSearchController,
          onChanged: (value) => setState(() => _brandSearch = value),
          decoration: InputDecoration(
            hintText: 'Search brand',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: const Color(0xFFF8F5EF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _chipSelector(
            ['All', ...brands],
            _draft.brand,
            (value) => _update(_draft.copyWith(brand: value)),
            'brand',
          ),
        ),
      ],
    );
  }

  Widget _priceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '₹{_draft.priceRange.start.toInt()} - ₹{_draft.priceRange.end.toInt()',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        RangeSlider(
          values: _draft.priceRange,
          min: 0,
          max: 10000,
          divisions: 20,
          activeColor: const Color(0xFF9A7A34),
          onChanged: (value) => _update(_draft.copyWith(priceRange: value)),
        ),
      ],
    );
  }

  Widget _colorSelector() {
    final colors = <String, Color>{
      'All': Colors.transparent,
      'Black': Colors.black,
      'White': Colors.white,
      'Ivory': const Color(0xFFF8F5EF),
      'Gold': const Color(0xFFC6A769),
      'Red': const Color(0xFF8F1D2C),
      'Blue': const Color(0xFF243C66),
      'Green': const Color(0xFF355C45),
    };
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: colors.entries.map((entry) {
          final isSelected = _draft.color == entry.key;
          final count = _getCountForOption('color', entry.key);

          if (count == 0 && !isSelected) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () => _update(_draft.copyWith(color: entry.key)),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.value,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF17130F)
                          : const Color(0xFFD9CCB9),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: entry.key == 'All'
                      ? const Icon(Icons.all_inclusive_rounded, size: 18)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.key == 'All' ? entry.key : '${entry.key}\n({count})',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _attributeSelector(String key, List<String> values) {
    final selected = _draft.attributeFilters[key] ?? const <String>[];
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: values.map((value) {
          final isSelected = selected.any(
            (item) => item.toLowerCase() == value.toLowerCase(),
          );
          final count = _getCountForOption(key, value);

          if (count == 0 && !isSelected) return const SizedBox.shrink();

          return _LuxuryChip(
            label: '$value ($count)',
            selected: isSelected,
            onTap: () {
              final next = [...selected];
              if (isSelected) {
                next.removeWhere(
                  (item) => item.toLowerCase() == value.toLowerCase(),
                );
              } else {
                next.add(value);
              }
              _update(
                _draft.copyWith(
                  attributeFilters: {..._draft.attributeFilters, key: next},
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _availabilitySelector() {
    return ListView(
      children: [
        _toggleRow('Same day delivery', _draft.sameDayAvailable, (value) {
          _update(_draft.copyWith(sameDayAvailable: value));
        }),
        _toggleRow('Try at home available', _draft.tryAtHomeAvailable, (value) {
          _update(_draft.copyWith(tryAtHomeAvailable: value));
        }),
      ],
    );
  }

  Widget _flagSelector(String key, String label) {
    final selected = _draft.attributeFlags[key] ?? false;
    return ListView(
      children: [
        _toggleRow(label, selected, (value) {
          _update(
            _draft.copyWith(
              attributeFlags: {..._draft.attributeFlags, key: value},
            ),
          );
        }),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF9A7A34),
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _ratingSelector() {
    return _chipSelector(
      const ['All', '4.0+', '4.5+'],
      _draft.minRating == 0 ? 'All' : '${_draft.minRating.toStringAsFixed(1)}+',
      (value) {
        final rating = value == 'All'
            ? 0.0
            : double.parse(value.replaceAll('+', ''));
        _update(_draft.copyWith(minRating: rating));
      },
      'rating',
    );
  }

  Widget _sortSelector() {
    final labels = <ProductSortOption, String>{
      ProductSortOption.relevance: 'Relevance',
      ProductSortOption.priceLowToHigh: 'Price: Low to High',
      ProductSortOption.priceHighToLow: 'Price: High to Low',
      ProductSortOption.newest: 'Newest',
      ProductSortOption.popularity: 'Popularity',
      ProductSortOption.sameDayPriority: 'Fastest Delivery',
    };
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: labels.entries.map((entry) {
          return _LuxuryChip(
            label: entry.value,
            selected: _draft.sort == entry.key,
            onTap: () => _update(_draft.copyWith(sort: entry.key)),
          );
        }).toList(),
      ),
    );
  }

  List<String> _categories() {
    final values = <String>{'All', ..._SearchScreenState._categories};
    values.addAll(
      widget.allProducts
          .map((product) => product.category)
          .where((item) => item.trim().isNotEmpty),
    );
    return values.toList();
  }

  List<String> _brands() {
    final values = widget.allProducts
        .map((product) => product.brand.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> _getDynamicOptions(String key) {
    final values = widget.allProducts
        .expand<String>((p) {
          if (p.attributes.containsKey(key)) {
            final Object? val = p.attributes[key];
            if (val is String) {
              return [val];
            }
            if (val is List) {
              return val.map((e) => e.toString()).toList();
            }
          }
          return <String>[];
        })
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }
}

class _LuxuryChip extends StatelessWidget {
  const _LuxuryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF17130F),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF17130F) : const Color(0xFFE2D7C5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF3A3126),
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _DiscoveryItem {
  const _DiscoveryItem(this.label, this.imageUrl);

  final String label;
  final String imageUrl;
}

class _BrandItem {
  const _BrandItem(this.name, this.imageUrl);

  final String name;
  final String imageUrl;
}

class _BoutiqueItem {
  const _BoutiqueItem(this.name, this.imageUrl, this.distanceKm, this.rating);

  final String name;
  final String imageUrl;
  final double distanceKm;
  final double rating;
}
