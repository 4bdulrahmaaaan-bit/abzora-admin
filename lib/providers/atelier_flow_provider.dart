import 'package:flutter/foundation.dart';

import '../models/atelier_models.dart';
import '../models/banner_model.dart';
import '../services/database_service.dart';

enum AtelierStep {
  product,
  fabric,
  style,
  fit,
  measurement,
  review,
}

class AtelierFlowProvider extends ChangeNotifier {
  AtelierFlowProvider() {
    _loadInitial();
  }

  final DatabaseService _db = DatabaseService();

  bool _isLoading = true;
  String? _error;
  AtelierStep _step = AtelierStep.product;

  final int itemPrice = 4299;
  final int deliveryFee = 149;

  AtelierDesigner? _selectedDesigner;
  AtelierCategory? _selectedCategory;
  FabricOption? _selectedFabric;
  FitOption? _selectedFit;
  MeasurementOption? _selectedMeasurementOption;
  final Map<String, StyleOption> _styleSelections = <String, StyleOption>{};

  List<AtelierDesigner> designers = const <AtelierDesigner>[];
  List<AtelierCategory> categories = const <AtelierCategory>[];
  List<FabricOption> fabrics = const <FabricOption>[];
  List<StyleOptionGroup> styleGroups = const <StyleOptionGroup>[];
  List<FitOption> fitOptions = const <FitOption>[];
  List<MeasurementOption> measurementOptions = const <MeasurementOption>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  AtelierStep get step => _step;
  AtelierDesigner? get selectedDesigner => _selectedDesigner;
  AtelierCategory? get selectedCategory => _selectedCategory;
  FabricOption? get selectedFabric => _selectedFabric;
  FitOption? get selectedFit => _selectedFit;
  MeasurementOption? get selectedMeasurementOption => _selectedMeasurementOption;
  Map<String, StyleOption> get styleSelections => Map.unmodifiable(_styleSelections);

  String get productName => selectedCategory?.title ?? 'Tailored Signature Shirt';
  String get storeName => selectedDesigner?.name ?? 'Atelier Noir';
  String get productImageUrl {
    if (selectedCategory?.imageUrl.trim().isNotEmpty == true) {
      return selectedCategory!.imageUrl;
    }
    if (selectedDesigner?.bannerUrl.trim().isNotEmpty == true) {
      return selectedDesigner!.bannerUrl;
    }
    return '';
  }

  int get customizationPrice {
    final fabricDelta = _selectedFabric?.priceDelta ?? 0;
    final styleDelta = _styleSelections.values.fold<int>(
      0,
      (sum, option) => sum + option.priceDelta,
    );
    final fitDelta = _selectedFit?.priceDelta ?? 0;
    final measurementDelta = _selectedMeasurementOption?.priceDelta ?? 0;
    return fabricDelta + styleDelta + fitDelta + measurementDelta;
  }

  int get totalPrice => itemPrice + customizationPrice + deliveryFee;

  Future<void> _loadInitial() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    designers = const <AtelierDesigner>[
      AtelierDesigner(
        id: 'atelier-noir',
        name: 'Atelier Noir',
        city: 'Chennai',
        rating: 4.8,
        priceBand: 'Premium',
        tags: ['Luxury tailoring', '2-day dispatch'],
        bannerUrl:
            'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&w=1200&q=80',
      ),
      AtelierDesigner(
        id: 'house-of-arc',
        name: 'House of Arc',
        city: 'Chennai',
        rating: 4.7,
        priceBand: 'Premium',
        tags: ['Precision fit', 'Private fittings'],
        bannerUrl:
            'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
      ),
    ];
    categories = const <AtelierCategory>[
      AtelierCategory(
        id: 'signature-shirt',
        title: 'Signature Shirt',
        subtitle: 'Minimal structure',
        imageUrl:
            'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80',
      ),
      AtelierCategory(
        id: 'soft-blazer',
        title: 'Soft Blazer',
        subtitle: 'Clean evening form',
        imageUrl:
            'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=1200&q=80',
      ),
    ];
    fabrics = const <FabricOption>[
      FabricOption(
        id: 'italian-cotton',
        name: 'Italian Cotton',
        tags: ['Breathable', 'Soft touch'],
        description: 'Smooth weave with crisp structure for everyday polish.',
        priceDelta: 450,
        imageUrl:
            'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=900&q=80',
      ),
      FabricOption(
        id: 'silk-cotton',
        name: 'Silk Cotton',
        tags: ['Luminous', 'Fluid drape'],
        description: 'A refined blend with a soft glow for elevated dressing.',
        priceDelta: 850,
        imageUrl:
            'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
      ),
      FabricOption(
        id: 'linen-signature',
        name: 'Signature Linen',
        tags: ['Airy', 'Tailored'],
        description: 'Lightweight texture that keeps the silhouette relaxed and premium.',
        priceDelta: 650,
        imageUrl:
            'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=900&q=80',
      ),
      FabricOption(
        id: 'satin-stretch',
        name: 'Satin Stretch',
        tags: ['Sculpted', 'Comfort'],
        description: 'Soft stretch with a polished finish for a more evening-led look.',
        priceDelta: 950,
        imageUrl:
            'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=900&q=80',
      ),
    ];
    styleGroups = const <StyleOptionGroup>[
      StyleOptionGroup(
        id: 'collar',
        title: 'Collar Type',
        options: [
          StyleOption(id: 'spread', title: 'Spread'),
          StyleOption(id: 'band', title: 'Band', priceDelta: 80),
          StyleOption(id: 'cutaway', title: 'Cutaway', priceDelta: 120),
        ],
      ),
      StyleOptionGroup(
        id: 'sleeve',
        title: 'Sleeve Type',
        options: [
          StyleOption(id: 'full', title: 'Full Sleeve'),
          StyleOption(id: 'three-quarter', title: '3/4 Sleeve', priceDelta: 60),
          StyleOption(id: 'short', title: 'Short Sleeve'),
        ],
      ),
      StyleOptionGroup(
        id: 'length',
        title: 'Length',
        options: [
          StyleOption(id: 'regular', title: 'Regular'),
          StyleOption(id: 'cropped', title: 'Cropped', priceDelta: 90),
          StyleOption(id: 'longline', title: 'Longline', priceDelta: 140),
        ],
      ),
    ];
    fitOptions = const <FitOption>[
      FitOption(
        id: 'slim',
        label: 'Slim Fit',
        description: 'Sharper waist and shoulder shape.',
        iconKey: 'slim',
      ),
      FitOption(
        id: 'regular',
        label: 'Regular Fit',
        description: 'Balanced room with polished structure.',
        iconKey: 'regular',
      ),
      FitOption(
        id: 'relaxed',
        label: 'Relaxed Fit',
        description: 'Soft drape with more movement.',
        iconKey: 'relaxed',
      ),
    ];
    measurementOptions = const <MeasurementOption>[
      MeasurementOption(
        id: 'standard-size',
        title: 'Standard Size',
        description: 'Quickest route with atelier size matching.',
        iconKey: 'hanger',
      ),
      MeasurementOption(
        id: 'enter-measurements',
        title: 'Enter Measurements',
        description: 'Manual dimensions for a more exact first fit.',
        iconKey: 'ruler',
        priceDelta: 120,
      ),
      MeasurementOption(
        id: 'try-at-home-fit',
        title: 'Try at Home Fit',
        description: 'Try a fit sample before final tailoring.',
        iconKey: 'home',
        priceDelta: 199,
      ),
      MeasurementOption(
        id: 'schedule-home-visit',
        title: 'Schedule Home Visit',
        description: 'A stylist visits for guided measuring.',
        iconKey: 'calendar',
        priceDelta: 299,
      ),
    ];

    _selectedDesigner = designers.first;
    _selectedCategory = categories.first;
    _selectedFabric = fabrics.first;
    _selectedFit = fitOptions[1];
    _selectedMeasurementOption = measurementOptions.first;
    for (final group in styleGroups) {
      _styleSelections[group.id] = group.options.first;
    }

    await _applyAdminManagedAtelierImages();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _applyAdminManagedAtelierImages() async {
    try {
      final config = await _db.getHomeVisualConfig(adminView: false);
      final atelierVisuals = config.categoryVisuals.where((visual) {
        return visual.isActive && visual.tab.trim().toLowerCase() == 'atelier';
      }).toList();
      if (atelierVisuals.isEmpty) {
        return;
      }

      final designerImageByKey = <String, String>{};
      final categoryImageByKey = <String, String>{};
      for (final visual in atelierVisuals) {
        final key = _normalizedVisualKey(visual);
        if (key.isEmpty || visual.imageUrl.trim().isEmpty) {
          continue;
        }
        if (visual.icon.trim().toLowerCase() == 'designer') {
          designerImageByKey[key] = visual.imageUrl.trim();
        } else {
          categoryImageByKey[key] = visual.imageUrl.trim();
        }
      }

      designers = designers
          .map((designer) {
            final key = _normalizedKey(designer.id, designer.name);
            final imageUrl = designerImageByKey[key];
            if (imageUrl == null || imageUrl.isEmpty) {
              return designer;
            }
            return AtelierDesigner(
              id: designer.id,
              name: designer.name,
              city: designer.city,
              rating: designer.rating,
              priceBand: designer.priceBand,
              tags: designer.tags,
              bannerUrl: imageUrl,
            );
          })
          .toList(growable: false);

      categories = categories
          .map((category) {
            final key = _normalizedKey(category.id, category.title);
            final imageUrl = categoryImageByKey[key];
            if (imageUrl == null || imageUrl.isEmpty) {
              return category;
            }
            return AtelierCategory(
              id: category.id,
              title: category.title,
              subtitle: category.subtitle,
              imageUrl: imageUrl,
            );
          })
          .toList(growable: false);
    } catch (_) {
      // Fall back to bundled visuals if remote config is unavailable.
    }
  }

  String _normalizedVisualKey(HomeCategoryVisualModel visual) {
    final source = visual.label.trim().isNotEmpty ? visual.label : visual.id;
    return _normalizedKey(source, source);
  }

  String _normalizedKey(String primary, String fallback) {
    final raw = primary.trim().isNotEmpty ? primary : fallback;
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void selectDesigner(AtelierDesigner designer) {
    _selectedDesigner = designer;
    notifyListeners();
  }

  void selectCategory(AtelierCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void selectFabric(FabricOption fabric) {
    _selectedFabric = fabric;
    notifyListeners();
  }

  void selectStyle(String groupId, StyleOption option) {
    _styleSelections[groupId] = option;
    notifyListeners();
  }

  void selectFit(FitOption option) {
    _selectedFit = option;
    notifyListeners();
  }

  void selectMeasurementOption(MeasurementOption option) {
    _selectedMeasurementOption = option;
    notifyListeners();
  }

  void startCustomization() {
    _step = AtelierStep.fabric;
    notifyListeners();
  }

  void goToProduct() {
    _step = AtelierStep.product;
    notifyListeners();
  }

  void goToStep(AtelierStep step) {
    _step = step;
    notifyListeners();
  }

  void nextStep() {
    if (_step.index < AtelierStep.values.length - 1) {
      _step = AtelierStep.values[_step.index + 1];
      notifyListeners();
    }
  }

  void previousStep() {
    if (_step.index > AtelierStep.product.index) {
      _step = AtelierStep.values[_step.index - 1];
      notifyListeners();
    }
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
