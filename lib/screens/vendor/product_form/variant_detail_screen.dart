import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final _nameController = TextEditingController();
  final _hexController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceOverrideController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.variantIndex != null) {
      final variant = widget.controller.colorVariants[widget.variantIndex!];
      _nameController.text = variant.name;
      _hexController.text = variant.hexCode;
      _skuController.text = variant.id;
      _priceOverrideController.text = variant.priceOverride?.toStringAsFixed(0) ?? '';
    } else {
      _hexController.text = '#000000';
    }
  }

  void _saveVariant() {
    final newVariant = ProductColorVariant(
      id: _skuController.text.isEmpty ? 'VAR-${DateTime.now().millisecondsSinceEpoch}' : _skuController.text,
      name: _nameController.text,
      hexCode: _hexController.text,
      images: [], // To be implemented with media section later
      sizes: [],  // Simplified for now
      priceOverride: double.tryParse(_priceOverrideController.text),
      isActive: true,
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AbzioTheme.textPrimary, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: AbzioTheme.textPrimary),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveVariant,
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AbzioTheme.accentColor)),
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
                border: Border.all(color: AbzioTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Color Name',
                      hintText: 'e.g. Midnight Black',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _parseHex(_hexController.text),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _hexController,
                          onChanged: (v) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Hex Code',
                            hintText: '#000000',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceOverrideController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price Override (Optional)',
                      hintText: 'Leave empty to use main price',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}
