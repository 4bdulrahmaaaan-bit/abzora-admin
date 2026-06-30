import sys

file_path = 'c:/Users/AAA/Documents/abzio/lib/screens/user/search_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

import_statement = "import '../../config/product_attribute_config.dart';\n"
if 'product_attribute_config.dart' not in content:
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('import ') and 'package:flutter/material.dart' in line:
            lines.insert(i + 1, import_statement)
            break
    content = '\n'.join(lines)

start_marker = 'class _SearchFilterModal extends StatefulWidget {'
end_marker = 'class _LuxuryChip extends StatelessWidget {'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print('Markers not found')
    sys.exit(1)

new_code = '''class _SearchFilterModal extends StatefulWidget {
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
    if (_draft.category != 'All' && productAttributeTemplates.containsKey(_draft.category.toLowerCase())) {
      final template = productAttributeTemplates[_draft.category.toLowerCase()]!;
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

    if (_activeFilterKey == null || !_orderedFilterKeys.contains(_activeFilterKey)) {
      _activeFilterKey = _orderedFilterKeys.first;
    }
  }

  int _getCountForOption(String filterKey, String optionValue) {
    if (_cachedCounts.containsKey(filterKey) && _cachedCounts[filterKey]!.containsKey(optionValue)) {
      return _cachedCounts[filterKey]![optionValue]!;
    }

    SearchFilter testFilter = _draft;
    if (filterKey == 'category') testFilter = testFilter.copyWith(category: optionValue);
    else if (filterKey == 'gender') testFilter = testFilter.copyWith(gender: optionValue);
    else if (filterKey == 'brand') testFilter = testFilter.copyWith(brand: optionValue);
    else if (filterKey == 'size') testFilter = testFilter.copyWith(size: optionValue);
    else if (filterKey == 'color') testFilter = testFilter.copyWith(color: optionValue);
    else if (filterKey == 'rating') {
      final rating = optionValue == 'All' ? 0.0 : double.parse(optionValue.replaceAll('+', ''));
      testFilter = testFilter.copyWith(minRating: rating);
    } else {
      final currentList = testFilter.attributeFilters[filterKey] ?? [];
      final nextList = [...currentList];
      if (!nextList.any((e) => e.toLowerCase() == optionValue.toLowerCase())) {
        nextList.add(optionValue);
      }
      testFilter = testFilter.copyWith(attributeFilters: {...testFilter.attributeFilters, filterKey: nextList});
    }

    final count = widget.previewCount(testFilter);
    _cachedCounts.putIfAbsent(filterKey, () => {})[optionValue] = count;
    return count;
  }

  int _getSelectedCountForFilter(String key) {
    int count = 0;
    if (key == 'category' && _draft.category != 'All') count = 1;
    else if (key == 'gender' && _draft.gender != 'All') count = 1;
    else if (key == 'brand' && _draft.brand != 'All') count = 1;
    else if (key == 'size' && _draft.size != 'All') count = 1;
    else if (key == 'color' && _draft.color != 'All') count = 1;
    else if (key == 'price') {
      if (_draft.priceRange.start > 0 || _draft.priceRange.end < 10000) count = 1;
    }
    else if (key == 'availability') {
      if (_draft.sameDayAvailable) count++;
      if (_draft.tryAtHomeAvailable) count++;
    }
    else if (key == 'rating' && _draft.minRating > 0) count = 1;
    else if (key == 'sort' && _draft.sort != ProductSortOption.relevance) count = 1;
    else if (_draft.attributeFilters.containsKey(key)) {
      count = _draft.attributeFilters[key]!.length;
    }
    else if (_draft.attributeFlags.containsKey(key) && _draft.attributeFlags[key] == true) {
      count = 1;
    }
    return count;
  }

  IconData _getIconForFilter(String key) {
    switch (key) {
      case 'category': return Icons.category_rounded;
      case 'gender': return Icons.wc_rounded;
      case 'brand': return Icons.branding_watermark_rounded;
      case 'price': return Icons.payments_rounded;
      case 'size':
      case 'available_sizes': return Icons.straighten_rounded;
      case 'color': return Icons.palette_rounded;
      case 'material':
      case 'fabric': return Icons.texture_rounded;
      case 'fit': return Icons.accessibility_new_rounded;
      case 'occasion': return Icons.event_rounded;
      case 'pattern': return Icons.pattern_rounded;
      case 'availability': return Icons.inventory_2_rounded;
      case 'rating': return Icons.star_rounded;
      case 'sort': return Icons.sort_rounded;
      case 'sleeve_length':
      case 'sleeve_type': return Icons.checkroom_rounded;
      case 'neck_type': return Icons.portrait_rounded;
      default: return Icons.tune_rounded;
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _update(const SearchFilter()),
              child: const Text('Reset', style: TextStyle(color: Color(0xFF8C8273))),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              child: const Text('Apply', style: TextStyle(color: Color(0xFF17130F), fontWeight: FontWeight.bold)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Show $count Results', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                          color: isSelected ? const Color(0xFFC6A769) : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                            color: isSelected ? const Color(0xFF17130F) : const Color(0xFF8C8273),
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
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF17130F) : const Color(0xFF8C8273),
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
                      position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
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
        content = _chipSelector(_categories(), _draft.category, (value) => _update(_draft.copyWith(category: value)), key);
        break;
      case 'gender':
        content = _chipSelector(const ['All', 'Men', 'Women', 'Unisex', 'Kids'], _draft.gender, (value) => _update(_draft.copyWith(gender: value)), key);
        break;
      case 'brand':
        content = _brandSelector();
        break;
      case 'price':
        content = _priceSelector();
        break;
      case 'size':
        content = _chipSelector(const ['All', 'XS', 'S', 'M', 'L', 'XL', 'XXL'], _draft.size, (value) => _update(_draft.copyWith(size: value)), key);
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
            final options = field.options.isNotEmpty ? field.options : _getDynamicOptions(key);
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Expanded(child: content),
      ],
    );
  }

  Widget _chipSelector(List<String> values, String selected, ValueChanged<String> onChanged, String filterKey) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: values.map((value) {
          final isSelected = selected.toLowerCase() == value.toLowerCase();
          final count = _getCountForOption(filterKey, value);

          if (count == 0 && !isSelected) return const SizedBox.shrink();

          return _LuxuryChip(
            label: value == 'All' ? value : f'{value} ({count})',
            selected: isSelected,
            onTap: () => onChanged(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _brandSelector() {
    final brands = _brands().where((brand) => brand.toLowerCase().contains(_brandSearch.toLowerCase())).toList();
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _chipSelector(['All', ...brands], _draft.brand, (value) => _update(_draft.copyWith(brand: value)), 'brand'),
        ),
      ],
    );
  }

  Widget _priceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f'₹{_draft.priceRange.start.toInt()} - ₹{_draft.priceRange.end.toInt()}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                      color: isSelected ? const Color(0xFF17130F) : const Color(0xFFD9CCB9),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: entry.key == 'All' ? const Icon(Icons.all_inclusive_rounded, size: 18) : null,
                ),
                const SizedBox(height: 6),
                Text(entry.key == 'All' ? entry.key : f'{entry.key}\\n({count})', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
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
          final isSelected = selected.any((item) => item.toLowerCase() == value.toLowerCase());
          final count = _getCountForOption(key, value);

          if (count == 0 && !isSelected) return const SizedBox.shrink();

          return _LuxuryChip(
            label: f'{value} ({count})',
            selected: isSelected,
            onTap: () {
              final next = [...selected];
              if (isSelected) {
                next.removeWhere((item) => item.toLowerCase() == value.toLowerCase());
              } else {
                next.add(value);
              }
              _update(_draft.copyWith(attributeFilters: {..._draft.attributeFilters, key: next}));
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
          _update(_draft.copyWith(attributeFlags: {..._draft.attributeFlags, key: value}));
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
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _ratingSelector() {
    return _chipSelector(
      const ['All', '4.0+', '4.5+'],
      _draft.minRating == 0 ? 'All' : f'{_draft.minRating.toStringAsFixed(1)}+',
      (value) {
        final rating = value == 'All' ? 0.0 : double.parse(value.replaceAll('+', ''));
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
    values.addAll(widget.allProducts.map((product) => product.category).where((item) => item.trim().isNotEmpty));
    return values.toList();
  }

  List<String> _brands() {
    final values = widget.allProducts.map((product) => product.brand.trim()).where((item) => item.isNotEmpty).toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> _getDynamicOptions(String key) {
     final values = widget.allProducts.expand((p) {
        if (p.attributes.containsKey(key)) {
           final val = p.attributes[key];
           if (val is String) return [val];
           if (val is List) return val.map((e) => e.toString());
        }
        return <String>[];
     }).where((s) => s.trim().isNotEmpty).toSet().toList();
     values.sort();
     return values;
  }
}
'''
new_code = new_code.replace("f'{", "'${").replace("}'", "'").replace("f'₹", "'₹").replace("+'", "+'").replace("f'", "'")

new_content = content[:start_idx] + new_code + '\n' + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Success')
