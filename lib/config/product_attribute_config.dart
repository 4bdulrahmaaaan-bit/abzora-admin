enum ProductAttributeFieldType {
  text,
  number,
  dropdown,
  boolean,
  multiSelect,
  image,
  color,
  size,
  dimension,
  specification,
}

class ProductAttributeFieldConfig {
  const ProductAttributeFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.readOnly = false,
    this.filterable = true,
    this.variantSupport = false,
    this.unit = '',
    this.options = const [],
  });

  final String key;
  final String label;
  final ProductAttributeFieldType type;
  final bool required;
  final bool readOnly;
  final bool filterable;
  final bool variantSupport;
  final String unit;
  final List<String> options;
}

class ProductAttributeSectionConfig {
  const ProductAttributeSectionConfig({
    required this.title,
    required this.fields,
  });

  final String title;
  final List<String> fields;
}

class ProductAttributeCategoryConfig {
  const ProductAttributeCategoryConfig({required this.sections});

  final List<ProductAttributeSectionConfig> sections;
}

class ProductAttributeTemplateConfig {
  const ProductAttributeTemplateConfig({
    required this.key,
    required this.label,
    required this.sections,
    required this.fields,
    this.version = 1,
  });

  final String key;
  final String label;
  final List<ProductAttributeSectionConfig> sections;
  final Map<String, ProductAttributeFieldConfig> fields;
  final int version;
}

const genericAttributeFields = [
  'brand',
  'material',
  'fit',
  'usage',
  'occasion',
  'color',
];

const _genderOptions = ['Men', 'Women', 'Unisex', 'Kids'];
const _fitOptions = ['Slim', 'Regular', 'Relaxed', 'Oversized', 'Athletic'];
const _occasionOptions = [
  'Casual',
  'Formal',
  'Office',
  'Party',
  'Wedding',
  'Travel',
  'Sport',
  'Daily Wear',
];
const _stretchOptions = ['None', 'Low', 'Medium', 'High'];
const _transparencyOptions = ['Opaque', 'Sheer', 'Semi-sheer'];
const _breathabilityOptions = ['Low', 'Medium', 'High'];
const _riseOptions = ['Low', 'Mid', 'High'];
const _closureOptions = [
  'Button',
  'Zip',
  'Slip-on',
  'Lace-up',
  'Buckle',
  'Velcro',
  'Drawstring',
  'Toggle',
];
const _toeOptions = ['Round', 'Square', 'Pointed', 'Almond'];
const _neckOptions = [
  'Round Neck',
  'V Neck',
  'Polo',
  'Crew Neck',
  'Mandarin Collar',
  'Henley',
  'Boat Neck',
];
const _sleeveOptions = [
  'Short Sleeve',
  'Half Sleeve',
  'Full Sleeve',
  'Sleeveless',
  'Three Quarter Sleeve',
];
const _collarOptions = [
  'Spread',
  'Button Down',
  'Mandarin',
  'Cutaway',
  'Classic',
];
const _movementOptions = ['Quartz', 'Automatic', 'Mechanical', 'Digital'];
const _displayOptions = ['Analog', 'Digital', 'Hybrid'];
const _frameShapeOptions = [
  'Round',
  'Square',
  'Aviator',
  'Cat Eye',
  'Wayfarer',
];
const _lensTypeOptions = [
  'Single Vision',
  'Gradient',
  'Mirrored',
  'Photochromic',
];
const _waterResistanceOptions = [
  'Splash Resistant',
  '30m',
  '50m',
  '100m',
  '200m',
];
const _warrantyOptions = ['6 Months', '1 Year', '2 Years', '3 Years'];
const _concentrationOptions = ['EDT', 'EDP', 'Parfum', 'Body Mist'];
const _longevityOptions = [
  'Light',
  'Moderate',
  'Long Lasting',
  'Very Long Lasting',
];
const _skinOptions = [
  'Dry',
  'Oily',
  'Combination',
  'Sensitive',
  'All Skin Types',
];
const _hairOptions = ['Straight', 'Wavy', 'Curly', 'Coily', 'All Hair Types'];
const _roomOptions = [
  'Living Room',
  'Bedroom',
  'Kitchen',
  'Dining Room',
  'Bathroom',
  'Outdoor',
];
const _frameMaterialOptions = [
  'Acetate',
  'Metal',
  'Plastic',
  'Titanium',
  'TR90',
];
const _lensMaterialOptions = ['Polycarbonate', 'Glass', 'CR-39', 'Nylon'];
const _caseMaterialOptions = [
  'Stainless Steel',
  'Titanium',
  'Aluminium',
  'Ceramic',
  'Plastic',
];
const _glassOptions = ['Mineral', 'Sapphire', 'Hardened Glass', 'Acrylic'];
const _batteryOptions = ['Battery', 'Rechargeable', 'Solar'];
const _fragranceFamilyOptions = [
  'Floral',
  'Woody',
  'Oriental',
  'Fresh',
  'Citrus',
  'Gourmand',
  'Aquatic',
];
const _brandlessOptions = [
  'Solid',
  'Striped',
  'Checked',
  'Printed',
  'Textured',
  'Self Design',
];

const productAttributeTemplates = <String, ProductAttributeTemplateConfig>{
  'footwear': ProductAttributeTemplateConfig(
    key: 'footwear',
    label: 'Footwear',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'gender',
          'category',
          'subcategory',
          'occasion',
          'color',
          'country_of_origin',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Build & Comfort',
        fields: [
          'size_chart',
          'available_sizes',
          'upper_material',
          'sole_material',
          'insole_material',
          'closure_type',
          'heel_height',
          'toe_shape',
          'arch_support',
          'cushioning',
          'waterproof',
          'breathable',
          'weight',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'gender': ProductAttributeFieldConfig(
        key: 'gender',
        label: 'Gender',
        type: ProductAttributeFieldType.dropdown,
        required: true,
        options: _genderOptions,
      ),
      'category': ProductAttributeFieldConfig(
        key: 'category',
        label: 'Category',
        type: ProductAttributeFieldType.text,
        readOnly: true,
      ),
      'subcategory': ProductAttributeFieldConfig(
        key: 'subcategory',
        label: 'Subcategory',
        type: ProductAttributeFieldType.text,
      ),
      'size_chart': ProductAttributeFieldConfig(
        key: 'size_chart',
        label: 'Size Chart',
        type: ProductAttributeFieldType.image,
      ),
      'available_sizes': ProductAttributeFieldConfig(
        key: 'available_sizes',
        label: 'Available Sizes',
        type: ProductAttributeFieldType.size,
        required: true,
        variantSupport: true,
      ),
      'upper_material': ProductAttributeFieldConfig(
        key: 'upper_material',
        label: 'Upper Material',
        type: ProductAttributeFieldType.dropdown,
        options: ['Leather', 'Mesh', 'Canvas', 'Synthetic', 'Suede', 'Knit'],
      ),
      'sole_material': ProductAttributeFieldConfig(
        key: 'sole_material',
        label: 'Sole Material',
        type: ProductAttributeFieldType.dropdown,
        options: ['Rubber', 'EVA', 'TPU', 'Leather', 'Phylon'],
      ),
      'insole_material': ProductAttributeFieldConfig(
        key: 'insole_material',
        label: 'Insole Material',
        type: ProductAttributeFieldType.dropdown,
        options: ['Foam', 'Memory Foam', 'Leather', 'EVA', 'PU'],
      ),
      'closure_type': ProductAttributeFieldConfig(
        key: 'closure_type',
        label: 'Closure Type',
        type: ProductAttributeFieldType.dropdown,
        options: _closureOptions,
      ),
      'heel_height': ProductAttributeFieldConfig(
        key: 'heel_height',
        label: 'Heel Height',
        type: ProductAttributeFieldType.dimension,
        unit: 'cm',
      ),
      'toe_shape': ProductAttributeFieldConfig(
        key: 'toe_shape',
        label: 'Toe Shape',
        type: ProductAttributeFieldType.dropdown,
        options: _toeOptions,
      ),
      'arch_support': ProductAttributeFieldConfig(
        key: 'arch_support',
        label: 'Arch Support',
        type: ProductAttributeFieldType.boolean,
      ),
      'cushioning': ProductAttributeFieldConfig(
        key: 'cushioning',
        label: 'Cushioning',
        type: ProductAttributeFieldType.dropdown,
        options: ['None', 'Low', 'Medium', 'High', 'Responsive'],
      ),
      'waterproof': ProductAttributeFieldConfig(
        key: 'waterproof',
        label: 'Waterproof',
        type: ProductAttributeFieldType.boolean,
      ),
      'breathable': ProductAttributeFieldConfig(
        key: 'breathable',
        label: 'Breathable',
        type: ProductAttributeFieldType.boolean,
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'g',
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'country_of_origin': ProductAttributeFieldConfig(
        key: 'country_of_origin',
        label: 'Country of Origin',
        type: ProductAttributeFieldType.text,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'clothing': ProductAttributeTemplateConfig(
    key: 'clothing',
    label: 'Clothing',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'gender',
          'fabric',
          'fabric_composition',
          'fit',
          'pattern',
          'occasion',
          'color',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Construction',
        fields: [
          'collar_type',
          'sleeve_length',
          'sleeve_type',
          'neck_type',
          'stretch',
          'transparency',
          'breathability',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'gender': ProductAttributeFieldConfig(
        key: 'gender',
        label: 'Gender',
        type: ProductAttributeFieldType.dropdown,
        options: _genderOptions,
      ),
      'fabric': ProductAttributeFieldConfig(
        key: 'fabric',
        label: 'Fabric',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric_composition': ProductAttributeFieldConfig(
        key: 'fabric_composition',
        label: 'Fabric Composition',
        type: ProductAttributeFieldType.specification,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'pattern': ProductAttributeFieldConfig(
        key: 'pattern',
        label: 'Pattern',
        type: ProductAttributeFieldType.dropdown,
        options: [
          'Solid',
          'Striped',
          'Checked',
          'Printed',
          'Textured',
          'Self Design',
        ],
      ),
      'collar_type': ProductAttributeFieldConfig(
        key: 'collar_type',
        label: 'Collar Type',
        type: ProductAttributeFieldType.dropdown,
        options: _collarOptions,
      ),
      'sleeve_length': ProductAttributeFieldConfig(
        key: 'sleeve_length',
        label: 'Sleeve Length',
        type: ProductAttributeFieldType.dropdown,
        options: ['Short', 'Half', 'Three Quarter', 'Full'],
      ),
      'sleeve_type': ProductAttributeFieldConfig(
        key: 'sleeve_type',
        label: 'Sleeve Type',
        type: ProductAttributeFieldType.dropdown,
        options: _sleeveOptions,
      ),
      'neck_type': ProductAttributeFieldConfig(
        key: 'neck_type',
        label: 'Neck Type',
        type: ProductAttributeFieldType.dropdown,
        options: _neckOptions,
      ),
      'stretch': ProductAttributeFieldConfig(
        key: 'stretch',
        label: 'Stretch',
        type: ProductAttributeFieldType.dropdown,
        options: _stretchOptions,
      ),
      'transparency': ProductAttributeFieldConfig(
        key: 'transparency',
        label: 'Transparency',
        type: ProductAttributeFieldType.dropdown,
        options: _transparencyOptions,
      ),
      'breathability': ProductAttributeFieldConfig(
        key: 'breathability',
        label: 'Breathability',
        type: ProductAttributeFieldType.dropdown,
        options: _breathabilityOptions,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'accessories': ProductAttributeTemplateConfig(
    key: 'accessories',
    label: 'Accessories',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'material',
          'capacity',
          'closure_type',
          'strap_type',
          'occasion',
          'color',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Additional Details',
        fields: [
          'size_chart',
          'weight',
          'water_resistant',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'material': ProductAttributeFieldConfig(
        key: 'material',
        label: 'Material',
        type: ProductAttributeFieldType.text,
      ),
      'capacity': ProductAttributeFieldConfig(
        key: 'capacity',
        label: 'Capacity',
        type: ProductAttributeFieldType.dimension,
        unit: 'L',
      ),
      'closure_type': ProductAttributeFieldConfig(
        key: 'closure_type',
        label: 'Closure Type',
        type: ProductAttributeFieldType.dropdown,
        options: _closureOptions,
      ),
      'strap_type': ProductAttributeFieldConfig(
        key: 'strap_type',
        label: 'Strap Type',
        type: ProductAttributeFieldType.dropdown,
        options: [
          'Single Strap',
          'Dual Strap',
          'Top Handle',
          'Crossbody',
          'Shoulder Strap',
        ],
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'size_chart': ProductAttributeFieldConfig(
        key: 'size_chart',
        label: 'Size Chart',
        type: ProductAttributeFieldType.image,
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'g',
      ),
      'water_resistant': ProductAttributeFieldConfig(
        key: 'water_resistant',
        label: 'Water Resistant',
        type: ProductAttributeFieldType.boolean,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'shirt': ProductAttributeTemplateConfig(
    key: 'shirt',
    label: 'Shirt',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'gender',
          'fabric',
          'fabric_composition',
          'fit',
          'color',
          'occasion',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Construction',
        fields: [
          'collar_type',
          'sleeve_length',
          'pattern',
          'weave_type',
          'stretch',
          'transparency',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'gender': ProductAttributeFieldConfig(
        key: 'gender',
        label: 'Gender',
        type: ProductAttributeFieldType.dropdown,
        options: _genderOptions,
      ),
      'fabric': ProductAttributeFieldConfig(
        key: 'fabric',
        label: 'Fabric',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric_composition': ProductAttributeFieldConfig(
        key: 'fabric_composition',
        label: 'Fabric Composition',
        type: ProductAttributeFieldType.specification,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'collar_type': ProductAttributeFieldConfig(
        key: 'collar_type',
        label: 'Collar Type',
        type: ProductAttributeFieldType.dropdown,
        options: _collarOptions,
      ),
      'sleeve_length': ProductAttributeFieldConfig(
        key: 'sleeve_length',
        label: 'Sleeve Length',
        type: ProductAttributeFieldType.dropdown,
        options: ['Short', 'Half', 'Three Quarter', 'Full'],
      ),
      'pattern': ProductAttributeFieldConfig(
        key: 'pattern',
        label: 'Pattern',
        type: ProductAttributeFieldType.dropdown,
        options: _brandlessOptions,
      ),
      'weave_type': ProductAttributeFieldConfig(
        key: 'weave_type',
        label: 'Weave Type',
        type: ProductAttributeFieldType.text,
      ),
      'stretch': ProductAttributeFieldConfig(
        key: 'stretch',
        label: 'Stretch',
        type: ProductAttributeFieldType.dropdown,
        options: _stretchOptions,
      ),
      'transparency': ProductAttributeFieldConfig(
        key: 'transparency',
        label: 'Transparency',
        type: ProductAttributeFieldType.dropdown,
        options: _transparencyOptions,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'tshirt': ProductAttributeTemplateConfig(
    key: 'tshirt',
    label: 'T-Shirt',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'fabric',
          'fabric_composition',
          'fit',
          'neck_type',
          'sleeve_type',
          'pattern',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Comfort',
        fields: [
          'stretch',
          'breathability',
          'occasion',
          'color',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric': ProductAttributeFieldConfig(
        key: 'fabric',
        label: 'Fabric',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric_composition': ProductAttributeFieldConfig(
        key: 'fabric_composition',
        label: 'Fabric Composition',
        type: ProductAttributeFieldType.specification,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'neck_type': ProductAttributeFieldConfig(
        key: 'neck_type',
        label: 'Neck Type',
        type: ProductAttributeFieldType.dropdown,
        options: _neckOptions,
      ),
      'sleeve_type': ProductAttributeFieldConfig(
        key: 'sleeve_type',
        label: 'Sleeve Type',
        type: ProductAttributeFieldType.dropdown,
        options: _sleeveOptions,
      ),
      'pattern': ProductAttributeFieldConfig(
        key: 'pattern',
        label: 'Pattern',
        type: ProductAttributeFieldType.dropdown,
        options: [
          'Solid',
          'Printed',
          'Striped',
          'Graphic',
          'Typography',
          'Self Design',
        ],
      ),
      'stretch': ProductAttributeFieldConfig(
        key: 'stretch',
        label: 'Stretch',
        type: ProductAttributeFieldType.dropdown,
        options: _stretchOptions,
      ),
      'breathability': ProductAttributeFieldConfig(
        key: 'breathability',
        label: 'Breathability',
        type: ProductAttributeFieldType.dropdown,
        options: _breathabilityOptions,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'jeans': ProductAttributeTemplateConfig(
    key: 'jeans',
    label: 'Jeans',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'fabric',
          'fabric_composition',
          'fit',
          'rise',
          'length',
          'color',
          'occasion',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Construction',
        fields: [
          'stretch',
          'closure_type',
          'wash_type',
          'pocket_count',
          'distressed',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric': ProductAttributeFieldConfig(
        key: 'fabric',
        label: 'Fabric',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric_composition': ProductAttributeFieldConfig(
        key: 'fabric_composition',
        label: 'Fabric Composition',
        type: ProductAttributeFieldType.specification,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'rise': ProductAttributeFieldConfig(
        key: 'rise',
        label: 'Rise',
        type: ProductAttributeFieldType.dropdown,
        options: _riseOptions,
      ),
      'stretch': ProductAttributeFieldConfig(
        key: 'stretch',
        label: 'Stretch',
        type: ProductAttributeFieldType.dropdown,
        options: _stretchOptions,
      ),
      'closure_type': ProductAttributeFieldConfig(
        key: 'closure_type',
        label: 'Closure Type',
        type: ProductAttributeFieldType.dropdown,
        options: _closureOptions,
      ),
      'length': ProductAttributeFieldConfig(
        key: 'length',
        label: 'Length',
        type: ProductAttributeFieldType.dropdown,
        options: ['Cropped', 'Ankle Length', 'Regular', 'Long', 'Extra Long'],
      ),
      'wash_type': ProductAttributeFieldConfig(
        key: 'wash_type',
        label: 'Wash Type',
        type: ProductAttributeFieldType.dropdown,
        options: [
          'Rinse',
          'Light Wash',
          'Medium Wash',
          'Dark Wash',
          'Distressed',
        ],
      ),
      'pocket_count': ProductAttributeFieldConfig(
        key: 'pocket_count',
        label: 'Pocket Count',
        type: ProductAttributeFieldType.number,
      ),
      'distressed': ProductAttributeFieldConfig(
        key: 'distressed',
        label: 'Distressed',
        type: ProductAttributeFieldType.boolean,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'trousers': ProductAttributeTemplateConfig(
    key: 'trousers',
    label: 'Trousers',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: ['brand', 'fabric', 'fit', 'rise', 'length', 'occasion'],
      ),
      ProductAttributeSectionConfig(
        title: 'Construction',
        fields: [
          'closure_type',
          'pleated',
          'stretch',
          'color',
          'care_instructions',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric': ProductAttributeFieldConfig(
        key: 'fabric',
        label: 'Fabric',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'rise': ProductAttributeFieldConfig(
        key: 'rise',
        label: 'Rise',
        type: ProductAttributeFieldType.dropdown,
        options: _riseOptions,
      ),
      'closure_type': ProductAttributeFieldConfig(
        key: 'closure_type',
        label: 'Closure Type',
        type: ProductAttributeFieldType.dropdown,
        options: _closureOptions,
      ),
      'pleated': ProductAttributeFieldConfig(
        key: 'pleated',
        label: 'Pleated',
        type: ProductAttributeFieldType.boolean,
      ),
      'stretch': ProductAttributeFieldConfig(
        key: 'stretch',
        label: 'Stretch',
        type: ProductAttributeFieldType.dropdown,
        options: _stretchOptions,
      ),
      'length': ProductAttributeFieldConfig(
        key: 'length',
        label: 'Length',
        type: ProductAttributeFieldType.dropdown,
        options: ['Cropped', 'Ankle Length', 'Regular', 'Full Length'],
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'dress': ProductAttributeTemplateConfig(
    key: 'dress',
    label: 'Dress',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'fabric',
          'dress_length',
          'neck_type',
          'sleeve_type',
          'fit',
          'occasion',
          'color',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Finish',
        fields: ['lining', 'transparency', 'care_instructions'],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fabric': ProductAttributeFieldConfig(
        key: 'fabric',
        label: 'Fabric',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'dress_length': ProductAttributeFieldConfig(
        key: 'dress_length',
        label: 'Dress Length',
        type: ProductAttributeFieldType.dropdown,
        options: ['Mini', 'Midi', 'Maxi', 'Knee Length', 'Ankle Length'],
      ),
      'neck_type': ProductAttributeFieldConfig(
        key: 'neck_type',
        label: 'Neck Type',
        type: ProductAttributeFieldType.dropdown,
        options: _neckOptions,
      ),
      'sleeve_type': ProductAttributeFieldConfig(
        key: 'sleeve_type',
        label: 'Sleeve Type',
        type: ProductAttributeFieldType.dropdown,
        options: _sleeveOptions,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'lining': ProductAttributeFieldConfig(
        key: 'lining',
        label: 'Lining',
        type: ProductAttributeFieldType.boolean,
      ),
      'transparency': ProductAttributeFieldConfig(
        key: 'transparency',
        label: 'Transparency',
        type: ProductAttributeFieldType.dropdown,
        options: _transparencyOptions,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
    },
  ),
  'watch': ProductAttributeTemplateConfig(
    key: 'watch',
    label: 'Watch',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'dial_size',
          'dial_shape',
          'movement_type',
          'display_type',
          'country_of_origin',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Build',
        fields: [
          'strap_material',
          'strap_width',
          'case_material',
          'glass_type',
          'water_resistance',
          'battery_type',
          'warranty',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'dial_size': ProductAttributeFieldConfig(
        key: 'dial_size',
        label: 'Dial Size',
        type: ProductAttributeFieldType.dimension,
        unit: 'mm',
      ),
      'dial_shape': ProductAttributeFieldConfig(
        key: 'dial_shape',
        label: 'Dial Shape',
        type: ProductAttributeFieldType.dropdown,
        options: _frameShapeOptions,
      ),
      'movement_type': ProductAttributeFieldConfig(
        key: 'movement_type',
        label: 'Movement Type',
        type: ProductAttributeFieldType.dropdown,
        options: _movementOptions,
      ),
      'strap_material': ProductAttributeFieldConfig(
        key: 'strap_material',
        label: 'Strap Material',
        type: ProductAttributeFieldType.dropdown,
        options: ['Leather', 'Stainless Steel', 'Silicone', 'Nylon', 'Fabric'],
      ),
      'strap_width': ProductAttributeFieldConfig(
        key: 'strap_width',
        label: 'Strap Width',
        type: ProductAttributeFieldType.dimension,
        unit: 'mm',
      ),
      'case_material': ProductAttributeFieldConfig(
        key: 'case_material',
        label: 'Case Material',
        type: ProductAttributeFieldType.dropdown,
        options: _caseMaterialOptions,
      ),
      'glass_type': ProductAttributeFieldConfig(
        key: 'glass_type',
        label: 'Glass Type',
        type: ProductAttributeFieldType.dropdown,
        options: _glassOptions,
      ),
      'water_resistance': ProductAttributeFieldConfig(
        key: 'water_resistance',
        label: 'Water Resistance',
        type: ProductAttributeFieldType.dropdown,
        options: _waterResistanceOptions,
      ),
      'warranty': ProductAttributeFieldConfig(
        key: 'warranty',
        label: 'Warranty',
        type: ProductAttributeFieldType.dropdown,
        options: _warrantyOptions,
      ),
      'display_type': ProductAttributeFieldConfig(
        key: 'display_type',
        label: 'Display Type',
        type: ProductAttributeFieldType.dropdown,
        options: _displayOptions,
      ),
      'battery_type': ProductAttributeFieldConfig(
        key: 'battery_type',
        label: 'Battery Type',
        type: ProductAttributeFieldType.dropdown,
        options: _batteryOptions,
      ),
      'country_of_origin': ProductAttributeFieldConfig(
        key: 'country_of_origin',
        label: 'Country of Origin',
        type: ProductAttributeFieldType.text,
      ),
    },
  ),
  'sunglasses': ProductAttributeTemplateConfig(
    key: 'sunglasses',
    label: 'Sunglasses',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'frame_material',
          'frame_shape',
          'lens_material',
          'lens_type',
          'gender',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Protection',
        fields: ['uv_protection', 'polarized', 'weight', 'warranty'],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'frame_material': ProductAttributeFieldConfig(
        key: 'frame_material',
        label: 'Frame Material',
        type: ProductAttributeFieldType.dropdown,
        options: _frameMaterialOptions,
      ),
      'frame_shape': ProductAttributeFieldConfig(
        key: 'frame_shape',
        label: 'Frame Shape',
        type: ProductAttributeFieldType.dropdown,
        options: _frameShapeOptions,
      ),
      'lens_material': ProductAttributeFieldConfig(
        key: 'lens_material',
        label: 'Lens Material',
        type: ProductAttributeFieldType.dropdown,
        options: _lensMaterialOptions,
      ),
      'lens_type': ProductAttributeFieldConfig(
        key: 'lens_type',
        label: 'Lens Type',
        type: ProductAttributeFieldType.dropdown,
        options: _lensTypeOptions,
      ),
      'gender': ProductAttributeFieldConfig(
        key: 'gender',
        label: 'Gender',
        type: ProductAttributeFieldType.dropdown,
        options: _genderOptions,
      ),
      'uv_protection': ProductAttributeFieldConfig(
        key: 'uv_protection',
        label: 'UV Protection',
        type: ProductAttributeFieldType.boolean,
      ),
      'polarized': ProductAttributeFieldConfig(
        key: 'polarized',
        label: 'Polarized',
        type: ProductAttributeFieldType.boolean,
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'g',
      ),
      'warranty': ProductAttributeFieldConfig(
        key: 'warranty',
        label: 'Warranty',
        type: ProductAttributeFieldType.dropdown,
        options: _warrantyOptions,
      ),
    },
  ),
  'bag': ProductAttributeTemplateConfig(
    key: 'bag',
    label: 'Bag',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'material',
          'capacity',
          'closure_type',
          'strap_type',
          'occasion',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Functionality',
        fields: [
          'compartments',
          'laptop_compatible',
          'water_resistant',
          'weight',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'material': ProductAttributeFieldConfig(
        key: 'material',
        label: 'Material',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'capacity': ProductAttributeFieldConfig(
        key: 'capacity',
        label: 'Capacity',
        type: ProductAttributeFieldType.dimension,
        unit: 'L',
      ),
      'closure_type': ProductAttributeFieldConfig(
        key: 'closure_type',
        label: 'Closure Type',
        type: ProductAttributeFieldType.dropdown,
        options: _closureOptions,
      ),
      'strap_type': ProductAttributeFieldConfig(
        key: 'strap_type',
        label: 'Strap Type',
        type: ProductAttributeFieldType.dropdown,
        options: [
          'Single Strap',
          'Dual Strap',
          'Top Handle',
          'Crossbody',
          'Shoulder Strap',
        ],
      ),
      'compartments': ProductAttributeFieldConfig(
        key: 'compartments',
        label: 'Compartments',
        type: ProductAttributeFieldType.number,
      ),
      'laptop_compatible': ProductAttributeFieldConfig(
        key: 'laptop_compatible',
        label: 'Laptop Compatible',
        type: ProductAttributeFieldType.boolean,
      ),
      'water_resistant': ProductAttributeFieldConfig(
        key: 'water_resistant',
        label: 'Water Resistant',
        type: ProductAttributeFieldType.boolean,
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'g',
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
    },
  ),
  'jewellery': ProductAttributeTemplateConfig(
    key: 'jewellery',
    label: 'Jewellery',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'material',
          'metal_type',
          'stone_type',
          'purity',
          'finish',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Assurance',
        fields: ['weight', 'certification', 'occasion'],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'material': ProductAttributeFieldConfig(
        key: 'material',
        label: 'Material',
        type: ProductAttributeFieldType.text,
      ),
      'metal_type': ProductAttributeFieldConfig(
        key: 'metal_type',
        label: 'Metal Type',
        type: ProductAttributeFieldType.dropdown,
        options: [
          'Gold',
          'Silver',
          'Platinum',
          'Diamond',
          'Rose Gold',
          'Stainless Steel',
        ],
      ),
      'stone_type': ProductAttributeFieldConfig(
        key: 'stone_type',
        label: 'Stone Type',
        type: ProductAttributeFieldType.dropdown,
        options: ['Diamond', 'Pearl', 'Ruby', 'Emerald', 'Sapphire', 'None'],
      ),
      'purity': ProductAttributeFieldConfig(
        key: 'purity',
        label: 'Purity',
        type: ProductAttributeFieldType.text,
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'g',
      ),
      'finish': ProductAttributeFieldConfig(
        key: 'finish',
        label: 'Finish',
        type: ProductAttributeFieldType.dropdown,
        options: ['Glossy', 'Matte', 'Polished', 'Brushed'],
      ),
      'certification': ProductAttributeFieldConfig(
        key: 'certification',
        label: 'Certification',
        type: ProductAttributeFieldType.boolean,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
    },
  ),
  'perfume': ProductAttributeTemplateConfig(
    key: 'perfume',
    label: 'Perfume',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'fragrance_family',
          'concentration',
          'volume',
          'gender',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Notes',
        fields: [
          'top_notes',
          'middle_notes',
          'base_notes',
          'longevity',
          'usage',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'fragrance_family': ProductAttributeFieldConfig(
        key: 'fragrance_family',
        label: 'Fragrance Family',
        type: ProductAttributeFieldType.dropdown,
        options: _fragranceFamilyOptions,
      ),
      'top_notes': ProductAttributeFieldConfig(
        key: 'top_notes',
        label: 'Top Notes',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'middle_notes': ProductAttributeFieldConfig(
        key: 'middle_notes',
        label: 'Middle Notes',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'base_notes': ProductAttributeFieldConfig(
        key: 'base_notes',
        label: 'Base Notes',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'longevity': ProductAttributeFieldConfig(
        key: 'longevity',
        label: 'Longevity',
        type: ProductAttributeFieldType.dropdown,
        options: _longevityOptions,
      ),
      'concentration': ProductAttributeFieldConfig(
        key: 'concentration',
        label: 'Concentration',
        type: ProductAttributeFieldType.dropdown,
        options: _concentrationOptions,
      ),
      'volume': ProductAttributeFieldConfig(
        key: 'volume',
        label: 'Volume',
        type: ProductAttributeFieldType.dimension,
        unit: 'ml',
      ),
      'gender': ProductAttributeFieldConfig(
        key: 'gender',
        label: 'Gender',
        type: ProductAttributeFieldType.dropdown,
        options: _genderOptions,
      ),
      'usage': ProductAttributeFieldConfig(
        key: 'usage',
        label: 'Usage',
        type: ProductAttributeFieldType.dropdown,
        options: ['Daily Wear', 'Evening', 'Office', 'Party', 'Gift'],
      ),
    },
  ),
  'beauty': ProductAttributeTemplateConfig(
    key: 'beauty',
    label: 'Beauty',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'skin_type',
          'hair_type',
          'ingredients',
          'benefits',
          'volume',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Usage',
        fields: [
          'usage_instructions',
          'expiry_date',
          'shelf_life',
          'fragrance_family',
        ],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'skin_type': ProductAttributeFieldConfig(
        key: 'skin_type',
        label: 'Skin Type',
        type: ProductAttributeFieldType.dropdown,
        options: _skinOptions,
      ),
      'hair_type': ProductAttributeFieldConfig(
        key: 'hair_type',
        label: 'Hair Type',
        type: ProductAttributeFieldType.dropdown,
        options: _hairOptions,
      ),
      'ingredients': ProductAttributeFieldConfig(
        key: 'ingredients',
        label: 'Ingredients',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'benefits': ProductAttributeFieldConfig(
        key: 'benefits',
        label: 'Benefits',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'usage_instructions': ProductAttributeFieldConfig(
        key: 'usage_instructions',
        label: 'Usage Instructions',
        type: ProductAttributeFieldType.specification,
      ),
      'expiry_date': ProductAttributeFieldConfig(
        key: 'expiry_date',
        label: 'Expiry Date',
        type: ProductAttributeFieldType.text,
      ),
      'shelf_life': ProductAttributeFieldConfig(
        key: 'shelf_life',
        label: 'Shelf Life',
        type: ProductAttributeFieldType.text,
      ),
      'volume': ProductAttributeFieldConfig(
        key: 'volume',
        label: 'Volume',
        type: ProductAttributeFieldType.dimension,
        unit: 'ml',
      ),
      'fragrance_family': ProductAttributeFieldConfig(
        key: 'fragrance_family',
        label: 'Fragrance Family',
        type: ProductAttributeFieldType.dropdown,
        options: _fragranceFamilyOptions,
      ),
    },
  ),
  'home_living': ProductAttributeTemplateConfig(
    key: 'home_living',
    label: 'Home & Living',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'material',
          'dimensions',
          'weight',
          'room_type',
          'finish',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Care & Assembly',
        fields: ['assembly_required', 'warranty', 'care_instructions'],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'material': ProductAttributeFieldConfig(
        key: 'material',
        label: 'Material',
        type: ProductAttributeFieldType.text,
      ),
      'dimensions': ProductAttributeFieldConfig(
        key: 'dimensions',
        label: 'Dimensions',
        type: ProductAttributeFieldType.dimension,
        unit: 'cm',
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'kg',
      ),
      'assembly_required': ProductAttributeFieldConfig(
        key: 'assembly_required',
        label: 'Assembly Required',
        type: ProductAttributeFieldType.boolean,
      ),
      'warranty': ProductAttributeFieldConfig(
        key: 'warranty',
        label: 'Warranty',
        type: ProductAttributeFieldType.dropdown,
        options: _warrantyOptions,
      ),
      'care_instructions': ProductAttributeFieldConfig(
        key: 'care_instructions',
        label: 'Care Instructions',
        type: ProductAttributeFieldType.specification,
      ),
      'room_type': ProductAttributeFieldConfig(
        key: 'room_type',
        label: 'Room Type',
        type: ProductAttributeFieldType.dropdown,
        options: _roomOptions,
      ),
      'finish': ProductAttributeFieldConfig(
        key: 'finish',
        label: 'Finish',
        type: ProductAttributeFieldType.dropdown,
        options: ['Glossy', 'Matte', 'Textured', 'Polished', 'Natural'],
      ),
    },
  ),
  'electronics': ProductAttributeTemplateConfig(
    key: 'electronics',
    label: 'Electronics',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Core Details',
        fields: [
          'brand',
          'model_number',
          'specifications',
          'battery_capacity',
          'connectivity',
          'compatibility',
        ],
      ),
      ProductAttributeSectionConfig(
        title: 'Power & Assurance',
        fields: ['warranty', 'power_consumption', 'dimensions', 'weight'],
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
        required: true,
      ),
      'model_number': ProductAttributeFieldConfig(
        key: 'model_number',
        label: 'Model Number',
        type: ProductAttributeFieldType.text,
      ),
      'specifications': ProductAttributeFieldConfig(
        key: 'specifications',
        label: 'Specifications',
        type: ProductAttributeFieldType.specification,
      ),
      'battery_capacity': ProductAttributeFieldConfig(
        key: 'battery_capacity',
        label: 'Battery Capacity',
        type: ProductAttributeFieldType.dimension,
        unit: 'mAh',
      ),
      'connectivity': ProductAttributeFieldConfig(
        key: 'connectivity',
        label: 'Connectivity',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'compatibility': ProductAttributeFieldConfig(
        key: 'compatibility',
        label: 'Compatibility',
        type: ProductAttributeFieldType.multiSelect,
      ),
      'warranty': ProductAttributeFieldConfig(
        key: 'warranty',
        label: 'Warranty',
        type: ProductAttributeFieldType.dropdown,
        options: _warrantyOptions,
      ),
      'power_consumption': ProductAttributeFieldConfig(
        key: 'power_consumption',
        label: 'Power Consumption',
        type: ProductAttributeFieldType.dimension,
        unit: 'W',
      ),
      'dimensions': ProductAttributeFieldConfig(
        key: 'dimensions',
        label: 'Dimensions',
        type: ProductAttributeFieldType.dimension,
        unit: 'cm',
      ),
      'weight': ProductAttributeFieldConfig(
        key: 'weight',
        label: 'Weight',
        type: ProductAttributeFieldType.dimension,
        unit: 'g',
      ),
    },
  ),
  'generic': ProductAttributeTemplateConfig(
    key: 'generic',
    label: 'Generic',
    sections: [
      ProductAttributeSectionConfig(
        title: 'Product Details',
        fields: genericAttributeFields,
      ),
    ],
    fields: {
      'brand': ProductAttributeFieldConfig(
        key: 'brand',
        label: 'Brand',
        type: ProductAttributeFieldType.text,
      ),
      'material': ProductAttributeFieldConfig(
        key: 'material',
        label: 'Material',
        type: ProductAttributeFieldType.text,
      ),
      'fit': ProductAttributeFieldConfig(
        key: 'fit',
        label: 'Fit',
        type: ProductAttributeFieldType.dropdown,
        options: _fitOptions,
      ),
      'usage': ProductAttributeFieldConfig(
        key: 'usage',
        label: 'Usage',
        type: ProductAttributeFieldType.text,
      ),
      'occasion': ProductAttributeFieldConfig(
        key: 'occasion',
        label: 'Occasion',
        type: ProductAttributeFieldType.dropdown,
        options: _occasionOptions,
      ),
      'color': ProductAttributeFieldConfig(
        key: 'color',
        label: 'Color',
        type: ProductAttributeFieldType.color,
        variantSupport: true,
      ),
    },
  ),
};

final productAttributeConfig = <String, ProductAttributeCategoryConfig>{
  for (final entry in productAttributeTemplates.entries)
    entry.key: ProductAttributeCategoryConfig(sections: entry.value.sections),
};

final Map<String, ProductAttributeTemplateConfig> legacyTemplates =
    productAttributeTemplates;

String normalizeProductCategory(String category, [String subcategory = '']) {
  final text =
      '${category.trim().toLowerCase()} ${subcategory.trim().toLowerCase()}';
  if (text.isEmpty) {
    return 'generic';
  }
  if (text.contains('t-shirt') || text.contains('tee')) {
    return 'tshirt';
  }
  if (text.contains('shirt')) {
    return 'shirt';
  }
  if (text.contains('jean')) {
    return 'jeans';
  }
  if (text.contains('trouser') || text.contains('pant')) {
    return 'trousers';
  }
  if (text.contains('dress')) {
    return 'dress';
  }
  if (text.contains('watch')) {
    return 'watch';
  }
  if (text.contains('sunglass') || text.contains('eyewear')) {
    return 'sunglasses';
  }
  if (text.contains('bag') ||
      text.contains('backpack') ||
      text.contains('handbag')) {
    return 'bag';
  }
  if (text.contains('jewel') ||
      text.contains('ring') ||
      text.contains('necklace')) {
    return 'jewellery';
  }
  if (text.contains('perfume') || text.contains('fragrance')) {
    return 'perfume';
  }
  if (text.contains('beauty') ||
      text.contains('skincare') ||
      text.contains('makeup')) {
    return 'beauty';
  }
  if (text.contains('home') ||
      text.contains('decor') ||
      text.contains('furniture')) {
    return 'home_living';
  }
  if (text.contains('electronic') || text.contains('gadget')) {
    return 'electronics';
  }
  if (text.contains('men') ||
      text.contains('women') ||
      text.contains('wedding') ||
      text.contains('formal') ||
      text.contains('apparel') ||
      text.contains('fashion')) {
    return 'clothing';
  }
  if (text.contains('accessor') ||
      text.contains('wallet') ||
      text.contains('belt')) {
    return 'accessories';
  }
  if (text.contains('shoe') ||
      text.contains('sneaker') ||
      text.contains('boot') ||
      text.contains('sandal')) {
    return 'footwear';
  }
  for (final entry in productAttributeTemplates.entries) {
    if (entry.key == 'generic') continue;
    if (text.contains(entry.key.replaceAll('_', ' '))) {
      return entry.key;
    }
  }
  if (text.contains('kurta') ||
      text.contains('top') ||
      text.contains('jacket') ||
      text.contains('coat')) {
    return 'shirt';
  }
  return 'generic';
}

ProductAttributeTemplateConfig getProductAttributeTemplate(
  String category, [
  String subcategory = '',
]) {
  final normalized = normalizeProductCategory(category, subcategory);
  return productAttributeTemplates[normalized] ??
      productAttributeTemplates['generic']!;
}

List<ProductAttributeSectionConfig> getFilterableAttributeSections(
  String category, [
  String subcategory = '',
]) {
  final template = getProductAttributeTemplate(category, subcategory);
  return template.sections
      .map(
        (section) => ProductAttributeSectionConfig(
          title: section.title,
          fields: section.fields
              .where(
                (fieldKey) => template.fields[fieldKey]?.filterable ?? false,
              )
              .toList(),
        ),
      )
      .where((section) => section.fields.isNotEmpty)
      .toList();
}

List<ProductAttributeFieldConfig> getFilterableAttributesForCategory(
  String category, [
  String subcategory = '',
]) {
  final template = getProductAttributeTemplate(category, subcategory);
  return template.fields.values.where((field) => field.filterable).toList();
}

Set<String> getFilterableAttributeKeys(
  String category, [
  String subcategory = '',
]) {
  return getFilterableAttributesForCategory(
    category,
    subcategory,
  ).map((field) => field.key).toSet();
}

ProductAttributeFieldConfig? getProductAttributeField(
  String templateKey,
  String fieldKey,
) {
  final template =
      productAttributeTemplates[templateKey] ??
      productAttributeTemplates['generic']!;
  return template.fields[fieldKey];
}

String humanizeAttributeLabel(String key) {
  return key
      .split('_')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

