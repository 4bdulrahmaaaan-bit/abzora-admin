import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../config/product_attribute_config.dart';

class ProductFormController extends ChangeNotifier {
  final String storeId;
  final Product? existingProduct;
  final formKey = GlobalKey<FormState>();

  // Basic Info
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  String selectedCategory = 'MEN';
  String selectedSubcategory = '';
  final collectionController = TextEditingController();

  // Pricing
  final mrpController = TextEditingController();
  final sellingPriceController = TextEditingController();
  bool taxIncluded = true;

  // Inventory
  final skuController = TextEditingController();
  final stockController = TextEditingController();
  final lowStockThresholdController = TextEditingController();
  final barcodeController = TextEditingController();

  // Media
  final List<String> imageUrls = [];

  // Dynamic Sizes & Stock
  final Map<String, int> sizeQuantities = {};

  // Variants
  final List<ProductColorVariant> colorVariants = [];

  // Details (Attributes)
  final descriptionController = TextEditingController();
  final Map<String, TextEditingController> attributeControllers = {};

  // Delivery Settings
  bool sameDayDelivery = true;
  bool cashOnDelivery = true;
  bool freeReturns = true;
  bool tryBeforeYouBuy = false;
  bool expressDelivery = false;
  String etaDropdown = '3–5 Days';

  // Advanced / AI Settings
  final glbModelController = TextEditingController();
  final assetBundleUrlController = TextEditingController();
  final rigProfileController = TextEditingController();
  final materialProfileController = TextEditingController();
  final avatarMappingController = TextEditingController();
  final physicsMetadataController = TextEditingController();
  final arMetadataController = TextEditingController();

  ProductStatus status = ProductStatus.draft;

  ProductFormController({required this.storeId, this.existingProduct}) {
    if (existingProduct != null) {
      _loadExistingProduct(existingProduct!);
    } else {
      _initDefaultAttributes();
    }
    
    // Listeners for live pricing updates
    mrpController.addListener(notifyListeners);
    sellingPriceController.addListener(notifyListeners);
  }

  void _initDefaultAttributes() {
    attributeControllers.clear();
    final template = getProductAttributeTemplate(selectedCategory, selectedSubcategory);
    for (final field in template.fields.keys) {
      attributeControllers[field] = TextEditingController();
    }
  }

  void updateCategory(String category) {
    selectedCategory = category;
    selectedSubcategory = ''; // Reset
    _initDefaultAttributes();
    
    // Auto-gen sizes based on config
    sizeQuantities.clear();
    final template = getProductAttributeTemplate(selectedCategory, selectedSubcategory);
    for (final size in template.sizes) {
      sizeQuantities[size] = 0;
    }
    notifyListeners();
  }

  void updateSubcategory(String subcategory) {
    selectedSubcategory = subcategory;
    _initDefaultAttributes();
    
    sizeQuantities.clear();
    final template = getProductAttributeTemplate(selectedCategory, selectedSubcategory);
    for (final size in template.sizes) {
      sizeQuantities[size] = 0;
    }
    notifyListeners();
  }

  void _loadExistingProduct(Product product) {
    nameController.text = product.name;
    brandController.text = product.brand;
    mrpController.text = product.originalPrice?.toStringAsFixed(0) ?? '';
    sellingPriceController.text = product.price.toStringAsFixed(0);
    skuController.text = product.id; // Just fallback
    stockController.text = product.stock.toString();
    imageUrls.addAll(product.images);
    colorVariants.addAll(product.colorVariants);
    descriptionController.text = product.description;
    
    selectedCategory = product.category;
    selectedSubcategory = product.subcategory;
    status = product.status;

    // Load sizes
    for (final size in product.sizes) {
      sizeQuantities[size] = product.stock; // Simplify
    }

    // Load AI Assets
    glbModelController.text = product.model3d ?? '';
    assetBundleUrlController.text = product.assetBundleUrl ?? '';
    rigProfileController.text = product.rigProfile ?? '';
    materialProfileController.text = product.materialProfile ?? '';

    _initDefaultAttributes();
    for (final attr in product.structuredAttributes) {
      final key = attr['key']?.toString() ?? '';
      if (attributeControllers.containsKey(key)) {
        attributeControllers[key]?.text = attr['value']?.toString() ?? '';
      }
    }
  }

  void toggleTaxIncluded(bool? value) {
    if (value != null) {
      taxIncluded = value;
      notifyListeners();
    }
  }

  void addImage(String url) {
    if (url.isNotEmpty) {
      imageUrls.add(url);
      notifyListeners();
    }
  }

  void removeImage(int index) {
    imageUrls.removeAt(index);
    notifyListeners();
  }

  void reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = imageUrls.removeAt(oldIndex);
    imageUrls.insert(newIndex, item);
    notifyListeners();
  }

  void markAsCover(int index) {
    if (index > 0 && index < imageUrls.length) {
      final item = imageUrls.removeAt(index);
      imageUrls.insert(0, item);
      notifyListeners();
    }
  }

  void generateSku() {
    final prefix = selectedCategory.isNotEmpty ? selectedCategory.substring(0, min(3, selectedCategory.length)).toUpperCase() : 'PRD';
    skuController.text = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    notifyListeners();
  }

  int min(int a, int b) => a < b ? a : b;

  double get discountPercentage {
    final mrp = double.tryParse(mrpController.text) ?? 0;
    final sell = double.tryParse(sellingPriceController.text) ?? 0;
    if (mrp <= 0 || sell <= 0 || sell >= mrp) return 0;
    return ((mrp - sell) / mrp) * 100;
  }

  double get amountSaved {
    final mrp = double.tryParse(mrpController.text) ?? 0;
    final sell = double.tryParse(sellingPriceController.text) ?? 0;
    if (mrp <= 0 || sell <= 0 || sell >= mrp) return 0;
    return mrp - sell;
  }

  int get totalStock {
    if (sizeQuantities.isEmpty) {
      return int.tryParse(stockController.text) ?? 0;
    }
    return sizeQuantities.values.fold(0, (sum, q) => sum + q);
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    collectionController.dispose();
    mrpController.dispose();
    sellingPriceController.dispose();
    skuController.dispose();
    stockController.dispose();
    lowStockThresholdController.dispose();
    barcodeController.dispose();
    descriptionController.dispose();
    for (final c in attributeControllers.values) {
      c.dispose();
    }
    glbModelController.dispose();
    assetBundleUrlController.dispose();
    rigProfileController.dispose();
    materialProfileController.dispose();
    avatarMappingController.dispose();
    physicsMetadataController.dispose();
    arMetadataController.dispose();
    super.dispose();
  }
}
