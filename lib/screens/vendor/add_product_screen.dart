import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../theme.dart';
import 'product_form/product_form_controller.dart';
import 'product_form/product_media_section.dart';
import 'product_form/product_basic_info_section.dart';
import 'product_form/product_pricing_section.dart';
import 'product_form/product_inventory_section.dart';
import 'product_form/product_size_section.dart';
import 'product_form/product_variants_section.dart';
import 'product_form/product_details_section.dart';
import 'product_form/product_delivery_section.dart';
import 'product_form/product_ai_section.dart';
import 'product_form/product_publish_bar.dart';
import '../../services/database_service.dart';

class AddProductScreen extends StatelessWidget {
  final String storeId;
  final Product? existingProduct;

  const AddProductScreen({
    super.key,
    required this.storeId,
    this.existingProduct,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductFormController(
        storeId: storeId,
        existingProduct: existingProduct,
      ),
      child: const _AddProductScreenContent(),
    );
  }
}

class _AddProductScreenContent extends StatefulWidget {
  const _AddProductScreenContent();

  @override
  State<_AddProductScreenContent> createState() =>
      _AddProductScreenContentState();
}

class _AddProductScreenContentState extends State<_AddProductScreenContent> {
  bool _isSubmitting = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFC03C2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _validateForm(ProductFormController controller) {
    if (controller.imageUrls.isEmpty) {
      _showError('Cover image is required');
      return false;
    }
    if (controller.nameController.text.trim().isEmpty) {
      _showError('Product name is required');
      return false;
    }
    if (controller.selectedCategory.isEmpty) {
      _showError('Category must be selected');
      return false;
    }
    if ((double.tryParse(controller.sellingPriceController.text) ?? 0) <= 0) {
      _showError('Valid selling price is required');
      return false;
    }
    if (controller.totalStock <= 0 && controller.colorVariants.isEmpty) {
      _showError('Product must have stock or at least one purchasable variant');
      return false;
    }
    return true;
  }

  Future<void> _submit(
    BuildContext context,
    ProductFormController controller,
    ProductStatus newStatus,
  ) async {
    if (newStatus == ProductStatus.active && !_validateForm(controller)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final db = DatabaseService();

      // Basic translation to Product model (In real implementation, connect to API)
      final p = Product(
        id:
            controller.existingProduct?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        storeId: controller.storeId,
        name: controller.nameController.text.trim(),
        brand: controller.brandController.text.trim(),
        description: controller.descriptionController.text.trim(),
        price: double.tryParse(controller.sellingPriceController.text) ?? 0,
        originalPrice: double.tryParse(controller.mrpController.text),
        images: controller.imageUrls,
        colorVariants: controller.colorVariants,
        sizes: controller.sizeQuantities.keys.toList(),
        stock: controller.totalStock,
        category: controller.selectedCategory,
        subcategory: controller.selectedSubcategory,
        status: controller.status,
        model3d: controller.glbModelController.text,
        assetBundleUrl: controller.assetBundleUrlController.text,
        rigProfile: controller.rigProfileController.text,
        materialProfile: controller.materialProfileController.text,
        structuredAttributes: controller.attributeControllers.entries
            .map((e) => {'key': e.key, 'value': e.value.text})
            .toList(),
        deliveryInfo: {
          'sameDayEligible': controller.sameDayDelivery,
          'codEligible': controller.cashOnDelivery,
          'freeReturns': controller.freeReturns,
          'tryBeforeYouBuy': controller.tryBeforeYouBuy,
          'expressDelivery': controller.expressDelivery,
          'etaLabel': controller.etaDropdown,
        },
      );

      if (controller.existingProduct != null) {
        await db.updateProduct(p);
        if (!context.mounted) return;
        _showSuccess('Product updated successfully!');
      } else {
        await db.addProduct(p);
        if (!context.mounted) return;
        _showSuccess('Product created successfully!');
      }

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Error saving product: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProductFormController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          controller.existingProduct != null ? 'Edit Product' : 'Add Product',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AbzioTheme.textPrimary,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: AbzioTheme.textPrimary),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: controller.formKey,
            child: ListView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 120,
              ),
              children: const [
                ProductMediaSection(),
                SizedBox(height: 16),
                ProductBasicInfoSection(),
                SizedBox(height: 16),
                ProductPricingSection(),
                SizedBox(height: 16),
                ProductInventorySection(),
                SizedBox(height: 16),
                ProductSizeSection(),
                SizedBox(height: 16),
                ProductVariantsSection(),
                SizedBox(height: 16),
                ProductDetailsSection(),
                SizedBox(height: 16),
                ProductDeliverySection(),
                SizedBox(height: 16),
                ProductAiSection(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ProductPublishBar(
              onSaveDraft: () =>
                  _submit(context, controller, ProductStatus.draft),
              onPreview: () {
                _showSuccess(
                  'Live Preview not connected in this simplified build',
                );
              },
              onPublish: () =>
                  _submit(context, controller, ProductStatus.active),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AbzioTheme.accentColor),
              ),
            ),
        ],
      ),
    );
  }
}
