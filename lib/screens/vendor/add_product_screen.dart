import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../config/product_attribute_config.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/image_url_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';

class AddProductScreen extends StatefulWidget {
  final String storeId;
  final Product? existingProduct;

  const AddProductScreen({
    super.key,
    required this.storeId,
    this.existingProduct,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stockController = TextEditingController();
  final _imageUrlsController = TextEditingController();
  final _model3dController = TextEditingController();
  final _assetBundleUrlController = TextEditingController();
  final _rigProfileController = TextEditingController();
  final _materialProfileController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _highlightsController = TextEditingController();
  final _colorVariantsController = TextEditingController();
  final _boutiqueNameController = TextEditingController();
  final _boutiqueLogoController = TextEditingController();
  final _deliveryEtaController = TextEditingController();
  final _deliveryCountdownController = TextEditingController();
  final _specificationsController = TextEditingController();
  final _socialProofController = TextEditingController();
  final _completeLookController = TextEditingController();
  final List<ProductColorVariant> _colorVariantDrafts = [];
  String _selectedCategory = 'MEN';
  bool _isActive = true;
  bool _boutiqueVerified = false;
  bool _sameDayEligible = true;
  bool _tryAtHomeEligible = true;
  bool _tryOnAvailable = false;
  bool _freeReturns = true;
  bool _cashOnDelivery = true;
  bool _isUploading = false;
  final _picker = ImagePicker();
  late final Map<String, TextEditingController> _attributeControllers;

  final List<String> _categories = [
    'MEN',
    'WOMEN',
    'WEDDING',
    'ACCESSORIES',
    'FORMAL',
    'SHOES',
    'FOOTWEAR',
    'SHIRT',
    'T-SHIRT',
    'JEANS',
    'TROUSERS',
    'DRESS',
    'WATCH',
    'SUNGLASSES',
    'BAG',
    'JEWELLERY',
    'PERFUME',
    'BEAUTY',
    'HOME & LIVING',
    'ELECTRONICS',
  ];
  static const Map<String, String> _attributeHints = {
    'upper_material': 'Mesh, knit, leather',
    'sole_material': 'Rubber, EVA',
    'closure': 'Lace-up, buckle, zip',
    'occasion': 'Running, casual, office',
    'cushioning': 'High, medium, responsive',
    'fit_type': 'Regular, snug, relaxed',
    'fabric': 'Cotton, satin, linen',
    'fit': 'Regular, slim, oversized',
    'pattern': 'Solid, striped, printed',
    'sleeve_type': 'Full sleeve, sleeveless',
    'dial_shape': 'Round, rectangular',
    'strap_material': 'Leather, stainless steel',
    'movement': 'Quartz, automatic',
    'water_resistance': '50m, splash resistant',
    'material': 'Leather, vegan leather, canvas',
    'capacity': '20L, fits 15-inch laptop',
    'strap_type': 'Single strap, dual strap',
    'usage': 'Travel, office, daily wear',
  };
  static final List<String> _allAttributeKeys = {
    ...genericAttributeFields,
    for (final config in productAttributeConfig.values)
      for (final section in config.sections) ...section.fields,
  }.toList()..sort();

  @override
  void initState() {
    super.initState();
    _attributeControllers = {
      for (final key in _allAttributeKeys) key: TextEditingController(),
    };
    _imageUrlsController.addListener(_handleImageUrlsChanged);
    final product = widget.existingProduct;
    if (product != null) {
      _nameController.text = product.name;
      _brandController.text = product.brand;
      _priceController.text = product.price.toStringAsFixed(0);
      _originalPriceController.text =
          product.originalPrice?.toStringAsFixed(0) ?? '';
      _descriptionController.text = product.description;
      _stockController.text = product.stock.toString();
      _imageUrlsController.text = product.images.join('\n');
      _model3dController.text = product.model3d ?? '';
      _assetBundleUrlController.text = product.assetBundleUrl ?? '';
      _rigProfileController.text = product.rigProfile ?? '';
      _materialProfileController.text = product.materialProfile ?? '';
      _subcategoryController.text = product.subcategory;
      _highlightsController.text = product.highlights.join('\n');
      _colorVariantDrafts.addAll(product.colorVariants);
      _syncColorVariantController();
      _boutiqueNameController.text =
          product.boutiqueInfo['name']?.toString() ?? '';
      _boutiqueLogoController.text =
          product.boutiqueInfo['logoUrl']?.toString() ?? '';
      _boutiqueVerified = product.boutiqueInfo['verified'] == true;
      _deliveryEtaController.text =
          product.deliveryInfo['etaLabel']?.toString() ?? '';
      _deliveryCountdownController.text =
          product.deliveryInfo['countdownMinutes']?.toString() ?? '';
      _sameDayEligible = product.deliveryInfo['sameDayEligible'] != false;
      _tryAtHomeEligible =
          product.deliveryInfo['tryAtHomeAvailable'] == true ||
          product.deliveryInfo['tryAtHomeEligible'] == true ||
          product.tryAtHomeAvailable;
      _tryOnAvailable = product.tryOnAvailable;
      _freeReturns = product.deliveryInfo['freeReturns'] != false;
      _cashOnDelivery = product.deliveryInfo['cashOnDelivery'] != false;
      _specificationsController.text = product.specifications.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
      _socialProofController.text = [
        if ((product.socialProof['viewersToday']?.toString() ?? '').isNotEmpty)
          'viewers_today: ${product.socialProof['viewersToday']}',
        if ((product.socialProof['ordersThisWeek']?.toString() ?? '')
            .isNotEmpty)
          'orders_this_week: ${product.socialProof['ordersThisWeek']}',
        if ((product.socialProof['wishlistCount']?.toString() ?? '').isNotEmpty)
          'wishlist_count: ${product.socialProof['wishlistCount']}',
        if ((product.socialProof['purchasesText']?.toString() ?? '').isNotEmpty)
          'purchases_text: ${product.socialProof['purchasesText']}',
      ].join('\n');
      _completeLookController.text = product.completeLookProductIds.join(', ');
      _selectedCategory = product.category;
      _attributeControllers['category']?.text = product.category;
      _attributeControllers['subcategory']?.text = product.subcategory;
      _isActive = product.isActive;
      for (final entry in product.structuredAttributes) {
        final key = entry['key']?.toString().trim() ?? '';
        final value = entry['value']?.toString() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          _attributeControllers[key]?.text = value;
        }
      }
      for (final entry in product.attributes.entries) {
        final controller = _attributeControllers[entry.key];
        if (controller != null && controller.text.trim().isEmpty) {
          controller.text = entry.value;
        }
      }
      if (product.attributeText('fabric').isEmpty &&
          (product.fabric ?? '').isNotEmpty) {
        _attributeControllers['fabric']?.text = product.fabric!;
      }
    }
  }

  @override
  void dispose() {
    _imageUrlsController.removeListener(_handleImageUrlsChanged);
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    _imageUrlsController.dispose();
    _model3dController.dispose();
    _assetBundleUrlController.dispose();
    _rigProfileController.dispose();
    _materialProfileController.dispose();
    _subcategoryController.dispose();
    _highlightsController.dispose();
    _colorVariantsController.dispose();
    _boutiqueNameController.dispose();
    _boutiqueLogoController.dispose();
    _deliveryEtaController.dispose();
    _deliveryCountdownController.dispose();
    _specificationsController.dispose();
    _socialProofController.dispose();
    _completeLookController.dispose();
    _colorVariantDrafts.clear();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleImageUrlsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _miniPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF7B6437),
        ),
      ),
    );
  }

  void _syncColorVariantController() {
    _colorVariantsController.text = _colorVariantDrafts
        .map(
          (variant) => [
            variant.name,
            variant.hex,
            variant.thumbnail.isNotEmpty ? variant.thumbnail : variant.imageUrl,
          ].where((value) => value.trim().isNotEmpty).join(' | '),
        )
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.existingProduct == null ? 'ADD PRODUCT' : 'EDIT PRODUCT',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Product Image URLs'),
            TextField(
              controller: _imageUrlsController,
              maxLines: 5,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText:
                    'Paste 4 to 5 portrait image URLs (4:5), one per line',
              ),
            ),
            const SizedBox(height: 12),
            _imagePreviewPanel(),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadProductImage,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('UPLOAD PRODUCT IMAGE'),
            ),
            const SizedBox(height: 10),
            Text(
              'Use portrait 4:5 product images for the cleanest fashion presentation. Target 1200 × 1500 framing, keep full outfits visible, and use neutral lighting for the best preview. Cloudinary uploads save optimized image URLs, and you can still paste public image links when needed.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AbzioTheme.grey500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            _buildLabel('Product Name'),
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'e.g. Slim Fit Denim Jacket',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Brand'),
            TextField(
              controller: _brandController,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'e.g. Roadster'),
            ),
            const SizedBox(height: 20),

            _buildLabel('Category'),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                filled: true,
                fillColor: AbzioTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedCategory = val;
                  _attributeControllers['category']?.text = val;
                });
              },
            ),
            const SizedBox(height: 20),

            _buildLabel('Subcategory / Product Type'),
            TextField(
              controller: _subcategoryController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: _subcategoryHint,
                helperText: _attributeHelperText,
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('3D Model (GLB/GLTF URL or asset key)'),
            TextField(
              controller: _model3dController,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText:
                    'shirt_001.glb or https://cdn.example.com/models/shirt_001.glb',
                helperText:
                    'Optional: used for avatar try-on and AR experiences.',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('3D Asset Bundle URL (Optional)'),
            TextField(
              controller: _assetBundleUrlController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'https://cdn.example.com/ar/female_dress_bundle',
                helperText: _arRuntimeBundleHelperText(),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Rig Profile'),
            TextField(
              controller: _rigProfileController,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText:
                    'female_dress_v1, female_top_v1, male_shirt_v1, unisex_torso_v1',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Material Profile'),
            TextField(
              controller: _materialProfileController,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText:
                    'cotton_matte, silk_sheen, linen_soft, structured_formal',
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Selling Price'),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: '1499'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Original Price (MRP)'),
                      TextField(
                        controller: _originalPriceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: '2499'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildLiveDiscountPreview(),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Stock Qty'),
                      TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: '10'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              value: _isActive,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Product visible to customers',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _isActive
                    ? 'This product is active in your catalog.'
                    : 'This product stays hidden until you activate it.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AbzioTheme.grey500,
                ),
              ),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 8),

            _buildLabel('Description'),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Describe your product in detail...',
              ),
            ),

            const SizedBox(height: 20),
            _buildPremiumCommerceSection(),
            const SizedBox(height: 20),
            _buildAttributeEditor(),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.existingProduct == null
                            ? 'UPLOAD PRODUCT'
                            : 'SAVE PRODUCT',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _submitProduct() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      return;
    }
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }
    final imageUrls = _parseImageUrls(_imageUrlsController.text);
    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one valid image URL or upload an image first.',
          ),
        ),
      );
      return;
    }
    if (imageUrls.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 4 product images for the slide gallery.'),
        ),
      );
      return;
    }

    final model3dUrl = _normalizeModel3dInput(_model3dController.text);
    if (model3dUrl != _model3dController.text.trim()) {
      _model3dController.text = model3dUrl;
    }
    var assetBundleUrl = _assetBundleUrlController.text.trim();
    if (model3dUrl.isNotEmpty &&
        _isValidHttpUrl(model3dUrl) &&
        !_looksLikeModelFileUrl(model3dUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '3D Model URL must end with .glb or .gltf (or use a valid model asset key).',
          ),
        ),
      );
      return;
    }
    if (model3dUrl.isNotEmpty &&
        !_isValidHttpUrl(model3dUrl) &&
        model3dUrl.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '3D Model must be a full URL (https://...) or a simple asset key like shirt_001.glb.',
          ),
        ),
      );
      return;
    }
    // If a GLB/GLTF URL was accidentally pasted into AR bundle field,
    // auto-clear it and continue using the 3D model URL path.
    if (assetBundleUrl.isNotEmpty &&
        (_looksLikeModelFileUrl(assetBundleUrl) ||
            assetBundleUrl == model3dUrl)) {
      assetBundleUrl = '';
      _assetBundleUrlController.clear();
    }
    // AR bundle URL is optional. Do not block product save if it is missing
    // or malformed when vendors are using GLB-only AR assets.
    final normalizedassetBundleUrl =
        assetBundleUrl.isNotEmpty && _isValidHttpUrl(assetBundleUrl)
        ? assetBundleUrl
        : null;

    setState(() => _isUploading = true);

    final existing = widget.existingProduct;
    final attributes = _collectAttributes();
    final highlights = _parseLines(_highlightsController.text);
    final boutiqueName = _boutiqueNameController.text.trim();
    final boutiqueLogo = _boutiqueLogoController.text.trim();
    final deliveryEta = _deliveryEtaController.text.trim();
    final deliveryCountdown =
        int.tryParse(_deliveryCountdownController.text.trim()) ?? 0;
    final specifications = _parseKeyValueLines(_specificationsController.text);
    final socialProof = _parseKeyValueLines(_socialProofController.text)
      ..removeWhere((key, value) => value.trim().isEmpty);
    final completeLookProductIds = _parseIdList(_completeLookController.text);

    if (_colorVariantDrafts.isEmpty) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one color variant before saving.'),
        ),
      );
      return;
    }
    final invalidVariant = _colorVariantDrafts.firstWhere(
      (variant) =>
          ((variant.thumbnail.isNotEmpty ? variant.thumbnail : variant.imageUrl)
              .trim()
              .isEmpty) ||
          variant.stock <= 0,
      orElse: () => const ProductColorVariant(name: ''),
    );
    if (invalidVariant.name.isNotEmpty) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Each color variant must have an image and stock before publishing.',
          ),
        ),
      );
      return;
    }

    final product = Product(
      store: existing?.store,
      id: existing?.id ?? '',
      storeId: widget.storeId,
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.tryParse(_priceController.text) ?? 0,
      originalPrice: double.tryParse(_originalPriceController.text.trim()),
      images: imageUrls,
      sizes: existing?.sizes ?? ['S', 'M', 'L', 'XL'],
      stock: int.tryParse(_stockController.text) ?? 0,
      category: _selectedCategory,
      subcategory: _subcategoryController.text.trim(),
      isActive: _isActive,
      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
      rating: existing?.rating ?? 0,
      reviewCount: existing?.reviewCount ?? 0,
      highlights: highlights,
      colorVariants: _colorVariantDrafts,
      boutiqueInfo: {
        'name': boutiqueName,
        'logoUrl': boutiqueLogo,
        'verified': _boutiqueVerified,
        'rating': existing?.store?.rating ?? 0,
        'ctaLabel': 'View Store',
      },
      deliveryInfo: {
        'sameDayEligible': _sameDayEligible,
        'tryAtHomeAvailable': _tryAtHomeEligible,
        'freeReturns': _freeReturns,
        'cashOnDelivery': _cashOnDelivery,
        'etaLabel': deliveryEta,
        'countdownMinutes': deliveryCountdown,
      },
      socialProof: socialProof,
      specifications: specifications,
      completeLookProductIds: completeLookProductIds,
      isCustomTailoring: existing?.isCustomTailoring ?? false,
      outfitType: existing?.outfitType,
      fabric: attributes['fabric'] ?? existing?.fabric,
      model3d: _model3dController.text.trim().isEmpty ? null : model3dUrl,
      assetBundleUrl: normalizedassetBundleUrl,
      rigProfile: _rigProfileController.text.trim().isEmpty
          ? null
          : _rigProfileController.text.trim(),
      materialProfile: _materialProfileController.text.trim().isEmpty
          ? null
          : _materialProfileController.text.trim(),
      attributes: {
        ...attributes,
        'sameDayAvailable': _sameDayEligible.toString(),
        'tryAtHomeAvailable': _tryAtHomeEligible.toString(),
        'tryOnAvailable': _tryOnAvailable.toString(),
      },
      customizations: existing?.customizations ?? const {},
      measurements: existing?.measurements ?? const {},
      addons: existing?.addons ?? const [],
      measurementProfileLabel: existing?.measurementProfileLabel,
      neededBy: existing?.neededBy,
      tailoringDeliveryMode: existing?.tailoringDeliveryMode,
      tailoringExtraCost: existing?.tailoringExtraCost ?? 0,
    );

    try {
      if (existing == null) {
        await DatabaseService().addProduct(product, actor: auth.user);
      } else {
        await DatabaseService().updateProduct(product, actor: auth.user);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Text(
            existing == null
                ? 'Product uploaded successfully!'
                : 'Product updated successfully!',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppErrorText.from(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickAndUploadProductImage() async {
    try {
      final actor = context.read<AuthProvider>().user;
      if (actor == null) {
        return;
      }
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 84,
      );
      if (file == null) {
        return;
      }
      setState(() => _isUploading = true);
      final url = await StorageService().uploadPickedImage(
        file: file,
        folder: 'product_images',
        ownerId: actor.id,
      );
      if (!mounted) {
        return;
      }
      final current = _parseImageUrls(_imageUrlsController.text);
      if (current.length >= 5) {
        current.removeLast();
      }
      current.insert(0, url);
      setState(() => _imageUrlsController.text = current.join('\n'));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product image uploaded.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorText.from(error).contains('Cloudinary')
                ? 'Cloudinary upload is not configured yet. Paste a public image URL instead.'
                : AppErrorText.from(error),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _imagePreviewPanel() {
    final imageUrls = _parseImageUrls(_imageUrlsController.text);
    if (imageUrls.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AbzioTheme.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AbzioTheme.grey200),
        ),
        alignment: Alignment.center,
        child: Text(
          'Live preview appears here\n4:5 portrait crop',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AbzioTheme.grey500,
            height: 1.5,
          ),
        ),
      );
    }

    final firstImage = imageUrls.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AbzioTheme.grey100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AbzioTheme.grey200),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Image.network(
              firstImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    'Preview unavailable',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AbzioTheme.grey500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Preview crops to a 4:5 fashion frame and preserves portrait composition.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AbzioTheme.grey500,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: AbzioTheme.grey500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  bool _isValidImageUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return false;
    }
    return uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _looksLikeModelFileUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.endsWith('.glb') ||
        lower.endsWith('.gltf') ||
        lower.endsWith('.fbx') ||
        lower.endsWith('.obj') ||
        lower.endsWith('.usdz');
  }

  String _normalizeModel3dInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (_isValidHttpUrl(value)) {
      return _normalizeCloudinaryModelUrl(value);
    }
    // Common vendor input from Cloudinary UI copied without domain:
    // load/v177.../item.glb -> https://res.cloudinary.com/<cloud>/image/upload/load/v177.../item.glb
    if (value.startsWith('load/') && _looksLikeModelFileUrl(value)) {
      return _normalizeCloudinaryModelUrl(
        'https://res.cloudinary.com/dsgi8awyo/image/upload/$value',
      );
    }
    if (value.startsWith('res.cloudinary.com/')) {
      return _normalizeCloudinaryModelUrl('https://$value');
    }
    return _normalizeCloudinaryModelUrl(value);
  }

  String _normalizeCloudinaryModelUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('load/') && _looksLikeModelFileUrl(trimmed)) {
      return _normalizeCloudinaryModelUrl(
        'https://res.cloudinary.com/dsgi8awyo/image/upload/$trimmed',
      );
    }
    if (lower.startsWith('res.cloudinary.com/')) {
      return _normalizeCloudinaryModelUrl('https://$trimmed');
    }
    if (!trimmed.contains('res.cloudinary.com') ||
        !_looksLikeModelFileUrl(trimmed)) {
      return trimmed;
    }
    if (trimmed.contains('/raw/upload/')) {
      return trimmed;
    }
    return trimmed.replaceFirst('/image/upload/', '/raw/upload/');
  }

  List<String> _parseImageUrls(String raw) {
    final urls = raw
        .split(RegExp(r'[\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && _isValidImageUrl(value))
        .toList();
    if (urls.isEmpty) {
      return <String>[];
    }
    return ImageUrlService.optimizeAll(urls.take(5));
  }

  List<String> _parseLines(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Map<String, String> _parseKeyValueLines(String raw) {
    final result = <String, String>{};
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      final value = line.trim();
      if (value.isEmpty) {
        continue;
      }
      final parts = value.split(RegExp(r'[:=]'));
      if (parts.length < 2) {
        continue;
      }
      final key = parts.first.trim();
      final parsed = parts.sublist(1).join(':').trim();
      if (key.isEmpty || parsed.isEmpty) {
        continue;
      }
      result[key] = parsed;
    }
    return result;
  }

  List<String> _parseCsvList(String raw) {
    return raw
        .split(RegExp(r'[,\n\r]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<ProductVariantSizeStock> _parseVariantSizeStocks(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(':');
          final sizeName = parts.first.trim();
          final stock = parts.length > 1
              ? int.tryParse(parts.last.trim()) ?? 0
              : 0;
          return ProductVariantSizeStock(
            sizeName: sizeName,
            stockQuantity: stock,
          );
        })
        .where((item) => item.sizeName.isNotEmpty)
        .toList();
  }

  Future<ProductColorVariant?> _openColorVariantEditor({
    ProductColorVariant? initial,
    bool duplicate = false,
  }) async {
    final nameController = TextEditingController(
      text: duplicate ? '' : initial?.name ?? '',
    );
    final hexController = TextEditingController(
      text: duplicate ? '#C6A769' : initial?.hex ?? '#C6A769',
    );
    final skuController = TextEditingController(
      text: duplicate ? '' : initial?.sku ?? '',
    );
    final barcodeController = TextEditingController(
      text: duplicate ? '' : initial?.barcode ?? '',
    );
    final priceController = TextEditingController(
      text: duplicate ? '' : (initial?.price?.toStringAsFixed(0) ?? ''),
    );
    final discountController = TextEditingController(
      text: duplicate ? '' : (initial?.discountPrice?.toStringAsFixed(0) ?? ''),
    );
    final stockController = TextEditingController(
      text: duplicate ? '0' : initial?.stock.toString() ?? '0',
    );
    final thumbnailController = TextEditingController(
      text: duplicate
          ? ''
          : (initial?.thumbnail.isNotEmpty == true
                ? initial!.thumbnail
                : initial?.imageUrl ?? ''),
    );
    final imagesController = TextEditingController(
      text: duplicate ? '' : (initial?.images.join('\n') ?? ''),
    );
    final sizesController = TextEditingController(
      text: duplicate ? '' : (initial?.sizes.join(', ') ?? ''),
    );
    final sizeStocksController = TextEditingController(
      text: duplicate
          ? ''
          : (initial?.sizeStocks
                    .map((item) => '${item.sizeName}:${item.stockQuantity}')
                    .join('\n') ??
                ''),
    );
    final etaController = TextEditingController(
      text: duplicate
          ? ''
          : (initial?.deliveryInfo['etaLabel']?.toString() ?? ''),
    );
    bool sameDayEligible = initial?.deliveryInfo['sameDayEligible'] != false;
    bool freeReturns = initial?.deliveryInfo['freeReturns'] != false;
    bool cashOnDelivery = initial?.deliveryInfo['cashOnDelivery'] != false;
    bool active = (initial?.status ?? 'active') == 'active';

    final result = await showDialog<ProductColorVariant?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(
            initial == null ? 'Add Color Variant' : 'Edit Color Variant',
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Color Name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: hexController,
                        decoration: const InputDecoration(
                          labelText: 'Hex Code',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: skuController,
                        decoration: const InputDecoration(
                          labelText: 'Variant SKU',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Variant Barcode',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price Override',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Discount Price',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Variant Stock'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thumbnailController,
                  decoration: const InputDecoration(labelText: 'Thumbnail URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imagesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Gallery Images',
                    helperText: 'One URL per line',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizesController,
                  decoration: const InputDecoration(
                    labelText: 'Sizes',
                    helperText: 'Comma separated: S, M, L, XL',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizeStocksController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Size Stock Map',
                    helperText: 'Format: S:10\nM:8\nL:5',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: etaController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery ETA Label',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Active'),
                      selected: active,
                      onSelected: (value) =>
                          setDialogState(() => active = value),
                    ),
                    FilterChip(
                      label: const Text('Same Day'),
                      selected: sameDayEligible,
                      onSelected: (value) =>
                          setDialogState(() => sameDayEligible = value),
                    ),
                    FilterChip(
                      label: const Text('Free Returns'),
                      selected: freeReturns,
                      onSelected: (value) =>
                          setDialogState(() => freeReturns = value),
                    ),
                    FilterChip(
                      label: const Text('COD'),
                      selected: cashOnDelivery,
                      onSelected: (value) =>
                          setDialogState(() => cashOnDelivery = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final images = _parseLines(imagesController.text);
                final sizes = _parseCsvList(sizesController.text);
                final sizeStocks = _parseVariantSizeStocks(
                  sizeStocksController.text,
                );
                final parsedPrice = double.tryParse(
                  priceController.text.trim(),
                );
                final parsedDiscount = double.tryParse(
                  discountController.text.trim(),
                );
                final parsedStock =
                    int.tryParse(stockController.text.trim()) ?? 0;
                Navigator.pop(
                  dialogContext,
                  ProductColorVariant(
                    variantId: initial?.variantId ?? '',
                    productId: initial?.productId ?? '',
                    name: name,
                    colorName: name,
                    hex: hexController.text.trim().isEmpty
                        ? '#C6A769'
                        : hexController.text.trim(),
                    imageUrl: thumbnailController.text.trim(),
                    sku: skuController.text.trim(),
                    barcode: barcodeController.text.trim(),
                    price: parsedPrice,
                    discountPrice: parsedDiscount,
                    stock: parsedStock,
                    status: active ? 'active' : 'inactive',
                    thumbnail: thumbnailController.text.trim(),
                    images: images,
                    sizes: sizes,
                    sizeStocks: sizeStocks,
                    deliveryInfo: {
                      'sameDayEligible': sameDayEligible,
                      'freeReturns': freeReturns,
                      'cashOnDelivery': cashOnDelivery,
                      'etaLabel': etaController.text.trim(),
                    },
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    hexController.dispose();
    skuController.dispose();
    barcodeController.dispose();
    priceController.dispose();
    discountController.dispose();
    stockController.dispose();
    thumbnailController.dispose();
    imagesController.dispose();
    sizesController.dispose();
    sizeStocksController.dispose();
    etaController.dispose();

    return result;
  }

  Future<void> _addColorVariant() async {
    final variant = await _openColorVariantEditor();
    if (variant == null) return;
    setState(() {
      _colorVariantDrafts.add(variant);
      _syncColorVariantController();
    });
  }

  Future<void> _editColorVariant(int index, {bool duplicate = false}) async {
    if (index < 0 || index >= _colorVariantDrafts.length) return;
    final variant = await _openColorVariantEditor(
      initial: _colorVariantDrafts[index],
      duplicate: duplicate,
    );
    if (variant == null) return;
    setState(() {
      if (duplicate) {
        _colorVariantDrafts.insert(index + 1, variant);
      } else {
        _colorVariantDrafts[index] = variant;
      }
      _syncColorVariantController();
    });
  }

  void _deleteColorVariant(int index) {
    if (index < 0 || index >= _colorVariantDrafts.length) return;
    setState(() {
      _colorVariantDrafts.removeAt(index);
      _syncColorVariantController();
    });
  }

  void _reorderColorVariant(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _colorVariantDrafts.removeAt(oldIndex);
      _colorVariantDrafts.insert(newIndex, item);
      _syncColorVariantController();
    });
  }

  List<String> _parseIdList(String raw) {
    return raw
        .split(RegExp(r'[,\n\r]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String get _resolvedAttributeCategory {
    final subcategory = normalizeProductCategory(_subcategoryController.text);
    if (productAttributeConfig.containsKey(subcategory)) {
      return subcategory;
    }
    switch (_selectedCategory.toUpperCase()) {
      case 'SHOES':
      case 'FOOTWEAR':
        return 'footwear';
      case 'MEN':
      case 'WOMEN':
      case 'WEDDING':
      case 'FORMAL':
        return 'clothing';
      case 'SHIRT':
        return 'shirt';
      case 'T-SHIRT':
        return 'tshirt';
      case 'JEANS':
        return 'jeans';
      case 'TROUSERS':
        return 'trousers';
      case 'DRESS':
        return 'dress';
      case 'WATCH':
        return 'watch';
      case 'SUNGLASSES':
        return 'sunglasses';
      case 'BAG':
        return 'bag';
      case 'JEWELLERY':
        return 'jewellery';
      case 'PERFUME':
        return 'perfume';
      case 'BEAUTY':
        return 'beauty';
      case 'HOME & LIVING':
        return 'home_living';
      case 'ELECTRONICS':
        return 'electronics';
      case 'ACCESSORIES':
        return 'accessories';
      default:
        final normalized = normalizeProductCategory(_selectedCategory);
        return productAttributeConfig.containsKey(normalized) ? normalized : '';
    }
  }

  List<ProductAttributeSectionConfig> get _attributeSections {
    final config = productAttributeConfig[_resolvedAttributeCategory];
    if (config != null) {
      return config.sections;
    }
    return const [
      ProductAttributeSectionConfig(
        title: 'Product Details',
        fields: genericAttributeFields,
      ),
    ];
  }

  String get _subcategoryHint {
    switch (_selectedCategory.toUpperCase()) {
      case 'SHOES':
        return 'Running shoes, sneakers, loafers';
      case 'ACCESSORIES':
        return 'Watch, handbag, backpack';
      default:
        return 'Shirt, dress, kurta, blazer';
    }
  }

  String get _attributeHelperText {
    final resolved = _resolvedAttributeCategory;
    if (resolved.isEmpty) {
      return 'Add a specific product type to unlock category-based specifications.';
    }
    return 'Showing ${resolved.toUpperCase()} specifications based on category and subcategory.';
  }

  String _arRuntimeBundleHelperText() {
    final value = _assetBundleUrlController.text.trim();
    if (value.isEmpty) {
      return 'Optional: add only if you have a true AR asset bundle URL.';
    }
    if (_looksLikeModelFileUrl(value)) {
      return 'GLB/GLTF detected here. It will be ignored. Use the 3D Model field.';
    }
    if (!_isValidHttpUrl(value)) {
      return 'Invalid asset bundle URL. It will be ignored on save.';
    }
    return 'Valid asset bundle URL detected.';
  }

  Map<String, String> _collectAttributes() {
    final keys = {for (final section in _attributeSections) ...section.fields};
    final attributes = <String, String>{};
    for (final key in keys) {
      final value = _attributeControllers[key]?.text.trim() ?? '';
      if (value.isNotEmpty) {
        attributes[key] = value;
      }
    }
    return attributes;
  }

  ProductAttributeFieldConfig _fieldConfig(String key) {
    final template = getProductAttributeTemplate(
      _selectedCategory,
      _subcategoryController.text,
    );
    return template.fields[key] ??
        ProductAttributeFieldConfig(
          key: key,
          label: humanizeAttributeLabel(key),
          type: ProductAttributeFieldType.text,
        );
  }

  void _setAttributeValue(String key, String value) {
    final controller = _attributeControllers[key];
    if (controller == null) {
      return;
    }
    if (controller.text == value) {
      return;
    }
    controller.text = value;
    setState(() {});
  }

  Widget _buildAttributeInput(String field) {
    final config = _fieldConfig(field);
    final controller = _attributeControllers[field]!;
    final hint = _attributeHints[field] ?? humanizeAttributeLabel(field);
    switch (config.type) {
      case ProductAttributeFieldType.boolean:
        final selected =
            controller.text.trim().toLowerCase() == 'true' ||
            controller.text.trim().toLowerCase() == 'yes';
        return SwitchListTile(
          value: selected,
          contentPadding: EdgeInsets.zero,
          title: Text(
            config.label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: config.required
              ? Text(
                  'Required',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AbzioTheme.grey500,
                  ),
                )
              : null,
          secondary: config.readOnly
              ? const Icon(Icons.lock_outline_rounded, size: 18)
              : null,
          onChanged: config.readOnly
              ? null
              : (value) => _setAttributeValue(field, value ? 'Yes' : 'No'),
        );
      case ProductAttributeFieldType.dropdown:
        final value = controller.text.trim();
        return DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          decoration: InputDecoration(labelText: config.label, hintText: hint),
          items: config.options
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(),
          onChanged: config.readOnly
              ? null
              : (value) => _setAttributeValue(field, value ?? ''),
        );
      case ProductAttributeFieldType.number:
      case ProductAttributeFieldType.dimension:
        return TextField(
          controller: controller,
          enabled: !config.readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: config.unit.isNotEmpty ? '$hint (${config.unit})' : hint,
            labelText: config.label,
          ),
        );
      case ProductAttributeFieldType.multiSelect:
      case ProductAttributeFieldType.color:
      case ProductAttributeFieldType.size:
      case ProductAttributeFieldType.image:
      case ProductAttributeFieldType.specification:
      case ProductAttributeFieldType.text:
        return TextField(
          controller: controller,
          enabled: !config.readOnly,
          maxLines: config.type == ProductAttributeFieldType.specification
              ? 3
              : 1,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          decoration: InputDecoration(hintText: hint, labelText: config.label),
        );
    }
  }

  Widget _buildAttributeEditor() {
    final sections = _attributeSections;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AbzioTheme.grey100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Specifications',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'These details power the correct specs on customer product pages.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AbzioTheme.grey500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) const SizedBox(height: 18),
            Text(
              sections[index].title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            for (final field in sections[index].fields) ...[
              _buildAttributeInput(field),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumCommerceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9DECB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Commerce Content',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Controls the boutique PDP details shown to shoppers.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AbzioTheme.grey500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _boutiqueNameController,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Boutique name override',
                    labelText: 'Boutique Name',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _boutiqueLogoController,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Boutique logo URL',
                    labelText: 'Boutique Logo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _boutiqueVerified,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Verified boutique badge',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            onChanged: (value) => setState(() => _boutiqueVerified = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _highlightsController,
            maxLines: 3,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Pure Cotton\nSlim Fit\nBreathable',
              labelText: 'Product Highlights',
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Color Variants',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addColorVariant,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Variant'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_colorVariantDrafts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF7EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEADFC8)),
              ),
              child: Text(
                'Add colors like Black, Brown, or Grey. Each color can carry its own images, sizes, stock, and optional pricing.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AbzioTheme.grey500,
                  height: 1.45,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _colorVariantDrafts.length,
              buildDefaultDragHandles: false,
              onReorderItem: _reorderColorVariant,
              itemBuilder: (context, index) {
                final variant = _colorVariantDrafts[index];
                final stock = variant.stock;
                final status = variant.status == 'active'
                    ? 'Active'
                    : 'Inactive';
                final previewUrl = variant.thumbnail.isNotEmpty
                    ? variant.thumbnail
                    : (variant.images.isNotEmpty ? variant.images.first : '');
                return Container(
                  key: ValueKey('${variant.name}-$index'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DECB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F1E5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.drag_indicator_rounded,
                            color: Color(0xFF8B7A5B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: previewUrl.isNotEmpty
                              ? Image.network(previewUrl, fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFFF3EEE4),
                                  child: const Icon(
                                    Icons.palette_outlined,
                                    color: Color(0xFFC6A769),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              variant.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SKU: ${variant.sku.isNotEmpty ? variant.sku : 'Auto'} • Stock: $stock • $status',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AbzioTheme.grey500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _miniPill(
                                  'Images ${variant.images.length + (variant.thumbnail.isNotEmpty ? 1 : 0)}',
                                ),
                                _miniPill('Sizes ${variant.sizes.length}'),
                                _miniPill(variant.hex.toUpperCase()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () => _editColorVariant(index),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit variant',
                          ),
                          IconButton(
                            onPressed: () =>
                                _editColorVariant(index, duplicate: true),
                            icon: const Icon(Icons.copy_outlined),
                            tooltip: 'Duplicate variant',
                          ),
                          IconButton(
                            onPressed: () => _deleteColorVariant(index),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Delete variant',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deliveryEtaController,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Same-day delivery',
                    labelText: 'Delivery ETA',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _deliveryCountdownController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: '180',
                    labelText: 'Countdown Minutes',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Same Day'),
                selected: _sameDayEligible,
                onSelected: (value) => setState(() => _sameDayEligible = value),
              ),
              FilterChip(
                label: const Text('Try At Home'),
                selected: _tryAtHomeEligible,
                onSelected: (value) =>
                    setState(() => _tryAtHomeEligible = value),
              ),
              FilterChip(
                label: const Text('Try On'),
                selected: _tryOnAvailable,
                onSelected: (value) => setState(() => _tryOnAvailable = value),
              ),
              FilterChip(
                label: const Text('COD'),
                selected: _cashOnDelivery,
                onSelected: (value) => setState(() => _cashOnDelivery = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specificationsController,
            maxLines: 5,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText:
                  'Material: Cotton\nFabric: Premium Weave\nFit: Slim\nOccasion: Casual',
              labelText: 'Product Specifications',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _socialProofController,
            maxLines: 4,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText:
                  'viewers_today: 23\norders_this_week: 12\nwishlist_count: 78',
              labelText: 'Social Proof Metrics',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _completeLookController,
            maxLines: 2,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'product-id-1, product-id-2',
              labelText: 'Complete The Look Product IDs',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDiscountPreview() {
    final sellingPrice = double.tryParse(_priceController.text.trim());
    final originalPrice = double.tryParse(_originalPriceController.text.trim());
    final hasValidPrices =
        sellingPrice != null &&
        sellingPrice > 0 &&
        originalPrice != null &&
        originalPrice > 0;
    final safeSellingPrice = sellingPrice ?? 0;
    final safeOriginalPrice = originalPrice ?? 0;
    final discountPercent =
        hasValidPrices && safeOriginalPrice > safeSellingPrice
        ? (((safeOriginalPrice - safeSellingPrice) / safeOriginalPrice) * 100)
              .round()
        : 0;

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DDCA)),
      ),
      child: Row(
        children: [
          Text(
            'Live discount preview',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111111),
            ),
          ),
          const Spacer(),
          Text(
            hasValidPrices
                ? '${formatter.format(safeSellingPrice)}  ${formatter.format(safeOriginalPrice)}  $discountPercent% OFF'
                : 'Enter both prices to preview discount',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasValidPrices
                  ? const Color(0xFF111111)
                  : AbzioTheme.grey500,
            ),
          ),
        ],
      ),
    );
  }
}
