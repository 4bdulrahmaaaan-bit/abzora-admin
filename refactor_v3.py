import sys

file_path = 'c:/Users/AAA/Documents/abzio/lib/screens/user/search_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = '  @override\n  Widget build(BuildContext context) {\n    final count = widget.previewCount(_draft);'
end_marker = 'class _DiscoveryItem {'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1:
    start_marker = start_marker.replace('\n', '\r\n')
    start_idx = content.find(start_marker)
if end_idx == -1:
    end_marker = end_marker.replace('\n', '\r\n')
    end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print(f'Markers not found: start={start_idx}, end={end_idx}')
    sys.exit(1)

new_code = r'''  @override
  Widget build(BuildContext context) {
    final count = widget.previewCount(_draft);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      body: SafeArea(
        child: Column(
          children: [
            // ─── HEADER ───
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF17130F),
                        ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _update(const SearchFilter()),
                    child: const Text(
                      'CLEAR ALL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC6A769),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDE3D3)),
            // ─── BODY ───
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── LEFT PANE ───
                  SizedBox(
                    width: 120,
                    child: Container(
                      color: const Color(0xFFF8F5EF),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: _orderedFilterKeys.map((key) {
                          final isSelected = _activeFilterKey == key;
                          final selectedCount = _getSelectedCountForFilter(key);

                          return GestureDetector(
                            onTap: () => setState(() => _activeFilterKey = key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected ? const Color(0xFFC6A769) : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _filterLabels[key] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                                      ),
                                    ),
                                  ),
                                  if (selectedCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC6A769),
                                        borderRadius: BorderRadius.circular(10),
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
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFFEDE3D3)),
                  // ─── RIGHT PANE ───
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(_activeFilterKey),
                          child: _activeFilterKey == 'more_filters'
                              ? _buildMoreFiltersContent()
                              : _buildActiveFilterContent(_activeFilterKey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ─── BOTTOM BAR ───
            const Divider(height: 1, color: Color(0xFFEDE3D3)),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Center(
                        child: Text(
                          'CLOSE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5C5347),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 20, color: const Color(0xFFEDE3D3)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(_draft),
                      child: Center(
                        child: Text(
                          'APPLY ($count)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC6A769),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreFiltersContent() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _moreFiltersKeys.length,
      itemBuilder: (context, index) {
        final key = _moreFiltersKeys[index];
        return _buildActiveFilterContent(key, isMoreFilters: true);
      },
    );
  }

  Widget _buildActiveFilterContent(
    String? filterKey, {
    bool isMoreFilters = false,
  }) {
    if (filterKey == null) return const SizedBox.shrink();
    final key = filterKey;

    Widget content;
    switch (key) {
      case 'category':
        content = _checkListSelector(
          _categories(),
          _draft.category,
          (value) => _update(_draft.copyWith(category: value)),
          key,
        );
        break;
      case 'gender':
        content = _checkListSelector(
          const ['Men', 'Women', 'Unisex', 'Kids'],
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
        content = _checkListSelector(
          const ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
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
            final options = field.options.isNotEmpty ? field.options : _getDynamicOptions(key);
            content = _multiCheckListSelector(key, options);
          }
        } else {
          content = const SizedBox.shrink();
        }
    }

    if (isMoreFilters) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              _filterLabels[key] ?? '',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17130F),
              ),
            ),
          ),
          content,
          const Divider(height: 1, color: Color(0xFFEDE3D3)),
        ],
      );
    }

    return content;
  }

  // ─── Single-select list (Category, Gender, Size) ───
  Widget _checkListSelector(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
    String filterKey,
  ) {
    final filtered = values.where((v) => v != 'All').toList();
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3EDE0), indent: 48),
      itemBuilder: (context, index) {
        final value = filtered[index];
        final isSelected = selected.toLowerCase() == value.toLowerCase();
        final count = _getCountForOption(filterKey, value);

        if (count == 0 && !isSelected) return const SizedBox.shrink();

        return InkWell(
          onTap: () => onChanged(isSelected ? 'All' : value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? const Color(0xFFC6A769) : const Color(0xFFD9CCB9),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                    ),
                  ),
                ),
                Text(
                  '($count)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFBEB5A7)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Multi-select list (Attributes like Pattern, Occasion) ───
  Widget _multiCheckListSelector(String key, List<String> values) {
    final selected = _draft.attributeFilters[key] ?? const <String>[];
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: values.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3EDE0), indent: 48),
      itemBuilder: (context, index) {
        final value = values[index];
        final isSelected = selected.any((item) => item.toLowerCase() == value.toLowerCase());
        final count = _getCountForOption(key, value);

        if (count == 0 && !isSelected) return const SizedBox.shrink();

        return InkWell(
          onTap: () {
            final next = [...selected];
            if (isSelected) {
              next.removeWhere((item) => item.toLowerCase() == value.toLowerCase());
            } else {
              next.add(value);
            }
            _update(
              _draft.copyWith(attributeFilters: {..._draft.attributeFilters, key: next}),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: isSelected ? const Color(0xFFC6A769) : const Color(0xFFD9CCB9),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                    ),
                  ),
                ),
                Text(
                  '($count)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFBEB5A7)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _brandSelector() {
    final brands = _brands()
        .where((brand) => brand.toLowerCase().contains(_brandSearch.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _brandSearchController,
            onChanged: (value) => setState(() => _brandSearch = value),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search brand...',
              hintStyle: const TextStyle(color: Color(0xFFBEB5A7), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8C8273), size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F5EF),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _checkListSelector(
            brands,
            _draft.brand,
            (value) => _update(_draft.copyWith(brand: value)),
            'brand',
          ),
        ),
      ],
    );
  }

  Widget _priceSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Price range',
            style: TextStyle(fontSize: 13, color: Color(0xFF8C8273)),
          ),
          const SizedBox(height: 6),
          Text(
            '\u20B9${_draft.priceRange.start.toInt()} - \u20B9${_draft.priceRange.end.toInt()}+',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17130F),
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFC6A769),
              inactiveTrackColor: const Color(0xFFEDE3D3),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFFC6A769).withOpacity(0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: RangeSlider(
              values: _draft.priceRange,
              min: 0,
              max: 10000,
              divisions: 20,
              onChanged: (value) => _update(_draft.copyWith(priceRange: value)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorSelector() {
    final colors = <String, Color>{
      'Black': Colors.black,
      'White': Colors.white,
      'Navy': const Color(0xFF1B2A4A),
      'Grey': const Color(0xFF808080),
      'Beige': const Color(0xFFF5F0E1),
      'Brown': const Color(0xFF5C3317),
      'Red': const Color(0xFF8F1D2C),
      'Blue': const Color(0xFF3B6BA5),
      'Green': const Color(0xFF355C45),
      'Pink': const Color(0xFFD4839A),
      'Gold': const Color(0xFFC6A769),
      'Maroon': const Color(0xFF5E1224),
    };
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: colors.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3EDE0), indent: 48),
      itemBuilder: (context, index) {
        final entry = colors.entries.elementAt(index);
        final isSelected = _draft.color == entry.key;
        final count = _getCountForOption('color', entry.key);

        if (count == 0 && !isSelected) return const SizedBox.shrink();

        return InkWell(
          onTap: () => _update(_draft.copyWith(color: isSelected ? 'All' : entry.key)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.value,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFC6A769) : const Color(0xFFD9CCB9),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded,
                          color: entry.key == 'White' || entry.key == 'Beige' ? Colors.black : Colors.white,
                          size: 14)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                    ),
                  ),
                ),
                Text(
                  '($count)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFBEB5A7)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _availabilitySelector() {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        _toggleRow('Same Day Delivery', _draft.sameDayAvailable, (value) {
          _update(_draft.copyWith(sameDayAvailable: value));
        }),
        const Divider(height: 1, color: Color(0xFFF3EDE0), indent: 48),
        _toggleRow('Try at Home Available', _draft.tryAtHomeAvailable, (value) {
          _update(_draft.copyWith(tryAtHomeAvailable: value));
        }),
      ],
    );
  }

  Widget _flagSelector(String key, String label) {
    final selected = _draft.attributeFlags[key] ?? false;
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        _toggleRow(label, selected, (value) {
          _update(
            _draft.copyWith(attributeFlags: {..._draft.attributeFlags, key: value}),
          );
        }),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: value ? const Color(0xFFC6A769) : const Color(0xFFD9CCB9),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: value ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingSelector() {
    final options = ['1.0 to 5.0', '2.0 to 5.0', '3.0 to 5.0', '4.0 to 5.0'];
    final values = [1.0, 2.0, 3.0, 4.0];
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3EDE0), indent: 48),
      itemBuilder: (context, index) {
        final isSelected = _draft.minRating == values[index];
        return InkWell(
          onTap: () {
            _update(_draft.copyWith(minRating: isSelected ? 0.0 : values[index]));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? const Color(0xFFC6A769) : const Color(0xFFD9CCB9),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  options[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortSelector() {
    final labels = <ProductSortOption, String>{
      ProductSortOption.relevance: 'Relevance',
      ProductSortOption.priceLowToHigh: 'Price: Low to High',
      ProductSortOption.priceHighToLow: 'Price: High to Low',
      ProductSortOption.newest: 'Newest First',
      ProductSortOption.popularity: 'Popularity',
      ProductSortOption.sameDayPriority: 'Fastest Delivery',
    };
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: labels.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3EDE0), indent: 48),
      itemBuilder: (context, index) {
        final entry = labels.entries.elementAt(index);
        final isSelected = _draft.sort == entry.key;
        return InkWell(
          onTap: () => _update(_draft.copyWith(sort: entry.key)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? const Color(0xFFC6A769) : const Color(0xFFD9CCB9),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? const Color(0xFF17130F) : const Color(0xFF5C5347),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _categories() {
    final values = widget.allProducts
        .map((product) => product.category)
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
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
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF17130F) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF17130F) : const Color(0xFFE2D7C5),
          ),
        ),
        child: Text(
          count != null ? '$label ($count)' : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF3A3126),
          ),
        ),
      ),
    );
  }
}

'''

new_content = content[:start_idx] + new_code + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Success')
