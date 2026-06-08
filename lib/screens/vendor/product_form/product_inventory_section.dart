import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import 'product_form_controller.dart';

class ProductInventorySection extends StatefulWidget {
  const ProductInventorySection({super.key});

  @override
  State<ProductInventorySection> createState() => _ProductInventorySectionState();
}

class _ProductInventorySectionState extends State<ProductInventorySection> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();
    
    // Auto status logic
    final stock = int.tryParse(controller.stockController.text) ?? 0;
    final lowStock = int.tryParse(controller.lowStockThresholdController.text) ?? 5;
    
    String statusLabel = 'In Stock';
    Color statusColor = const Color(0xFF16A34A);
    Color statusBg = const Color(0xFFF0FDF4);
    
    if (stock <= 0) {
      statusLabel = 'Out Of Stock';
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
    } else if (stock <= lowStock) {
      statusLabel = 'Low Stock';
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inventory',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  label: 'SKU (Stock Keeping Unit)',
                  controller: controller.skuController,
                  hint: 'E.g. DRESS-BLK-M',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: controller.generateSku,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AbzioTheme.lightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Auto Gen',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AbzioTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Stock Quantity',
                  controller: controller.stockController,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Low Stock Threshold',
                  controller: controller.lowStockThresholdController,
                  hint: '5',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Advanced Inventory Settings',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AbzioTheme.textSecondary,
                ),
              ),
              children: [
                const SizedBox(height: 8),
                _buildTextField(
                  label: 'Barcode (ISBN, UPC, GTIN, etc.)',
                  controller: controller.barcodeController,
                  hint: 'Optional',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AbzioTheme.textSecondary.withValues(alpha: 0.5)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AbzioTheme.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AbzioTheme.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AbzioTheme.accentColor),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
