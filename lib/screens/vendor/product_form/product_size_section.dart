import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme.dart';
import 'product_form_controller.dart';

class ProductSizeSection extends StatelessWidget {
  const ProductSizeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();
    final sizes = controller.sizeQuantities.keys.toList();

    if (sizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Size & Stock',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.textPrimary,
                ),
              ),
              Text(
                'Total Stock: ${controller.totalStock}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dynamic sizes generated based on category: ${controller.selectedCategory}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AbzioTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sizes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final size = sizes[index];
              return Row(
                children: [
                  Container(
                    width: 60,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AbzioTheme.borderColor),
                    ),
                    child: Text(
                      size,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: controller.sizeQuantities[size]?.toString() ?? '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        final qty = int.tryParse(val) ?? 0;
                        controller.sizeQuantities[size] = qty;
                        // To update total stock UI, force notify
                        // We could use a specific method in controller
                        // Hacky fix for stateless widget to notify Provider:
                        Future.microtask(() => controller.notifyListeners());
                      },
                      decoration: InputDecoration(
                        hintText: 'Qty',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18, color: AbzioTheme.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AbzioTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AbzioTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AbzioTheme.accentColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
