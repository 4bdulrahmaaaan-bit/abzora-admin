import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/backend_commerce_service.dart';
import '../../widgets/premium_price_row.dart';
import '../../widgets/state_views.dart';

class PricingManagementScreen extends StatefulWidget {
  const PricingManagementScreen({super.key, required this.storeId});

  final String storeId;

  @override
  State<PricingManagementScreen> createState() => _PricingManagementScreenState();
}

class _PricingManagementScreenState extends State<PricingManagementScreen> {
  final BackendCommerceService _service = BackendCommerceService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );

  final Set<String> _selected = <String>{};
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();
  final TextEditingController _bulkValueController = TextEditingController(
    text: '200',
  );
  final TextEditingController _bulkMrpController = TextEditingController();
  final TextEditingController _bulkDiscountController = TextEditingController(
    text: '25',
  );

  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _summary = const <String, dynamic>{};
  Map<String, dynamic> _focusedAnalytics = const <String, dynamic>{};
  List<Map<String, dynamic>> _priceConversionPoints = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _discountSalesPoints = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _timeSeriesPoints = <Map<String, dynamic>>[];
  Map<String, dynamic>? _preview;

  bool _loading = true;
  bool _analyticsLoading = false;
  bool _bulkBusy = false;

  String _sortBy = 'newest';
  String _category = 'All';
  String _bulkMode = 'decrease';
  String _bulkUnit = 'amount';
  String _period = '30d';
  bool _removeDiscount = false;
  String? _focusedProductId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _bulkValueController.dispose();
    _bulkMrpController.dispose();
    _bulkDiscountController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final values = _rows
        .map((row) => (row['category'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return <String>['All', ...values];
  }

  Map<String, dynamic>? get _focusedProduct {
    final focusedId = _focusedProductId;
    if (focusedId == null || focusedId.isEmpty) {
      return _rows.isEmpty ? null : _rows.first;
    }
    for (final row in _rows) {
      if (row['id']?.toString() == focusedId) {
        return row;
      }
    }
    return _rows.isEmpty ? null : _rows.first;
  }

  DateTime? get _periodFrom {
    final now = DateTime.now();
    switch (_period) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  double _asDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  String _fmt(dynamic value) => _currency.format(_asDouble(value));

  String _periodLabel(String value) {
    switch (value) {
      case '7d':
        return 'Last 7 days';
      case '30d':
        return 'Last 30 days';
      default:
        return 'All time';
    }
  }

  String _formatNumber(num value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    }
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  List<double> _chartValues(
    List<Map<String, dynamic>> points,
    String key,
  ) {
    return points.map((item) => _asDouble(item[key])).take(8).toList();
  }

  String? _resolveImageUrl(Map<String, dynamic> row) {
    final images = row['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first != null && first.toString().trim().isNotEmpty) {
        return first.toString().trim();
      }
    }
    final candidates = <dynamic>[
      row['imageUrl'],
      row['image'],
      row['thumbnail'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Map<String, dynamic> _discountSuggestionFor(Map<String, dynamic> row) {
    final conversion = _asDouble(row['conversionRate']);
    final stock = _asInt(row['stock']);
    final views = _asInt(row['viewCount']);
    final demandScore = _asDouble(row['demandScore']);

    if (conversion < 2 && stock > 20) {
      return <String, dynamic>{
        'suggested': 35,
        'reason': 'Low conversion and high inventory pressure.',
      };
    }
    if (demandScore > 70 || (conversion > 8 && views > 100)) {
      return <String, dynamic>{
        'suggested': 12,
        'reason': 'Demand is healthy, so margin can stay protected.',
      };
    }
    return <String, dynamic>{
      'suggested': 25,
      'reason': 'Balanced by category trend and current sell-through.',
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final from = _periodFrom;
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.getVendorPricingProducts(
          storeId: widget.storeId,
          category: _category,
          sortBy: _sortBy,
          minPrice: double.tryParse(_minController.text.trim()),
          maxPrice: double.tryParse(_maxController.text.trim()),
        ),
        _service.getAnalyticsSummary(from: from),
      ]);

      final rows = List<Map<String, dynamic>>.from(results[0] as List);
      final summary = Map<String, dynamic>.from(results[1] as Map);
      final nextFocus = rows.any((row) => row['id']?.toString() == _focusedProductId)
          ? _focusedProductId
          : (rows.isEmpty ? null : rows.first['id']?.toString());

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _summary = summary;
        _focusedProductId = nextFocus;
        _selected.removeWhere(
          (id) => !_rows.any((row) => row['id']?.toString() == id),
        );
        _loading = false;
      });

      if (nextFocus != null && nextFocus.isNotEmpty) {
        await _loadFocusedAnalytics(nextFocus);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadFocusedAnalytics(String productId) async {
    setState(() {
      _analyticsLoading = true;
    });

    try {
      final from = _periodFrom;
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.getAnalyticsProduct(productId, from: from),
        _service.getAnalyticsPriceConversionChart(productId, from: from),
        _service.getAnalyticsDiscountSalesChart(productId, from: from),
        _service.getAnalyticsTimeSeriesChart(productId, from: from),
      ]);

      if (!mounted) return;
      setState(() {
        _focusedAnalytics = Map<String, dynamic>.from(results[0] as Map);
        _priceConversionPoints = List<Map<String, dynamic>>.from(
          results[1] as List,
        );
        _discountSalesPoints = List<Map<String, dynamic>>.from(
          results[2] as List,
        );
        _timeSeriesPoints = List<Map<String, dynamic>>.from(results[3] as List);
        _focusedProductId = productId;
        _analyticsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analyticsLoading = false;
        _error = error.toString();
      });
    }
  }

  void _focusProduct(String productId) {
    if (productId == _focusedProductId && _focusedAnalytics.isNotEmpty) {
      return;
    }
    _loadFocusedAnalytics(productId);
  }

  void _configureBulkAction({
    String? mode,
    String? unit,
    bool? removeDiscount,
    int? suggestedDiscount,
  }) {
    setState(() {
      if (mode != null) _bulkMode = mode;
      if (unit != null) _bulkUnit = unit;
      if (removeDiscount != null) _removeDiscount = removeDiscount;
      if (suggestedDiscount != null) {
        _bulkDiscountController.text = suggestedDiscount.toString();
      }
    });
  }

  Future<void> _previewBulk() async {
    if (_selected.isEmpty) return;
    setState(() {
      _bulkBusy = true;
      _error = null;
    });

    try {
      final payload = await _service.bulkUpdateVendorProductPrices(
        productIds: _selected.toList(),
        mode: _bulkMode,
        unit: _bulkUnit,
        changeValue: double.tryParse(_bulkValueController.text.trim()) ?? 0,
        setMrp: double.tryParse(_bulkMrpController.text.trim()),
        discountPercent: double.tryParse(_bulkDiscountController.text.trim()),
        removeDiscount: _removeDiscount,
        previewOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _preview = payload;
        _bulkBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bulkBusy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _applyBulk() async {
    if (_selected.isEmpty) return;
    setState(() {
      _bulkBusy = true;
      _error = null;
    });

    try {
      await _service.bulkUpdateVendorProductPrices(
        productIds: _selected.toList(),
        mode: _bulkMode,
        unit: _bulkUnit,
        changeValue: double.tryParse(_bulkValueController.text.trim()) ?? 0,
        setMrp: double.tryParse(_bulkMrpController.text.trim()),
        discountPercent: double.tryParse(_bulkDiscountController.text.trim()),
        removeDiscount: _removeDiscount,
        previewOnly: false,
      );
      if (!mounted) return;
      setState(() {
        _preview = null;
        _bulkBusy = false;
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing changes applied successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bulkBusy = false;
        _error = error.toString();
      });
    }
  }

  Widget _buildKpiCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7F7A70),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBarChart({
    required String title,
    required List<double> values,
    required String footer,
  }) {
    final safe = values.map((value) => value < 0 ? 0 : value).toList();
    final max = safe.isEmpty ? 1.0 : safe.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: safe.isEmpty
                  ? <Widget>[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EEE3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No data yet',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF8C857A),
                            ),
                          ),
                        ),
                      ),
                    ]
                  : safe
                        .map(
                          (value) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                                height: max <= 0 ? 2 : (value / max) * 82,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: <Color>[
                                      Color(0xFFC6A96B),
                                      Color(0xFFE8D8B7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            footer,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF7F7A70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF7F7A70),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: value,
          items: values
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String value) {
    final selected = _period == value;
    return ChoiceChip(
      label: Text(value.toUpperCase()),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _period = value;
        });
        _load();
      },
      labelStyle: GoogleFonts.inter(
        color: selected ? const Color(0xFF1B1710) : const Color(0xFF6E685D),
        fontWeight: FontWeight.w600,
      ),
      selectedColor: const Color(0xFFE7D4AE),
      backgroundColor: const Color(0xFFF4EFE5),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildProductThumb(Map<String, dynamic> row) {
    final imageUrl = _resolveImageUrl(row);
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EEE3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_outlined, size: 18),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEE3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image_outlined, size: 18),
          );
        },
      ),
    );
  }

  Widget _buildSelectedActionBar() {
    final focused = _focusedProduct;
    final suggestion = focused == null
        ? const <String, dynamic>{'suggested': 25}
        : _discountSuggestionFor(focused);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF7F0E1), Color(0xFFFDF9F2)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D9BC)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${_selected.length} products selected',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2B251A),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => _configureBulkAction(
                  mode: 'set',
                  unit: 'amount',
                  removeDiscount: false,
                ),
                child: const Text('Edit Price'),
              ),
              OutlinedButton(
                onPressed: () => _configureBulkAction(
                  mode: 'decrease',
                  unit: 'percent',
                  removeDiscount: false,
                  suggestedDiscount: _asInt(suggestion['suggested']),
                ),
                child: const Text('Apply Discount'),
              ),
              OutlinedButton(
                onPressed: () => _configureBulkAction(
                  removeDiscount: true,
                ),
                child: const Text('Remove Discount'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkPanel() {
    final focused = _focusedProduct;
    final suggestion = focused == null
        ? const <String, dynamic>{'suggested': 25, 'reason': 'No data available.'}
        : _discountSuggestionFor(focused);
    final updates = (_preview?['updates'] as List?) ?? const <dynamic>[];
    final sample = updates.isNotEmpty
        ? Map<String, dynamic>.from(updates.first as Map)
        : null;
    final before = sample == null
        ? null
        : Map<String, dynamic>.from(sample['before'] as Map);
    final after = sample == null
        ? null
        : Map<String, dynamic>.from(sample['after'] as Map);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Bulk Pricing Edit',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Preview the new premium price stack before applying it across your selected catalog.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6F685D),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _pillDropdown(
                label: 'Mode',
                value: _bulkMode,
                values: const <String>['increase', 'decrease', 'set'],
                onChanged: (value) => setState(() => _bulkMode = value),
              ),
              _pillDropdown(
                label: 'Unit',
                value: _bulkUnit,
                values: const <String>['amount', 'percent'],
                onChanged: (value) => setState(() => _bulkUnit = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _bulkValueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Increase or decrease value',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _bulkMrpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Set new MRP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _bulkDiscountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount %'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remove discount'),
            subtitle: const Text('Turn off active discount windows on selected products.'),
            value: _removeDiscount,
            onChanged: (value) => setState(() => _removeDiscount = value),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF7EE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Suggested Discount: ${suggestion['suggested']}%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF30281B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion['reason']?.toString() ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF685F52),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _bulkDiscountController.text =
                        _asInt(suggestion['suggested']).toString();
                    _bulkMode = 'decrease';
                    _bulkUnit = 'percent';
                    _removeDiscount = false;
                  }),
                  child: const Text('Apply Suggestion'),
                ),
              ],
            ),
          ),
          if (before != null && after != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Live Preview',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: PremiumPriceRow(
                    currentPriceLabel: _fmt(before['price']),
                    originalPriceLabel: before['original_price'] == null
                        ? null
                        : _fmt(before['original_price']),
                    discountPercent: _asInt(before['discount_percentage']),
                    compact: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF9A8D72),
                  ),
                ),
                Expanded(
                  child: PremiumPriceRow(
                    currentPriceLabel: _fmt(after['price']),
                    originalPriceLabel: after['original_price'] == null
                        ? null
                        : _fmt(after['original_price']),
                    discountPercent: _asInt(after['discount_percentage']),
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: _bulkBusy ? null : _previewBulk,
                child: const Text('Preview'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _bulkBusy ? null : _applyBulk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC6A96B),
                  foregroundColor: const Color(0xFF18150F),
                ),
                child: Text(_bulkBusy ? 'Applying...' : 'Apply Changes'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _bulkBusy
                    ? null
                    : () => setState(() {
                        _preview = null;
                        _removeDiscount = false;
                      }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPanel() {
    final product = _focusedProduct;
    if (product == null) {
      return const SizedBox.shrink();
    }

    final analytics = _focusedAnalytics;
    final views = _asDouble(analytics['views'], _asDouble(product['viewCount']));
    final purchases = _asDouble(
      analytics['purchases'],
      _asDouble(product['purchaseCount']),
    );
    final conversion = _asDouble(
      analytics['conversion_rate'],
      _asDouble(product['conversionRate']),
    );
    final carts = _asDouble(analytics['carts'], _asDouble(product['cartCount']));
    final cartRate = _asDouble(analytics['cart_rate']);
    final suggestion = _discountSuggestionFor(product);
    final bestPricePoint = _priceConversionPoints.isEmpty
        ? null
        : (_priceConversionPoints.toList()
              ..sort(
                (a, b) => _asDouble(
                  b['conversion_rate'],
                ).compareTo(_asDouble(a['conversion_rate'])),
              ))
            .first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildProductThumb(product),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product['name']?.toString() ?? 'Focused product',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pricing insights for ${_periodLabel(_period).toLowerCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF7F7A70),
                      ),
                    ),
                  ],
                ),
              ),
              if (_analyticsLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          PremiumPriceRow(
            currentPriceLabel: _fmt(product['price']),
            originalPriceLabel: product['originalPrice'] == null
                ? null
                : _fmt(product['originalPrice']),
            discountPercent: _asInt(product['discountPercentage']),
            compact: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _buildKpiCard('Views', _formatNumber(views)),
              const SizedBox(width: 10),
              _buildKpiCard('Purchases', _formatNumber(purchases)),
              const SizedBox(width: 10),
              _buildKpiCard('Conversion', '${conversion.toStringAsFixed(1)}%'),
              const SizedBox(width: 10),
              _buildKpiCard('Cart Rate', '${cartRate.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMiniBarChart(
                  title: 'Price vs Conversion',
                  values: _chartValues(_priceConversionPoints, 'conversion_rate'),
                  footer: bestPricePoint == null
                      ? 'Price testing data will appear after enough sessions.'
                      : 'Best performing price appears near ${_fmt(bestPricePoint['price'])}.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniBarChart(
                  title: 'Discount vs Sales',
                  values: _chartValues(_discountSalesPoints, 'sales'),
                  footer: carts <= 0
                      ? 'No discount-led sales trend yet.'
                      : 'Higher discounts are currently influencing purchase lift.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI Insights',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suggested discount: ${suggestion['suggested']}% because ${suggestion['reason']?.toString().toLowerCase() ?? 'current performance needs support.'}',
                  style: GoogleFonts.inter(
                    height: 1.4,
                    color: const Color(0xFF645F55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bestPricePoint == null
                      ? 'Keep collecting pricing exposure data to unlock price-conversion optimization.'
                      : 'Optimal price point is currently clustering around ${_fmt(bestPricePoint['price'])} with the strongest conversion response.',
                  style: GoogleFonts.inter(
                    height: 1.4,
                    color: const Color(0xFF645F55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final views = _asDouble(_summary['views']);
    final cartRate = _asDouble(_summary['cart_rate']);
    final conversionRate = _asDouble(_summary['conversion_rate']);
    final purchases = _asDouble(_summary['purchases']);
    final estimatedRevenue = _rows.fold<double>(
      0,
      (sum, row) => sum + (_asDouble(row['price']) * _asDouble(row['purchaseCount'])),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F3),
      appBar: AppBar(
        title: Text(
          'Pricing Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AbzioLoadingView(
              title: 'Loading pricing data',
              subtitle: 'Preparing premium pricing controls and live insights.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_error != null && _error!.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5D4B2)),
                    ),
                    child: Text(
                      'Some live pricing signals are temporarily unavailable. Showing the latest stable snapshot.',
                      style: GoogleFonts.inter(color: const Color(0xFF7A5A00)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Pricing Management',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tune luxury pricing, protect margin, and respond to demand in real time.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
                                color: const Color(0xFF6F685D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EFE4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFC6A96B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Live',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5B5140),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _buildPeriodChip('7d'),
                    _buildPeriodChip('30d'),
                    _buildPeriodChip('all'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    _buildKpiCard('Views', _formatNumber(views)),
                    const SizedBox(width: 10),
                    _buildKpiCard('Cart Rate', '${cartRate.toStringAsFixed(1)}%'),
                    const SizedBox(width: 10),
                    _buildKpiCard(
                      'Conversion',
                      '${conversionRate.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(width: 10),
                    _buildKpiCard('Revenue', _fmt(estimatedRevenue)),
                  ],
                ),
                const SizedBox(height: 14),
                if (_rows.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Pricing Suggestions',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _SuggestionTile(
                          text: 'Running Sneakers -> Reduce price by ?200 to increase conversion',
                          impact: 'HIGH IMPACT',
                        ),
                        _SuggestionTile(
                          text: 'Denim Jacket -> High demand, increase price by ?150',
                          impact: 'MEDIUM',
                        ),
                        _SuggestionTile(
                          text: 'Floral Dress -> Out of stock, losing potential revenue',
                          impact: 'HIGH IMPACT',
                        ),
                      ],
                    ),
                  ),
                if (_rows.isNotEmpty) const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: _categories
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _category = value ?? 'All');
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _sortBy,
                          decoration: const InputDecoration(labelText: 'Sort'),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text('Newest'),
                            ),
                            DropdownMenuItem(
                              value: 'price_asc',
                              child: Text('Price Low-High'),
                            ),
                            DropdownMenuItem(
                              value: 'price_desc',
                              child: Text('Price High-Low'),
                            ),
                            DropdownMenuItem(
                              value: 'performance',
                              child: Text('Performance'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _sortBy = value ?? 'newest');
                          },
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _minController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min \u20B9',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _maxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max \u20B9',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6A96B),
                          foregroundColor: const Color(0xFF18150F),
                        ),
                        child: const Text('Apply Filters'),
                      ),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty) _buildSelectedActionBar(),
                const SizedBox(height: 14),
                if (_rows.isEmpty)
                  AbzioEmptyCard(
                    title: 'Add products to start optimizing pricing',
                    subtitle: 'Start selling to unlock demand and purchase insights.',
                    ctaLabel: 'ADD PRODUCT',
                    onTap: () => Navigator.pop(context),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF635E55),
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Select')),
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('MRP')),
                        DataColumn(label: Text('Discount %')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Conversion %')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _rows.map((row) {
                        final id = row['id'].toString();
                        final isSelected = _selected.contains(id);
                        final productName = (row['name'] ?? '').toString();
                        final discount = _asInt(row['discountPercentage']);
                        final status = (row['pricingStatus'] ?? 'active')
                            .toString();
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            });
                            _focusProduct(id);
                          },
                          cells: <DataCell>[
                            DataCell(
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  });
                                  _focusProduct(id);
                                },
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 260,
                                child: InkWell(
                                  onTap: () => _focusProduct(id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        _buildProductThumb(row),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Text(
                                                productName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                row['category']?.toString() ?? '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(0xFF8C857A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(_fmt(row['price']))),
                            DataCell(
                              Text(
                                row['originalPrice'] == null
                                    ? '--'
                                    : _fmt(row['originalPrice']),
                              ),
                            ),
                            DataCell(Text('$discount%')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? const Color(0xFFF2F8EE)
                                      : status == 'scheduled'
                                          ? const Color(0xFFF7F1E3)
                                          : const Color(0xFFF3F1EE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(status),
                              ),
                            ),
                            DataCell(
                              Text(
                                _asDouble(row['conversionRate']).toStringAsFixed(2),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selected
                                      ..clear()
                                      ..add(id);
                                    _preview = null;
                                    _removeDiscount = false;
                                    _bulkMode = 'set';
                                  });
                                  _focusProduct(id);
                                },
                                child: const Text('Edit'),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (_selected.isNotEmpty) _buildBulkPanel(),
                const SizedBox(height: 14),
                _buildAnalyticsPanel(),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildMiniBarChart(
                        title: 'Demand Activity',
                        values: _chartValues(_timeSeriesPoints, 'views'),
                        footer:
                            'Recent visibility trend for ${_focusedProduct?['name'] ?? 'this product'}.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniBarChart(
                        title: 'Purchase Activity',
                        values: _chartValues(_timeSeriesPoints, 'purchases'),
                        footer:
                            '${_formatNumber(purchases)} purchases tracked in ${_periodLabel(_period).toLowerCase()}.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.text, required this.impact});

  final String text;
  final String impact;

  @override
  Widget build(BuildContext context) {
    final high = impact.toUpperCase().contains('HIGH');
    final color = high ? const Color(0xFFC03C2E) : const Color(0xFFAA7F14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: GoogleFonts.inter(height: 1.4))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
            child: Text(impact, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () {}, child: const Text('Apply Suggestion')),
        ],
      ),
    );
  }
}
