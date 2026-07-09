import '../../../services/app_config.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../config/product_attribute_config.dart';
import '../../../models/models.dart';

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

  final Map<String, dynamic> _vendorMeta = {};

  // Details (Attributes)
  final descriptionController = TextEditingController();
  final Map<String, TextEditingController> attributeControllers = {};

  // Delivery Settings
  bool sameDayDelivery = true;
  bool cashOnDelivery = true;
  bool freeReturns = true;
  bool tryBeforeYouBuy = false;
  bool expressDelivery = false;
  String etaDropdown = '3-5 Days';

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

    mrpController.addListener(notifyListeners);
    sellingPriceController.addListener(notifyListeners);
  }

  void _initDefaultAttributes() {
    attributeControllers.clear();
    final template = getProductAttributeTemplate(
      selectedCategory,
      selectedSubcategory,
    );
    for (final field in template.fields.keys) {
      attributeControllers[field] = TextEditingController();
    }
  }

  void updateCategory(String category) {
    selectedCategory = category;
    selectedSubcategory = '';
    _initDefaultAttributes();

    sizeQuantities.clear();
    final template = getProductAttributeTemplate(
      selectedCategory,
      selectedSubcategory,
    );
    for (final size in template.sizes) {
      sizeQuantities[size] = 0;
    }
    notifyListeners();
  }

  void updateSubcategory(String subcategory) {
    selectedSubcategory = subcategory;
    _initDefaultAttributes();

    sizeQuantities.clear();
    final template = getProductAttributeTemplate(
      selectedCategory,
      selectedSubcategory,
    );
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
    skuController.text = product.id;
    stockController.text = product.stock.toString();
    imageUrls.addAll(product.images);
    colorVariants.addAll(product.colorVariants);
    descriptionController.text = product.description;
    _vendorMeta
      ..clear()
      ..addAll(product.vendorMeta);

    selectedCategory = product.category;
    selectedSubcategory = product.subcategory;
    status = product.status;

    for (final size in product.sizes) {
      sizeQuantities[size] = product.stock;
    }

    glbModelController.text = product.model3d ?? '';
    assetBundleUrlController.text = product.assetBundleUrl ?? '';
    rigProfileController.text = product.rigProfile ?? '';
    materialProfileController.text = product.materialProfile ?? '';
    collectionController.text = _readVendorString(product, 'collection');
    barcodeController.text = _readVendorString(product, 'barcode');
    lowStockThresholdController.text = _readVendorString(
      product,
      'lowStockThreshold',
      fallback: '5',
    );
    taxIncluded = _readVendorBool(product, 'taxIncluded', fallback: true);
    sameDayDelivery = _readVendorBool(
      product,
      'sameDayDelivery',
      fallback: product.deliveryInfo['sameDayEligible'] == true,
    );
    cashOnDelivery = _readVendorBool(
      product,
      'cashOnDelivery',
      fallback: product.deliveryInfo['cashOnDelivery'] == true,
    );
    freeReturns = _readVendorBool(
      product,
      'freeReturns',
      fallback: product.deliveryInfo['freeReturns'] != false,
    );
    tryBeforeYouBuy = _readVendorBool(
      product,
      'tryBeforeYouBuy',
      fallback:
          product.deliveryInfo['supportsTryAtHome'] == true ||
          product.deliveryInfo['tryAtHomeEligible'] == true ||
          product.deliveryInfo['tryAtHomeAvailable'] == true ||
          product.deliveryInfo['tryBeforeYouBuy'] == true,
    );
    expressDelivery = _readVendorBool(
      product,
      'expressDelivery',
      fallback: false,
    );
    etaDropdown = _readVendorString(
      product,
      'etaLabel',
      fallback: product.deliveryInfo['etaLabel']?.toString().trim().isNotEmpty == true
          ? product.deliveryInfo['etaLabel'].toString().trim()
          : etaDropdown,
    );

    _initDefaultAttributes();
    for (final entry in product.attributes.entries) {
      final controller = attributeControllers[entry.key];
      if (controller != null) {
        controller.text = entry.value;
      }
    }
    for (final attr in product.structuredAttributes) {
      final key = attr['key']?.toString() ?? '';
      if (attributeControllers.containsKey(key)) {
        attributeControllers[key]?.text = attr['value']?.toString() ?? '';
      }
    }
    _restoreSizeQuantities(product);
  }

  void toggleTaxIncluded(bool? value) {
    if (value != null) {
      taxIncluded = value;
      notifyListeners();
    }
  }

  void toggleSameDayDelivery() {
    sameDayDelivery = !sameDayDelivery;
    if (sameDayDelivery && etaDropdown == '3-5 Days') {
      etaDropdown = 'Same Day';
    }
    notifyListeners();
  }

  void toggleCashOnDelivery() {
    cashOnDelivery = !cashOnDelivery;
    notifyListeners();
  }

  void toggleFreeReturns() {
    freeReturns = !freeReturns;
    notifyListeners();
  }

  void toggleTryBeforeYouBuy() {
    tryBeforeYouBuy = !tryBeforeYouBuy;
    if (tryBeforeYouBuy) {
      sameDayDelivery = true;
      etaDropdown = 'Same Day';
    }
    notifyListeners();
  }

  void toggleExpressDelivery() {
    expressDelivery = !expressDelivery;
    notifyListeners();
  }

  void updateEtaDropdown(String value) {
    etaDropdown = value;
    if (value.toLowerCase().contains('same')) {
      sameDayDelivery = true;
    }
    notifyListeners();
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

  Map<String, dynamic> buildVendorMeta() {
    final meta = Map<String, dynamic>.from(_vendorMeta);
    meta['collection'] = collectionController.text.trim();
    meta['barcode'] = barcodeController.text.trim();
    meta['lowStockThreshold'] =
        int.tryParse(lowStockThresholdController.text.trim()) ?? 5;
    meta['taxIncluded'] = taxIncluded;
    meta['sameDayDelivery'] = AppConfig.enableLocalRiderDelivery ? sameDayDelivery : false;
    meta['cashOnDelivery'] = cashOnDelivery;
    meta['freeReturns'] = freeReturns;
    meta['tryBeforeYouBuy'] = AppConfig.enableLocalRiderDelivery ? tryBeforeYouBuy : false;
    meta['expressDelivery'] = expressDelivery;
    meta['etaLabel'] = etaDropdown.trim();
    meta['sizeQuantities'] = jsonEncode(sizeQuantities);
    return meta;
  }

  void generateSku() {
    final prefix = selectedCategory.isNotEmpty
        ? selectedCategory.substring(0, min(3, selectedCategory.length)).toUpperCase()
        : 'PRD';
    skuController.text =
        '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
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

  void forceNotify() {
    notifyListeners();
  }

  String _readVendorString(
    Product product,
    String key, {
    String fallback = '',
  }) {
    final candidates = <dynamic>[
      product.vendorMeta[key],
      product.vendorMeta['vendor_$key'],
      product.attributes[key],
      product.attributes['vendor_$key'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  bool _readVendorBool(
    Product product,
    String key, {
    required bool fallback,
  }) {
    final candidates = <dynamic>[
      product.vendorMeta[key],
      product.vendorMeta['vendor_$key'],
      product.attributes[key],
      product.attributes['vendor_$key'],
    ];
    for (final candidate in candidates) {
      if (candidate is bool) {
        return candidate;
      }
      final value = candidate?.toString().trim().toLowerCase() ?? '';
      if (['true', '1', 'yes'].contains(value)) {
        return true;
      }
      if (['false', '0', 'no'].contains(value)) {
        return false;
      }
    }
    return fallback;
  }

  void _restoreSizeQuantities(Product product) {
    final raw = _readVendorString(
      product,
      'sizeQuantities',
      fallback: '',
    );
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          sizeQuantities
            ..clear()
            ..addEntries(
              decoded.entries
                  .map((entry) {
                    final key = entry.key.toString().trim();
                    final qty = entry.value is num
                        ? (entry.value as num).toInt()
                        : int.tryParse(entry.value?.toString() ?? '') ?? 0;
                    return MapEntry(key, qty);
                  })
                  .where((entry) => entry.key.isNotEmpty),
            );
        }
      } catch (_) {
        // Fall through to size-based defaults.
      }
    }

    if (sizeQuantities.isEmpty) {
      for (final size in product.sizes) {
        sizeQuantities[size] = product.stock;
      }
    }
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
