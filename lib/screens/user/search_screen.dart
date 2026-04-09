import 'dart:async';

import 'package:flutter/material.dart';

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

  static const _trending = <String>[
    'Tailored tuxedo',
    'Wedding sherwani',
    'Linen co-ord',
    'Party shirt',
  ];

  static const _categories = <String>[
    'Men',
    'Women',
    'Wedding',
    'Accessories',
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
    final results = query.isEmpty
        ? const <Product>[]
        : widget.allProducts.where((product) {
            return '${product.name} ${product.description} ${product.category}'
                .toLowerCase()
                .contains(query);
          }).toList();

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFCF7),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchHeader(
                selectedLocation: widget.selectedLocation,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    _SearchBarCard(
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
                    const SizedBox(height: 18),
                    if (query.isEmpty) ...[
                      _sectionBlock(
                        context,
                        eyebrow: 'Recent',
                        title: AbzoraText.searchRecentTitle,
                        subtitle: 'Pick up where you left off or explore a new premium edit.',
                        child: _recent.isEmpty
                            ? Text(
                                AbzoraText.searchRecentEmpty,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: context.abzioSecondaryText),
                              )
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    _recent.map((item) => _chip(context, item)).toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _sectionBlock(
                        context,
                        eyebrow: 'Trending',
                        title: AbzoraText.searchTrendingTitle,
                        subtitle: 'Refined pieces and occasion-led searches shoppers are exploring now.',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _trending.map((item) => _chip(context, item)).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionBlock(
                        context,
                        eyebrow: 'Browse',
                        title: AbzoraText.searchSuggestedCategoriesTitle,
                        subtitle: 'Jump into a curated category instead of typing from scratch.',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                              _categories.map((item) => _chip(context, item)).toList(),
                        ),
                      ),
                    ] else if (results.isEmpty) ...[
                      const SizedBox(height: 64),
                      const AbzioEmptyCard(
                        title: AbzoraText.searchEmptyTitle,
                        subtitle: AbzoraText.searchEmptySubtitle,
                      ),
                    ] else ...[
                      _ResultsHeader(
                        count: results.length,
                        query: _controller.text.trim(),
                      ),
                      const SizedBox(height: 14),
                      ...results.map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SearchResultCard(
                            product: product,
                            onTap: () {
                              _rememberSearch(_controller.text.trim());
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(product: product),
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

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
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
    if (_recent.contains(trimmed)) {
      _recent.remove(trimmed);
    }
    _recent.insert(0, trimmed);
    if (_recent.length > 6) {
      _recent.removeLast();
    }
  }

  Widget _sectionBlock(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3C5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8963F).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8E6B22),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.45,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D1A14),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return ActionChip(
      backgroundColor: const Color(0xFFFFF7E6),
      side: const BorderSide(color: Color(0xFFF0DFC0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B2418),
            ),
      ),
      onPressed: () {
        _controller.text = label;
        _onQueryChanged(label);
      },
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.selectedLocation,
    required this.onBack,
  });

  final String selectedLocation;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF0E3C5)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8963F).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                height: 44,
                width: 44,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AbzoraText.heroSearchTitlePrefix} $selectedLocation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D1A14),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore refined fashion, premium tailoring, and curated local edits.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarCard extends StatelessWidget {
  const _SearchBarCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E3C5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8963F).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: AbzoraText.searchHint,
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

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.query,
  });

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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Showing the strongest matches for "$query".',
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
            color: const Color(0xFFFFF4D8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Curated',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF8E6B22),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images.isNotEmpty ? product.images.first : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF0E3C5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8963F).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 96,
                  width: 84,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        product.category.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF8E6B22),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D1A14),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description.trim().isEmpty
                          ? 'Premium style picked for a stronger wardrobe update.'
                          : product.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.abzioSecondaryText,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toInt()}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF1D1A14),
                                fontWeight: FontWeight.w800,
                              ),
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
