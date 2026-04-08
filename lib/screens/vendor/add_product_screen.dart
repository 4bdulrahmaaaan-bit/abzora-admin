import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../config/product_attribute_config.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/image_url_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';

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
  final _subcategoryController = TextEditingController();
  String _selectedCategory = 'MEN';
  bool _isActive = true;
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
      _subcategoryController.text = product.subcategory;
      _selectedCategory = product.category;
      _isActive = product.isActive;
      for (final entry in product.attributes.entries) {
        _attributeControllers[entry.key]?.text = entry.value;
      }
      if ((product.attributes['fabric'] ?? '').isEmpty &&
          (product.fabric ?? '').isNotEmpty) {
        _attributeControllers['fabric']?.text = product.fabric!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    _imageUrlsController.dispose();
    _model3dController.dispose();
    _subcategoryController.dispose();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
                hintText: 'Paste 4 to 5 public image URLs, one per line',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadProductImage,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('UPLOAD PRODUCT IMAGE'),
            ),
            const SizedBox(height: 10),
            Text(
              'Use 4 to 5 product images for the best slide experience. Cloudinary uploads save optimized image URLs, and you can still paste public image links when needed.',
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
              onChanged: (val) => setState(() => _selectedCategory = val!),
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

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Price (Rs)'),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
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
                      _buildLabel('Original Price'),
                      TextField(
                        controller: _originalPriceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: '2499'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

    setState(() => _isUploading = true);

    final existing = widget.existingProduct;
    final attributes = _collectAttributes();
    final product = Product(
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
      isCustomTailoring: existing?.isCustomTailoring ?? false,
      outfitType: existing?.outfitType,
      fabric: attributes['fabric'] ?? existing?.fabric,
      model3d: _model3dController.text.trim().isEmpty
          ? null
          : _model3dController.text.trim(),
      attributes: attributes,
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
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
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
            error
                    .toString()
                    .replaceFirst('Bad state: ', '')
                    .contains('Cloudinary')
                ? 'Cloudinary upload is not configured yet. Paste a public image URL instead.'
                : error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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

  String get _resolvedAttributeCategory {
    final subcategory = normalizeProductCategory(_subcategoryController.text);
    if (productAttributeConfig.containsKey(subcategory)) {
      return subcategory;
    }
    switch (_selectedCategory.toUpperCase()) {
      case 'SHOES':
        return 'shoes';
      case 'MEN':
      case 'WOMEN':
      case 'WEDDING':
      case 'FORMAL':
        return 'clothing';
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
              TextField(
                controller: _attributeControllers[field],
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText:
                      _attributeHints[field] ?? humanizeAttributeLabel(field),
                  labelText: humanizeAttributeLabel(field),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}
