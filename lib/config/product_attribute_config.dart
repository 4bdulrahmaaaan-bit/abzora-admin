class ProductAttributeSectionConfig {
  const ProductAttributeSectionConfig({
    required this.title,
    required this.fields,
  });

  final String title;
  final List<String> fields;
}

class ProductAttributeCategoryConfig {
  const ProductAttributeCategoryConfig({
    required this.sections,
  });

  final List<ProductAttributeSectionConfig> sections;
}

const genericAttributeFields = ['material', 'usage', 'fit'];

const productAttributeConfig = <String, ProductAttributeCategoryConfig>{
  'shoes': ProductAttributeCategoryConfig(
    sections: [
      ProductAttributeSectionConfig(
        title: 'Material & Build',
        fields: ['upper_material', 'sole_material'],
      ),
      ProductAttributeSectionConfig(
        title: 'Performance',
        fields: ['closure', 'occasion', 'cushioning', 'fit_type'],
      ),
    ],
  ),
  'clothing': ProductAttributeCategoryConfig(
    sections: [
      ProductAttributeSectionConfig(
        title: 'Product Details',
        fields: ['fabric', 'fit', 'pattern', 'sleeve_type', 'occasion'],
      ),
    ],
  ),
  'watch': ProductAttributeCategoryConfig(
    sections: [
      ProductAttributeSectionConfig(
        title: 'Specifications',
        fields: ['dial_shape', 'strap_material', 'movement', 'water_resistance'],
      ),
    ],
  ),
  'bag': ProductAttributeCategoryConfig(
    sections: [
      ProductAttributeSectionConfig(
        title: 'Product Details',
        fields: ['material', 'capacity', 'closure', 'strap_type'],
      ),
    ],
  ),
};

String normalizeProductCategory(String category) {
  final normalized = category.trim().toLowerCase();
  if (['shoe', 'shoes', 'footwear', 'sneakers'].contains(normalized)) {
    return 'shoes';
  }
  if (['clothing', 'apparel', 'fashion', 'dress', 'shirt', 't-shirt', 'kurta'].contains(normalized)) {
    return 'clothing';
  }
  if (normalized == 'watches') {
    return 'watch';
  }
  if (['bags', 'handbags', 'backpacks'].contains(normalized)) {
    return 'bag';
  }
  return normalized;
}

String humanizeAttributeLabel(String key) {
  return key
      .split('_')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
