import 'package:flutter/foundation.dart';

import '../models/atelier_models.dart';
import '../models/banner_model.dart';
import '../services/database_service.dart';

enum AtelierStep {
  home,
  style,
  fabric,
  measurements,
  design,
  preview,
  summary,
}

class AtelierFlowProvider extends ChangeNotifier {
  AtelierFlowProvider() {
    _loadInitial();
  }

  final DatabaseService _db = DatabaseService();

  bool _isLoading = true;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  final int basePrice = 2499;
  AtelierStep _step = AtelierStep.home;

  AtelierDesigner? _selectedDesigner;
  AtelierCategory? _selectedCategory;
  FabricOption? _selectedFabric;
  MeasurementData _measurements = const MeasurementData();
  final Map<String, DesignOption> _designChoices = <String, DesignOption>{};

  List<AtelierDesigner> designers = const <AtelierDesigner>[];
  List<AtelierCategory> categories = const <AtelierCategory>[];
  List<FabricOption> fabrics = const <FabricOption>[];
  List<DesignOptionGroup> designGroups = const <DesignOptionGroup>[];

  AtelierStep get step => _step;
  AtelierDesigner? get selectedDesigner => _selectedDesigner;
  AtelierCategory? get selectedCategory => _selectedCategory;
  FabricOption? get selectedFabric => _selectedFabric;
  MeasurementData get measurements => _measurements;
  Map<String, DesignOption> get designChoices => Map.unmodifiable(_designChoices);

  int get totalPrice {
    final fabricDelta = _selectedFabric?.priceDelta ?? 0;
    final designDelta = _designChoices.values.fold<int>(
      0,
      (sum, option) => sum + option.priceDelta,
    );
    return basePrice + fabricDelta + designDelta;
  }

  Future<void> _loadInitial() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    designers = const <AtelierDesigner>[
      AtelierDesigner(
        id: 'atelier-noir',
        name: 'Atelier Noir',
        city: 'Hyderabad',
        rating: 4.8,
        priceBand: '₹₹₹₹',
        tags: ['Premium Atelier', 'Verified Designer'],
        bannerUrl:
            'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1000&q=80',
      ),
      AtelierDesigner(
        id: 'stitched-society',
        name: 'Stitched Society',
        city: 'Bengaluru',
        rating: 4.7,
        priceBand: '₹₹₹',
        tags: ['Express Fit', 'Luxury Tailoring'],
        bannerUrl:
            'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1000&q=80',
      ),
    ];
    categories = const <AtelierCategory>[
      AtelierCategory(
        id: 'formal-shirts',
        title: 'Formal Shirts',
        subtitle: 'Clean lines',
        imageUrl:
            'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?auto=format&fit=crop&w=1000&q=80',
      ),
      AtelierCategory(
        id: 'blazers',
        title: 'Blazers',
        subtitle: 'Structured elegance',
        imageUrl:
            'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1000&q=80',
      ),
      AtelierCategory(
        id: 'suits',
        title: 'Suits',
        subtitle: 'Ceremony ready',
        imageUrl:
            'https://images.unsplash.com/photo-1617127365659-c47fa864d8bc?auto=format&fit=crop&w=1000&q=80',
      ),
      AtelierCategory(
        id: 'kurtas',
        title: 'Kurtas',
        subtitle: 'Festive tailored',
        imageUrl:
            'https://images.unsplash.com/photo-1618886614638-80e3c103d31a?auto=format&fit=crop&w=1000&q=80',
      ),
      AtelierCategory(
        id: 'dresses',
        title: 'Dresses',
        subtitle: 'Soft structure',
        imageUrl:
            'https://images.unsplash.com/photo-1502716119720-b23a93e5fe1b?auto=format&fit=crop&w=1000&q=80',
      ),
      AtelierCategory(
        id: 'gowns',
        title: 'Gowns',
        subtitle: 'Evening couture',
        imageUrl:
            'https://images.unsplash.com/photo-1566174053879-31528523f8ae?auto=format&fit=crop&w=1000&q=80',
      ),
    ];
    fabrics = const <FabricOption>[
      FabricOption(
        id: 'egyptian-cotton',
        name: 'Egyptian Cotton',
        tags: ['Soft', 'Crisp', 'Luxurious'],
        description: 'Lightweight premium cotton with a refined sheen.',
        priceDelta: 650,
      ),
      FabricOption(
        id: 'italian-wool',
        name: 'Italian Wool',
        tags: ['Structured', 'Breathable', 'Premium'],
        description: 'All-season wool with elevated drape and polish.',
        priceDelta: 980,
      ),
      FabricOption(
        id: 'silk-blend',
        name: 'Silk Blend',
        tags: ['Smooth', 'Gloss', 'Lightweight'],
        description: 'A luxe blend for fluid silhouettes and shine.',
        priceDelta: 1200,
      ),
    ];
    designGroups = const <DesignOptionGroup>[
      DesignOptionGroup(
        id: 'collar',
        title: 'Collar Type',
        options: [
          DesignOption(
            id: 'spread',
            title: 'Spread',
            subtitle: 'Balanced formal spread',
            iconKey: 'collar',
            priceDelta: 0,
          ),
          DesignOption(
            id: 'cutaway',
            title: 'Cutaway',
            subtitle: 'Wide modern opening',
            iconKey: 'collar',
            priceDelta: 120,
          ),
          DesignOption(
            id: 'band',
            title: 'Band',
            subtitle: 'Minimal and sharp',
            iconKey: 'collar',
            priceDelta: 80,
          ),
        ],
      ),
      DesignOptionGroup(
        id: 'cuff',
        title: 'Cuff Style',
        options: [
          DesignOption(
            id: 'barrel',
            title: 'Barrel',
            subtitle: 'Classic everyday fit',
            iconKey: 'cuff',
            priceDelta: 0,
          ),
          DesignOption(
            id: 'french',
            title: 'French',
            subtitle: 'Luxury fold finish',
            iconKey: 'cuff',
            priceDelta: 180,
          ),
          DesignOption(
            id: 'round',
            title: 'Round',
            subtitle: 'Soft tailored curve',
            iconKey: 'cuff',
            priceDelta: 90,
          ),
        ],
      ),
      DesignOptionGroup(
        id: 'buttons',
        title: 'Buttons',
        options: [
          DesignOption(
            id: 'pearl',
            title: 'Mother of Pearl',
            subtitle: 'Luminous finish',
            iconKey: 'button',
            priceDelta: 210,
          ),
          DesignOption(
            id: 'matte',
            title: 'Matte Resin',
            subtitle: 'Minimal luxe',
            iconKey: 'button',
            priceDelta: 0,
          ),
          DesignOption(
            id: 'metal',
            title: 'Brushed Metal',
            subtitle: 'Statement edge',
            iconKey: 'button',
            priceDelta: 150,
          ),
        ],
      ),
      DesignOptionGroup(
        id: 'pocket',
        title: 'Pocket',
        options: [
          DesignOption(
            id: 'none',
            title: 'No Pocket',
            subtitle: 'Clean silhouette',
            iconKey: 'pocket',
            priceDelta: 0,
          ),
          DesignOption(
            id: 'single',
            title: 'Single',
            subtitle: 'Classic detail',
            iconKey: 'pocket',
            priceDelta: 80,
          ),
          DesignOption(
            id: 'hidden',
            title: 'Hidden',
            subtitle: 'Minimal utility',
            iconKey: 'pocket',
            priceDelta: 120,
          ),
        ],
      ),
    ];
    _selectedDesigner = designers.first;
    _selectedCategory = categories.first;
    _selectedFabric = fabrics.first;
    for (final group in designGroups) {
      _designChoices[group.id] = group.options.first;
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
      // Fall back to bundled atelier visuals if remote config is unavailable.
    }
  }

  String _normalizedVisualKey(HomeCategoryVisualModel visual) {
    final source = visual.label.trim().isNotEmpty ? visual.label : visual.id;
    return _normalizedKey(source, source);
  }

  String _normalizedKey(String primary, String fallback) {
    final raw = primary.trim().isNotEmpty ? primary : fallback;
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').trim();
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

  void updateMeasurement({
    String? chest,
    String? waist,
    String? hips,
    String? shoulder,
    String? height,
  }) {
    _measurements = _measurements.copyWith(
      chest: chest,
      waist: waist,
      hips: hips,
      shoulder: shoulder,
      height: height,
    );
    notifyListeners();
  }

  void selectDesignChoice(String groupId, DesignOption option) {
    _designChoices[groupId] = option;
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
    if (_step.index > 0) {
      _step = AtelierStep.values[_step.index - 1];
      notifyListeners();
    }
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
