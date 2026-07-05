import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../../theme.dart';
import '../../../models/models.dart';
import 'product_form_controller.dart';

class VariantDetailScreen extends StatefulWidget {
  final ProductFormController controller;
  final int? variantIndex;

  const VariantDetailScreen({
    super.key,
    required this.controller,
    this.variantIndex,
  });

  @override
  State<VariantDetailScreen> createState() => _VariantDetailScreenState();
}

class _VariantDetailScreenState extends State<VariantDetailScreen> {
  static const List<Color> _presetColors = [
    Color(0xFF111111),
    Color(0xFF374151),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF0F766E),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFFEA580C),
    Color(0xFFDC2626),
    Color(0xFFD946EF),
    Color(0xFFDB2777),
    Color(0xFFE5E7EB),
  ];

  final _nameController = TextEditingController();
  final _hexController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceOverrideController = TextEditingController();
  bool _showAdvancedHex = false;
  Color _selectedColor = Colors.black;

  @override
  void initState() {
    super.initState();
    if (widget.variantIndex != null) {
      final variant = widget.controller.colorVariants[widget.variantIndex!];
      _nameController.text = variant.name;
      _selectedColor = _parseHex(variant.hex);
      _hexController.text = _colorToHex(_selectedColor);
      _skuController.text = variant.variantId;
      _priceOverrideController.text = variant.price?.toStringAsFixed(0) ?? '';
    } else {
      _selectedColor = Colors.black;
      _hexController.text = _colorToHex(_selectedColor);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    _skuController.dispose();
    _priceOverrideController.dispose();
    super.dispose();
  }

  void _saveVariant() {
    final normalizedHex = _colorToHex(_selectedColor);
    final newVariant = ProductColorVariant(
      variantId: _skuController.text.isEmpty
          ? 'VAR-${DateTime.now().millisecondsSinceEpoch}'
          : _skuController.text,
      name: _nameController.text,
      hex: normalizedHex,
      images: [], // To be implemented with media section later
      sizes: [], // Simplified for now
      price: double.tryParse(_priceOverrideController.text),
      status: 'active',
    );

    if (widget.variantIndex != null) {
      widget.controller.colorVariants[widget.variantIndex!] = newVariant;
    } else {
      widget.controller.colorVariants.add(newVariant);
    }

    // Future.microtask(() => widget.controller.notifyListeners());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.variantIndex != null ? 'Edit Variant' : 'Add Variant',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AbzioTheme.textPrimary,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: AbzioTheme.textPrimary),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveVariant,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AbzioTheme.accentColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AbzioTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Color Details',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Color Name',
                      hintText: 'e.g. Midnight Black',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await _showColorPickerSheet(context);
                      if (picked == null) {
                        return;
                      }
                      setState(() {
                        _selectedColor = picked;
                        _hexController.text = _colorToHex(picked);
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Color',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AbzioTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hexController.text.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AbzioTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to choose a different color',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AbzioTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.palette_outlined,
                            color: AbzioTheme.accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preset colors',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presetColors.map((color) {
                      final isSelected = color.value == _selectedColor.value;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                            _hexController.text = _colorToHex(color);
                          });
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AbzioTheme.accentColor
                                  : Colors.black12,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8),
                    title: Text(
                      'Advanced HEX editing',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Optional manual override for exact HEX values',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AbzioTheme.textSecondary,
                      ),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() => _showAdvancedHex = expanded);
                    },
                    children: [
                      TextFormField(
                        controller: _hexController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[#0-9a-fA-F]'),
                          ),
                          LengthLimitingTextInputFormatter(7),
                        ],
                        onChanged: (value) {
                          final parsed = _parseHex(value);
                          setState(() {
                            _selectedColor = parsed;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'HEX Code',
                          hintText: '#000000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _showAdvancedHex
                              ? 'Manual HEX editing is enabled.'
                              : 'Select a color visually or from presets. HEX is generated automatically.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AbzioTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _skuController,
                    decoration: InputDecoration(
                      labelText: 'Variant SKU (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceOverrideController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price Override (Optional)',
                      hintText: 'Leave empty to use main price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Color _parseHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
      return Colors.grey;
    } catch (e) {
      return Colors.grey;
    }
  }

  String _colorToHex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }

  Future<Color?> _showColorPickerSheet(BuildContext context) async {
    var tempColor = _selectedColor;
    return showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void update(Color color) {
              setSheetState(() => tempColor = color);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Choose Color',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 90,
                          decoration: BoxDecoration(
                            color: tempColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preset Colors',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AbzioTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _presetColors.map((color) {
                            final selected = color.value == tempColor.value;
                            return GestureDetector(
                              onTap: () => update(color),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? AbzioTheme.accentColor
                                        : Colors.black12,
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Fine-tune',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AbzioTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildColorSlider(
                          label: 'Red',
                          value: tempColor.red.toDouble(),
                          color: Colors.red,
                          onChanged: (value) => update(
                            Color.fromARGB(
                              tempColor.alpha,
                              value.round(),
                              tempColor.green,
                              tempColor.blue,
                            ),
                          ),
                        ),
                        _buildColorSlider(
                          label: 'Green',
                          value: tempColor.green.toDouble(),
                          color: Colors.green,
                          onChanged: (value) => update(
                            Color.fromARGB(
                              tempColor.alpha,
                              tempColor.red,
                              value.round(),
                              tempColor.blue,
                            ),
                          ),
                        ),
                        _buildColorSlider(
                          label: 'Blue',
                          value: tempColor.blue.toDouble(),
                          color: Colors.blue,
                          onChanged: (value) => update(
                            Color.fromARGB(
                              tempColor.alpha,
                              tempColor.red,
                              tempColor.green,
                              value.round(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(tempColor),
                            child: const Text('Apply Color'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AbzioTheme.textSecondary,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
