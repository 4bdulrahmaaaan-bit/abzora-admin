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
            return '${product.name} ${product.description} ${product.category}'.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text('${AbzoraText.heroSearchTitlePrefix} ${widget.selectedLocation}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: const InputDecoration(
                hintText: AbzoraText.searchHint,
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 18),
            if (query.isEmpty) ...[
              _sectionTitle(context, AbzoraText.searchRecentTitle),
              const SizedBox(height: 8),
              if (_recent.isEmpty)
                Text(AbzoraText.searchRecentEmpty, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recent.map((item) => _chip(context, item)).toList(),
                ),
              const SizedBox(height: 18),
              _sectionTitle(context, AbzoraText.searchTrendingTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _trending.map((item) => _chip(context, item)).toList(),
              ),
              const SizedBox(height: 18),
              _sectionTitle(context, AbzoraText.searchSuggestedCategoriesTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((item) => _chip(context, item)).toList(),
              ),
            ] else if (results.isEmpty) ...[
              const Spacer(),
              const AbzioEmptyCard(
                title: AbzoraText.searchEmptyTitle,
                subtitle: AbzoraText.searchEmptySubtitle,
              ),
              const Spacer(),
            ] else ...[
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (context, index) => Divider(color: context.abzioBorder),
                  itemBuilder: (context, index) {
                    final product = results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        _rememberSearch(_controller.text.trim());
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                        );
                      },
                      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(product.category),
                      trailing: Text(
                        'Rs ${product.price.toInt()}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AbzioTheme.accentColor),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
  }

  Widget _chip(BuildContext context, String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _controller.text = label;
        _onQueryChanged(label);
      },
    );
  }
}
