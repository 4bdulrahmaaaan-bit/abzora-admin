import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import '../user/body_scan_screen.dart';
import '../user/live_ar_try_on_screen.dart';
import 'tailoring_flow_screen.dart';

class CustomBrandFlowScreen extends StatefulWidget {
  const CustomBrandFlowScreen({super.key});

  @override
  State<CustomBrandFlowScreen> createState() => _CustomBrandFlowScreenState();
}

class _CustomBrandFlowScreenState extends State<CustomBrandFlowScreen> {
  static const String _draftKey = 'abzora_custom_studio_draft_v2';
  static const List<String> _steps = <String>[
    'Style',
    'Fabric',
    'Measurements',
    'Design',
    'Preview',
    'Confirm',
  ];

  final DatabaseService _database = DatabaseService();
  final TextEditingController _occasionController = TextEditingController(
    text: 'Wedding Reception',
  );
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _chestController = TextEditingController();
  final TextEditingController _waistController = TextEditingController();
  final TextEditingController _hipsController = TextEditingController();
  final TextEditingController _shoulderController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  int _stepIndex = 0;
  bool _isBootstrapping = true;
  bool _isSavingDesign = false;
  bool _isAddingToCart = false;
  bool _isLoadingStoreProducts = false;
  bool _enteredStudio = false;
  String? _error;
  _TailoringCategory? _selectedCategory;
  _StudioStyle? _selectedStyle;
  _FabricOption? _selectedFabric;
  MeasurementProfile? _selectedMeasurement;
  BodyProfile? _savedBodyProfile;
  List<CustomBrand> _brands = const <CustomBrand>[];
  List<CustomBrandProduct> _brandProducts = const <CustomBrandProduct>[];
  CustomBrand? _selectedBrand;
  CustomBrandProduct? _selectedBrandProduct;
  Map<String, String> _designSelections = <String, String>{};
  String _stylistInsight = '';

  @override
  void initState() {
    super.initState();
    _occasionController.addListener(_persistDraft);
    _notesController.addListener(_persistDraft);
    _chestController.addListener(_persistDraft);
    _waistController.addListener(_persistDraft);
    _hipsController.addListener(_persistDraft);
    _shoulderController.addListener(_persistDraft);
    _heightController.addListener(_persistDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _occasionController.dispose();
    _notesController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    _shoulderController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = context.read<AuthProvider>().user;
    final futures = <Future<dynamic>>[
      _database.getCustomBrands(),
    ];
    if (user != null) {
      futures.add(_database.getMeasurementProfiles(user.id));
      futures.add(_database.getBodyProfile(user.id));
    }
    final results = await Future.wait<dynamic>(futures);
    final brands = results.first as List<CustomBrand>;
    final profiles =
        user == null ? const <MeasurementProfile>[] : results[1] as List<MeasurementProfile>;
    final bodyProfile = user == null ? null : results[2] as BodyProfile?;
    final products = brands.isEmpty
        ? const <CustomBrandProduct>[]
        : await _database.getCustomProductsByBrand(brands.first.id);
    await _restoreDraft(
      brands: brands,
      profiles: profiles,
      bodyProfile: bodyProfile,
      products: products,
    );
    final restoredBrand = _selectedBrand;
    if (restoredBrand != null && restoredBrand.id != (brands.isEmpty ? '' : brands.first.id)) {
      final restoredProducts = await _database.getCustomProductsByBrand(restoredBrand.id);
      products
        ..clear()
        ..addAll(restoredProducts);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _brands = brands;
      _brandProducts = products;
      _selectedBrand ??= brands.isNotEmpty ? brands.first : null;
      _selectedBrandProduct ??= _resolveBrandProduct(
        products: products,
        category: _selectedCategory ?? _tailoredCategories.first,
      );
      _savedBodyProfile = bodyProfile;
      _isBootstrapping = false;
      _selectedCategory ??= _tailoredCategories.first;
      _selectedStyle ??= _stylesForCategory(_selectedCategory!).first;
      _selectedFabric ??= _fabrics.first;
      _designSelections = _designSelections.isEmpty
          ? _defaultDesignSelections(_selectedCategory)
          : _designSelections;
    });
    _applySavedBodyProfile(bodyProfile);
    _generateStylistInsight();
  }

  Future<void> _restoreDraft({
    required List<CustomBrand> brands,
    required List<MeasurementProfile> profiles,
    required BodyProfile? bodyProfile,
    required List<CustomBrandProduct> products,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.trim().isEmpty) {
      _applySavedBodyProfile(bodyProfile);
      return;
    }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _stepIndex = ((map['stepIndex'] ?? 0) as num).toInt().clamp(0, _steps.length - 1);
      _enteredStudio = map['enteredStudio'] == true;
      final brandId = (map['brandId'] ?? '').toString();
      if (brandId.isNotEmpty) {
        final matches = brands.where((item) => item.id == brandId);
        if (matches.isNotEmpty) {
          _selectedBrand = matches.first;
        }
      }
      _selectedCategory = _tailoredCategories.firstWhere(
        (item) => item.id == map['categoryId'],
        orElse: () => _tailoredCategories.first,
      );
      _selectedStyle = _allStyles.firstWhere(
        (item) => item.id == map['styleId'],
        orElse: () => _stylesForCategory(_selectedCategory!).first,
      );
      _selectedFabric = _fabrics.firstWhere(
        (item) => item.id == map['fabricId'],
        orElse: () => _fabrics.first,
      );
      _designSelections = Map<String, String>.from(
        map['designSelections'] ?? const <String, String>{},
      );
      _stylistInsight = (map['stylistInsight'] ?? '').toString();
      _occasionController.text = (map['occasion'] ?? _occasionController.text).toString();
      _notesController.text = (map['notes'] ?? '').toString();
      _chestController.text = (map['chest'] ?? '').toString();
      _waistController.text = (map['waist'] ?? '').toString();
      _hipsController.text = (map['hips'] ?? '').toString();
      _shoulderController.text = (map['shoulder'] ?? '').toString();
      _heightController.text = (map['height'] ?? '').toString();
      final productId = (map['brandProductId'] ?? '').toString();
      if (productId.isNotEmpty) {
        final matches = products.where((item) => item.id == productId);
        if (matches.isNotEmpty) {
          _selectedBrandProduct = matches.first;
        }
      }
      final measurementId = (map['measurementId'] ?? '').toString();
      if (measurementId.isNotEmpty) {
        final matches = profiles.where((item) => item.id == measurementId);
        if (matches.isNotEmpty) {
          _selectedMeasurement = matches.first;
        } else {
          _selectedMeasurement = profiles.isEmpty
              ? _measurementFromBodyProfile(bodyProfile)
              : profiles.first;
        }
      } else {
        _selectedMeasurement = profiles.isEmpty
            ? _measurementFromBodyProfile(bodyProfile)
            : profiles.first;
      }
      if (_selectedMeasurement == null) {
        _applySavedBodyProfile(bodyProfile);
      }
    } catch (_) {
      _applySavedBodyProfile(bodyProfile);
    }
  }

  Future<void> _persistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = <String, dynamic>{
      'stepIndex': _stepIndex,
      'enteredStudio': _enteredStudio,
      'brandId': _selectedBrand?.id,
      'brandProductId': _selectedBrandProduct?.id,
      'categoryId': _selectedCategory?.id,
      'styleId': _selectedStyle?.id,
      'fabricId': _selectedFabric?.id,
      'measurementId': _selectedMeasurement?.id,
      'designSelections': _designSelections,
      'occasion': _occasionController.text.trim(),
      'notes': _notesController.text.trim(),
      'chest': _chestController.text.trim(),
      'waist': _waistController.text.trim(),
      'hips': _hipsController.text.trim(),
      'shoulder': _shoulderController.text.trim(),
      'height': _heightController.text.trim(),
      'stylistInsight': _stylistInsight,
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _applySavedBodyProfile(BodyProfile? bodyProfile) {
    if (bodyProfile == null) {
      return;
    }
    _chestController.text = _formatMeasure(bodyProfile.chestCm);
    _waistController.text = _formatMeasure(bodyProfile.waistCm);
    _hipsController.text = _formatMeasure(bodyProfile.hipCm);
    _shoulderController.text = _formatMeasure(bodyProfile.shoulderCm);
    _heightController.text = bodyProfile.heightCm.toStringAsFixed(0);
  }

  String _formatMeasure(double? value) =>
      value == null || value <= 0 ? '' : value.toStringAsFixed(1);

  MeasurementProfile? _measurementFromBodyProfile(BodyProfile? bodyProfile) {
    if (bodyProfile == null) {
      return null;
    }
    return MeasurementProfile(
      id: 'body-profile',
      userId: context.read<AuthProvider>().user?.id ?? '',
      label: 'Estimated measurements',
      method: 'ai_scan',
      chest: bodyProfile.chestCm ?? 0,
      shoulder: bodyProfile.shoulderCm ?? 0,
      waist: bodyProfile.waistCm ?? 0,
      sleeve: bodyProfile.armLengthCm ?? 0,
      length: bodyProfile.heightCm * 0.42,
      recommendedSize: bodyProfile.recommendedSize,
    );
  }

  List<_StudioStyle> _stylesForCategory(_TailoringCategory category) {
    return _allStyles.where((item) => item.categoryId == category.id).toList();
  }

  List<CustomBrandProduct> _productsForCategory(_TailoringCategory category) {
    return _brandProducts
        .where((item) => _matchesProductCategory(item.category, category))
        .toList();
  }

  bool _matchesProductCategory(String productCategory, _TailoringCategory category) {
    final normalizedProduct = productCategory.trim().toLowerCase();
    final normalizedTitle = category.title.trim().toLowerCase();
    if (normalizedProduct == normalizedTitle) {
      return true;
    }
    final aliases = <String>{
      category.id,
      normalizedTitle,
      normalizedTitle.replaceAll(' ', '-'),
      normalizedTitle.replaceAll(' ', ''),
      if (category.id.startsWith('kurtas')) 'kurta',
      if (category.id == 'formal-shirts') 'shirt',
      if (category.id == 'blazers') 'blazer',
      if (category.id == 'suits') 'suit',
      if (category.id == 'dresses') 'dress',
      if (category.id == 'gowns') 'gown',
      if (category.id == 'blouses') 'blouse',
    };
    return aliases.contains(normalizedProduct);
  }

  CustomBrandProduct? _resolveBrandProduct({
    required List<CustomBrandProduct> products,
    required _TailoringCategory category,
  }) {
    final matches =
        products.where((item) => _matchesProductCategory(item.category, category)).toList();
    if (matches.isNotEmpty) {
      return matches.first;
    }
    return products.isEmpty ? null : products.first;
  }

  Map<String, String> _defaultDesignSelections(_TailoringCategory? category) {
    final groups = _designGroups(category);
    return <String, String>{
      for (final group in groups) group.id: group.options.first.id,
    };
  }

  List<_DesignGroup> _designGroups(_TailoringCategory? category) {
    switch (category?.id) {
      case 'formal-shirts':
        return _shirtDesignGroups;
      case 'blazers':
      case 'suits':
        return _blazerDesignGroups;
      case 'dresses':
      case 'gowns':
        return _dressDesignGroups;
      case 'blouses':
        return _blouseDesignGroups;
      case 'kurtas-men':
      case 'kurtas-women':
        return _kurtaDesignGroups;
      default:
        return _shirtDesignGroups;
    }
  }

  double get _livePrice {
    final style = _selectedStyle;
    final fabric = _selectedFabric;
    if (style == null || fabric == null) {
      return 2499;
    }
    final designImpact = _designSelections.entries.fold<double>(0, (sum, entry) {
      final groups = _designGroups(_selectedCategory);
      final group = groups.firstWhere((item) => item.id == entry.key);
      final option = group.options.firstWhere((item) => item.id == entry.value);
      return sum + option.priceImpact;
    });
    final basePrice = _selectedBrandProduct?.basePrice ?? style.basePrice;
    return basePrice + fabric.priceImpact + designImpact;
  }

  double get _startingPrice => _selectedCategory == null
      ? 2499
      : (() {
          final productMatches = _productsForCategory(_selectedCategory!);
          if (productMatches.isNotEmpty) {
            return productMatches
                .map((item) => item.basePrice)
                .fold<double>(productMatches.first.basePrice, (current, next) {
              return next < current ? next : current;
            });
          }
          final styles = _stylesForCategory(_selectedCategory!);
          return styles.map((item) => item.basePrice).fold<double>(
                2499,
                (current, next) => next < current ? next : current,
              );
        })();

  CustomBrand get _resolvedBrand {
    if (_selectedBrand != null) {
      return _selectedBrand!;
    }
    if (_brands.isNotEmpty) {
      return _brands.first;
    }
    return const CustomBrand(
      id: 'abzora-atelier',
      name: 'ABZORA Atelier',
      categories: <String>['Luxury Tailoring'],
      isPremium: true,
    );
  }

  Map<String, double> get _measurementMap {
    return <String, double>{
      'chest': double.tryParse(_chestController.text.trim()) ?? 0,
      'waist': double.tryParse(_waistController.text.trim()) ?? 0,
      'hips': double.tryParse(_hipsController.text.trim()) ?? 0,
      'shoulder': double.tryParse(_shoulderController.text.trim()) ?? 0,
      'height': double.tryParse(_heightController.text.trim()) ?? 0,
    };
  }

  Product get _previewProduct {
    final style = _selectedStyle!;
    final fabric = _selectedFabric!;
    final brand = _resolvedBrand;
    return Product(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      storeId: brand.id,
      name: _selectedBrandProduct?.name ?? style.title,
      brand: brand.name,
      description:
          '${_selectedBrandProduct?.name ?? style.title} tailored in ${fabric.name}. Crafted to your body. Designed for your style.',
      price: _livePrice,
      basePrice: _selectedBrandProduct?.basePrice ?? style.basePrice,
      images: brand.bannerUrl.isEmpty ? const <String>[] : <String>[brand.bannerUrl],
      sizes: const <String>['CUSTOM'],
      stock: 1,
      category: 'Custom Tailoring',
      subcategory: _selectedCategory?.title ?? 'Tailored',
      isCustomTailoring: true,
      outfitType: style.fitLabel,
      fabric: fabric.name,
      customizations: <String, String>{
        'occasion': _occasionController.text.trim(),
        'fabric': fabric.name,
        'atelier': brand.name,
        ..._designSelections.map((key, value) {
          final groups = _designGroups(_selectedCategory);
          final group = groups.firstWhere((item) => item.id == key);
          final option = group.options.firstWhere((item) => item.id == value);
          return MapEntry(group.title, option.title);
        }),
      },
      measurements: _measurementMap,
      addons: _designSelections.values.toList(),
      measurementProfileLabel:
          _selectedMeasurement?.label ?? 'Estimated measurements',
      tailoringDeliveryMode: 'Made-to-order',
      tailoringExtraCost: (_livePrice - style.basePrice).clamp(0, double.infinity),
    );
  }

  void _selectCategory(_TailoringCategory category) {
    final styles = _stylesForCategory(category);
    setState(() {
      _selectedCategory = category;
      _selectedStyle = styles.first;
      _designSelections = _defaultDesignSelections(category);
      _selectedBrandProduct = _resolveBrandProduct(
        products: _brandProducts,
        category: category,
      );
    });
    _generateStylistInsight();
    unawaited(_refreshBrandDiscovery(category: category));
    unawaited(_persistDraft());
  }

  Future<void> _refreshBrandDiscovery({
    _TailoringCategory? category,
  }) async {
    final brands = await _database.getCustomBrands(
      category: (category ?? _selectedCategory)?.title,
    );
    if (!mounted || brands.isEmpty) {
      return;
    }
    final currentBrandId = _selectedBrand?.id;
    CustomBrand? resolvedBrand;
    if (currentBrandId != null && currentBrandId.isNotEmpty) {
      for (final brand in brands) {
        if (brand.id == currentBrandId) {
          resolvedBrand = brand;
          break;
        }
      }
    }
    setState(() {
      _brands = brands;
      if (resolvedBrand != null) {
        _selectedBrand = resolvedBrand;
      }
    });
  }

  Future<void> _selectBrand(CustomBrand brand, {bool enterStudio = false}) async {
    setState(() {
      _selectedBrand = brand;
      _isLoadingStoreProducts = true;
      if (enterStudio) {
        _enteredStudio = true;
      }
    });
    final products = await _database.getCustomProductsByBrand(brand.id);
    if (!mounted) {
      return;
    }
    final category = _selectedCategory ?? _tailoredCategories.first;
    setState(() {
      _brandProducts = products;
      _selectedBrandProduct = _resolveBrandProduct(
        products: products,
        category: category,
      );
      _isLoadingStoreProducts = false;
    });
    _generateStylistInsight();
    await _persistDraft();
  }

  void _openSelectedStoreStudio() {
    final brand = _selectedBrand;
    if (brand == null) {
      _showMessage('Choose a designer or store first.');
      return;
    }
    unawaited(_selectBrand(brand, enterStudio: true));
  }

  void _startQuickCustom() {
    final fallback = _brands.isNotEmpty ? _brands.first : null;
    if (fallback == null) {
      _showMessage('No tailoring stores are available right now.');
      return;
    }
    unawaited(_selectBrand(fallback, enterStudio: true));
    _showMessage(
      'Quick Custom selected. We will prioritize a premium atelier based on availability, rating, and delivery speed.',
    );
  }

  void _selectStyle(_StudioStyle style) {
    setState(() {
      _selectedStyle = style;
    });
    _generateStylistInsight();
    unawaited(_persistDraft());
  }

  void _selectFabric(_FabricOption fabric) {
    setState(() {
      _selectedFabric = fabric;
    });
    _generateStylistInsight();
    unawaited(_persistDraft());
  }

  void _selectDesign(String groupId, String optionId) {
    setState(() {
      _designSelections[groupId] = optionId;
    });
    unawaited(_persistDraft());
  }

  Future<void> _openBodyScan() async {
    final profile = await Navigator.of(context).push<MeasurementProfile>(
      MaterialPageRoute(builder: (_) => const BodyScanScreen()),
    );
    if (!mounted || profile == null) {
      return;
    }
    _applyMeasurementProfile(profile);
  }

  Future<void> _openManualMeasurement() async {
    final profile = await Navigator.of(context).push<MeasurementProfile>(
      MaterialPageRoute(
        builder: (_) => const CustomTailoringFlowScreen(selectionOnly: true),
      ),
    );
    if (!mounted || profile == null) {
      return;
    }
    _applyMeasurementProfile(profile);
  }

  void _applyMeasurementProfile(MeasurementProfile profile) {
    setState(() {
      _selectedMeasurement = profile;
      _chestController.text = profile.chest.toStringAsFixed(1);
      _waistController.text = profile.waist.toStringAsFixed(1);
      _shoulderController.text = profile.shoulder.toStringAsFixed(1);
      _hipsController.text = _hipsController.text.trim().isEmpty
          ? (profile.waist + 8).toStringAsFixed(1)
          : _hipsController.text;
      if (_heightController.text.trim().isEmpty && _savedBodyProfile != null) {
        _heightController.text = _savedBodyProfile!.heightCm.toStringAsFixed(0);
      }
    });
    _generateStylistInsight();
    unawaited(_persistDraft());
  }

  void _generateStylistInsight() {
    final style = _selectedStyle;
    final fabric = _selectedFabric;
    final bodyType = _savedBodyProfile?.bodyType ?? 'regular';
    if (style == null || fabric == null) {
      return;
    }
    final occasion = _occasionController.text.trim().isEmpty
        ? 'special occasions'
        : _occasionController.text.trim();
    final colorAdvice = switch (fabric.id) {
      'silk' => 'deep jewel tones and warm metallic buttons',
      'linen' => 'stone neutrals and matte horn trims',
      'wool-blend' => 'midnight navy with structured contrast lining',
      _ => 'clean ivory and rich charcoal pairings',
    };
    final fitAdvice = switch (bodyType.toLowerCase()) {
      'slim' => 'a softly structured silhouette will add tailored depth',
      'heavy' => 'clean vertical seams will sharpen the frame beautifully',
      _ => 'balanced proportions will keep the look polished and effortless',
    };
    setState(() {
      _stylistInsight =
          'For $occasion, ${style.title.toLowerCase()} in ${fabric.name.toLowerCase()} works especially well. On your body type, $fitAdvice Consider $colorAdvice.';
    });
  }

  Future<void> _saveDesign() async {
    setState(() => _isSavingDesign = true);
    await _persistDraft();
    if (!mounted) {
      return;
    }
    setState(() => _isSavingDesign = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Design saved to your tailoring studio.'),
      ),
    );
  }

  Future<void> _addToCart() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      _showMessage('Sign in to add your tailored design to bag.');
      return;
    }
    if (!_canContinueFromCurrentStep(finalStep: true)) {
      return;
    }
    setState(() => _isAddingToCart = true);
    final result = context.read<CartProvider>().addToCart(_previewProduct, 'CUSTOM');
    if (!mounted) {
      return;
    }
    setState(() => _isAddingToCart = false);
    switch (result) {
      case CartAddResult.storeConflict:
        _showMessage('Your bag has items from another store. Clear it before adding this custom piece.');
        return;
      case CartAddResult.updated:
        _showMessage('Custom design updated in your bag.');
      case CartAddResult.added:
        _showMessage('Custom design added to your bag.');
    }
    await _clearDraft();
  }

  bool _canContinueFromCurrentStep({bool finalStep = false}) {
    if (_selectedBrand == null) {
      _showMessage('Choose a store or designer first.');
      return false;
    }
    if (_selectedCategory == null || _selectedStyle == null) {
      _showMessage('Choose a tailored category and style first.');
      return false;
    }
    if ((_selectedFabric == null) && (_stepIndex >= 1 || finalStep)) {
      _showMessage('Select a premium fabric to continue.');
      return false;
    }
    if ((_stepIndex >= 2 || finalStep) &&
        _measurementMap.values.any((value) => value <= 0)) {
      _showMessage('Add all core measurements before continuing.');
      return false;
    }
    return true;
  }

  void _goNext() {
    if (!_canContinueFromCurrentStep()) {
      return;
    }
    if (_stepIndex == _steps.length - 1) {
      unawaited(_addToCart());
      return;
    }
    setState(() => _stepIndex += 1);
    unawaited(_persistDraft());
  }

  void _goBack() {
    if (_stepIndex == 0) {
      return;
    }
    setState(() => _stepIndex -= 1);
    unawaited(_persistDraft());
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EA),
        appBar: AppBar(
          title: const Text('Tailored Just for You'),
          centerTitle: false,
        ),
        bottomNavigationBar:
            !_isBootstrapping &&
                _error == null &&
                !_enteredStudio &&
                _selectedBrand != null
            ? _buildDiscoveryStickyCta()
            : null,
        body: _isBootstrapping
            ? const AbzioLoadingView(
                title: 'Opening your tailoring studio',
                subtitle: 'Preparing premium styles, fabrics, and your saved measurements.',
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: AbzioEmptyCard(
                        title: 'Studio unavailable',
                        subtitle: _error!,
                      ),
                    ),
                  )
                : SafeArea(
                    child: _enteredStudio
                        ? Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                                child: _buildStepper(),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 240),
                                    child: KeyedSubtree(
                                      key: ValueKey<int>(_stepIndex),
                                      child: _buildStepContent(),
                                    ),
                                  ),
                                ),
                              ),
                              _buildBottomBar(),
                            ],
                          )
                        : RefreshIndicator(
                            onRefresh: _bootstrap,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                              child: _buildDiscoveryFlow(),
                            ),
                          ),
                  ),
      ),
    );
  }

  Widget _buildDiscoveryFlow() {
    final featuredBrands = _brands.take(4).toList();
    final selectedBrand = _selectedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(),
        const SizedBox(height: 22),
        _sectionTitle('Featured Designers'),
        const SizedBox(height: 10),
        _sectionCopy('Choose your atelier first. Every custom piece is designed with a real store, not randomly assigned behind the scenes.'),
        const SizedBox(height: 16),
        ...featuredBrands.map(
          (brand) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _StoreDiscoveryCard(
              brand: brand,
              meta: _storeMetaFor(brand),
              selected: selectedBrand?.id == brand.id,
              onTap: () => _selectBrand(brand),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _sectionTitle('Categories'),
        const SizedBox(height: 10),
        _sectionCopy('Premium tailoring only. Formal, occasion, and made-to-measure essentials curated by category.'),
        const SizedBox(height: 14),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tailoredCategories.length,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) {
              final category = _tailoredCategories[index];
              return SizedBox(
                width: 156,
                child: _CategoryCard(
                  category: category,
                  selected: _selectedCategory?.id == category.id,
                  onTap: () => _selectCategory(category),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _studioBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: AbzioTheme.accentColor),
                  const SizedBox(width: 10),
                  Text(
                    'Quick Custom',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Need a faster route? We can auto-match you with a premium store using rating, availability, and delivery promise.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6C6459),
                    ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _startQuickCustom,
                child: const Text('Start Quick Custom'),
              ),
            ],
          ),
        ),
        if (selectedBrand != null) ...[
          const SizedBox(height: 22),
          _buildStoreProfile(selectedBrand),
        ],
      ],
    );
  }

  Widget _buildStoreProfile(CustomBrand brand) {
    final meta = _storeMetaFor(brand);
    final trustBadges = _trustBadgesFor(brand, meta);
    final reviews = _reviewsFor(brand);
    final experienceYears = _storeExperienceYearsFor(brand);
    final deliveryWindow = _deliveryWindowFor(brand);
    final offeredCategories = brand.categories.isEmpty
        ? _tailoredCategories.take(3).map((item) => item.title).toList()
        : brand.categories;
    final matchingProducts = _brandProducts.isEmpty && !_isLoadingStoreProducts
        ? const <CustomBrandProduct>[]
        : _brandProducts.take(4).toList();
    final portfolioCount =
        brand.bannerUrl.isNotEmpty || brand.logoUrl.isNotEmpty ? 4 : 3;
    final startingPrice = matchingProducts.isNotEmpty
        ? matchingProducts
            .map((item) => item.basePrice)
            .reduce((value, element) => value < element ? value : element)
        : _startingPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Store Profile'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _studioBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 188,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(colors: meta.colors),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 18,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            child: Text(
                              _storeInitials(brand.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  brand.name,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${meta.rating} ★  •  ${meta.location}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.tagline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _PreviewChip(label: meta.priceBand),
                              _PreviewChip(label: 'Made by ${brand.name}'),
                              const _PreviewChip(label: 'Easy alteration policy'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: trustBadges.map((item) => _MetaPill(label: item)).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'About',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                meta.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6C6459),
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE9DFC8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StoreInfoTile(
                        icon: Icons.workspace_premium_rounded,
                        title: 'Experience',
                        value: '$experienceYears years tailoring',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StoreInfoTile(
                        icon: Icons.payments_outlined,
                        title: 'Starting from',
                        value: _rupee(startingPrice),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StoreInfoTile(
                        icon: Icons.schedule_rounded,
                        title: 'Delivery',
                        value: deliveryWindow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Portfolio',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.08,
                ),
                itemCount: portfolioCount,
                itemBuilder: (BuildContext context, int index) {
                  final imageUrl = index.isEven ? brand.bannerUrl : brand.logoUrl;
                  return _PortfolioCard(
                    imageUrl: imageUrl,
                    colors: meta.colors,
                    icon: index % 3 == 0
                        ? Icons.checkroom_rounded
                        : index % 3 == 1
                            ? Icons.workspace_premium_rounded
                            : Icons.style_rounded,
                    label: index == 0
                        ? 'Bridal finish'
                        : index == 1
                            ? 'Signature tailoring'
                            : index == 2
                                ? 'Craft detail'
                                : 'Custom silhouette',
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Specialization',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: offeredCategories.map((item) => _PreviewChip(label: item)).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Reviews',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              ...reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StoreReviewCard(review: review),
                ),
              ),
              if (_isLoadingStoreProducts) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(minHeight: 3),
              ] else if (matchingProducts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Signature styles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                ...matchingProducts.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StoreProductTile(
                      product: product,
                      selected: _selectedBrandProduct?.id == product.id,
                      onTap: () {
                        setState(() {
                          _selectedBrandProduct = product;
                        });
                        unawaited(_persistDraft());
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryStickyCta() {
    final brand = _selectedBrand;
    if (brand == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8DECA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customize directly with this designer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7A705F),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isLoadingStoreProducts ? null : _openSelectedStoreStudio,
              child: Text(
                _isLoadingStoreProducts
                    ? 'Preparing Atelier...'
                    : 'Customize with this Store',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List<Widget>.generate(_steps.length, (int index) {
        final bool active = index == _stepIndex;
        final bool complete = index < _stepIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: complete || active
                        ? AbzioTheme.accentColor
                        : const Color(0xFFE4DDD0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[index].toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: complete || active
                            ? AbzioTheme.accentColor
                            : const Color(0xFF9B927E),
                      ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_stepIndex) {
      case 0:
        return _buildStyleStep();
      case 1:
        return _buildFabricStep();
      case 2:
        return _buildMeasurementStep();
      case 3:
        return _buildDesignStep();
      case 4:
        return _buildPreviewStep();
      case 5:
      default:
        return _buildConfirmStep();
    }
  }

  Widget _buildStyleStep() {
    final category = _selectedCategory ?? _tailoredCategories.first;
    final styles = _stylesForCategory(category);
    final products = _productsForCategory(category);
    final brand = _resolvedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(),
        const SizedBox(height: 22),
        _LuxuryNote(
          title: 'Made by ${brand.name}',
          body:
              'You are customizing directly with this store. Delivery timeline, tailoring quality, and design ownership stay transparent all the way through.',
        ),
        const SizedBox(height: 18),
        _sectionTitle('Curated Categories'),
        const SizedBox(height: 10),
        _sectionCopy('Only refined, made-to-measure silhouettes. No casual basics. No oversized fast fashion.'),
        const SizedBox(height: 16),
        ...<String>['Men', 'Women'].map((String gender) {
          final items = _tailoredCategories.where((item) => item.gender == gender).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gender, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.98,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final item = items[index];
                    final selected = _selectedCategory?.id == item.id;
                    return _CategoryCard(
                      category: item,
                      selected: selected,
                      onTap: () => _selectCategory(item),
                    );
                  },
                ),
              ],
            ),
          );
        }),
        _sectionTitle('Choose Your Style'),
        const SizedBox(height: 10),
        _sectionCopy('Each silhouette is designed to feel atelier-made from the first fitting. Store-specific styles appear first.'),
        const SizedBox(height: 16),
        if (products.isNotEmpty) ...[
          ...products.map((product) {
            final selected = _selectedBrandProduct?.id == product.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StoreProductTile(
                product: product,
                selected: selected,
                onTap: () {
                  setState(() {
                    _selectedBrandProduct = product;
                  });
                  unawaited(_persistDraft());
                },
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        ...styles.map((style) {
          final selected = _selectedStyle?.id == style.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _StyleCard(
              style: style,
              selected: selected,
              onTap: () => _selectStyle(style),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFabricStep() {
    final brand = _resolvedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Select the Fabric'),
        const SizedBox(height: 10),
        _sectionCopy('Made by ${brand.name}. Premium cloth only: elegant drape, luxurious hand-feel, and a visible upgrade in finish.'),
        const SizedBox(height: 18),
        ..._fabrics.map((fabric) {
          final selected = _selectedFabric?.id == fabric.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _FabricCard(
              fabric: fabric,
              selected: selected,
              onTap: () => _selectFabric(fabric),
            ),
          );
        }),
        const SizedBox(height: 12),
        _LuxuryNote(
          title: 'Live price update',
          body:
              'Starting from ${_rupee(_startingPrice)}. Your final price updates instantly as you change fabric and design details.',
        ),
      ],
    );
  }

  Widget _buildMeasurementStep() {
    final brand = _resolvedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Measurements'),
        const SizedBox(height: 10),
        _sectionCopy('Made by ${brand.name}. AI body scan is the primary route. Manual tailoring input stays available when you want absolute control.'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _studioBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E4B4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Precision fit guaranteed',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _selectedMeasurement?.label ?? 'Estimated measurements (editable)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF776C58),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openBodyScan,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('AI Body Scan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openManualMeasurement,
                      icon: const Icon(Icons.straighten_rounded),
                      label: const Text('Manual Input'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _measurementField('Chest', _chestController),
                  _measurementField('Waist', _waistController),
                  _measurementField('Hips', _hipsController),
                  _measurementField('Shoulder', _shoulderController),
                  _measurementField('Height', _heightController),
                ],
              ),
              if (_savedBodyProfile != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Saved body profile: ${_savedBodyProfile!.recommendedSize} fit · ${((_savedBodyProfile!.confidence ?? 0.82) * 100).round()}% confidence',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6D6455)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesignStep() {
    final groups = _designGroups(_selectedCategory);
    final brand = _resolvedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Design Details'),
        const SizedBox(height: 10),
        _sectionCopy('Made by ${brand.name}. Every detail is visual and tactile. No dropdown clutter, just atelier decisions.'),
        const SizedBox(height: 18),
        ...groups.map((group) {
          final selected = _designSelections[group.id] ?? group.options.first.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: _studioBox(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(group.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6C6459))),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 144,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (BuildContext context, int index) {
                        final option = group.options[index];
                        return _DesignOptionCard(
                          option: option,
                          selected: option.id == selected,
                          onTap: () => _selectDesign(group.id, option.id),
                        );
                      },
                      separatorBuilder: (_, separatorIndex) => const SizedBox(width: 12),
                      itemCount: group.options.length,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPreviewStep() {
    final style = _selectedStyle!;
    final fabric = _selectedFabric!;
    final groups = _designGroups(_selectedCategory);
    final brand = _resolvedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Live Preview'),
        const SizedBox(height: 10),
        _sectionCopy('Made by ${brand.name}. A premium preview that updates as your style, fabric, and detailing change.'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF111111), Color(0xFF2C2417), Color(0xFFF5E8BD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      style.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      fabric.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                height: 340,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: fabric.colors
                                .map((color) => color.withValues(alpha: 0.28))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.accessibility_new_rounded,
                      size: 140,
                      color: Colors.white70,
                    ),
                    Positioned(
                      bottom: 18,
                      left: 18,
                      right: 18,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groups.map((group) {
                          final optionId = _designSelections[group.id]!;
                          final option =
                              group.options.firstWhere((item) => item.id == optionId);
                          return _PreviewChip(
                            label: '${group.title}: ${option.title}',
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _stylistInsight.isEmpty
                    ? 'Crafted to your body. Designed for your style. Made by ${brand.name}.'
                    : _stylistInsight,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveArTryOnScreen(
                        product: _previewProduct,
                        accentColor: AbzioTheme.accentColor,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.view_in_ar_rounded),
                label: const Text('Try on your body'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generateStylistInsight,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Get Style Suggestion'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final style = _selectedStyle!;
    final fabric = _selectedFabric!;
    final brand = _resolvedBrand;
    final measurements = _measurementMap;
    final groups = _designGroups(_selectedCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Order Summary'),
        const SizedBox(height: 10),
        _sectionCopy('Made-to-order luxury tailoring with a complete record of your design, measurements, and final price.'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _studioBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('Style', style.title),
              _summaryRow('Fabric', '${fabric.name} · ${fabric.feel}'),
              _summaryRow('Atelier', brand.name),
              _summaryRow('Measurements', _selectedMeasurement?.label ?? 'Estimated measurements'),
              _summaryRow('Final Price', _rupee(_livePrice)),
              const SizedBox(height: 16),
              Text('Design choices', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...groups.map((group) {
                final option = group.options.firstWhere(
                  (item) => item.id == _designSelections[group.id],
                );
                return _summaryRow(group.title, option.title);
              }),
              const Divider(height: 30),
              Text('Estimated measurements (editable)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: measurements.entries
                    .map((entry) => _PreviewChip(label: '${_capitalize(entry.key)} ${entry.value.toStringAsFixed(1)} cm'))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1E3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: AbzioTheme.accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Made-to-order · Delivered in 5-7 days',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSavingDesign ? null : _saveDesign,
                      child: Text(_isSavingDesign ? 'Saving...' : 'Save Design'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAddingToCart ? null : _addToCart,
                      child: Text(_isAddingToCart ? 'Adding...' : 'Add to Cart'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE6DFD1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _stepIndex == 0
                      ? 'Starting from ${_rupee(_startingPrice)}'
                      : 'Made by ${_resolvedBrand.name} • Final price updates live',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF7B705C)),
                ),
                const SizedBox(height: 3),
                Text(
                  _rupee(_livePrice),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (_stepIndex > 0) ...[
            OutlinedButton(
              onPressed: _goBack,
              child: const Text('Back'),
            ),
            const SizedBox(width: 10),
          ],
          ElevatedButton(
            onPressed: _goNext,
            child: Text(_stepIndex == _steps.length - 1 ? 'Add to Cart' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF141414), Color(0xFF2D2416), Color(0xFFF6E7B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'TAILORED JUST FOR YOU',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Crafted to your body.\nDesigned for your style.',
            style: GoogleFonts.outfit(
              fontSize: 30,
              height: 1.08,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedBrand == null
                ? 'Choose your designer first, then build a premium made-to-measure outfit with complete store visibility.'
                : 'Made by ${_resolvedBrand.name}. A luxury digital tailoring studio for refined shirts, suits, blazers, kurtas, gowns, dresses, and blouses.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
        ],
      ),
    );
  }

  Widget _measurementField(String label, TextEditingController controller) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64) / 2,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'cm',
        ),
      ),
    );
  }

  BoxDecoration _studioBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8DFCF)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF181512),
      ),
    );
  }

  Widget _sectionCopy(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF6B6357),
          ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7A705F),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF191612),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  _StoreMeta _storeMetaFor(CustomBrand brand) {
    final int seed = brand.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    if (brand.rating > 0 ||
        brand.location.trim().isNotEmpty ||
        brand.tagline.trim().isNotEmpty ||
        brand.description.trim().isNotEmpty) {
      return _StoreMeta(
        rating: brand.rating > 0 ? brand.rating.toStringAsFixed(1) : '4.8',
        location: brand.location.trim().isEmpty ? 'India' : brand.location.trim(),
        priceBand: brand.priceBand.trim().isEmpty ? 'RsRsRs' : brand.priceBand,
        tagline: brand.tagline.trim().isEmpty
            ? 'Luxury tailoring studio'
            : brand.tagline.trim(),
        description: brand.description.trim().isEmpty
            ? 'Premium made-to-measure tailoring with elevated finishing and a boutique workflow.'
            : brand.description.trim(),
        colors: <Color>[
          const Color(0xFF121212),
          brand.rankingVisibility == 'top_performer'
              ? const Color(0xFFC8A95B)
              : brand.rankingVisibility == 'new_designer'
                  ? const Color(0xFF8E7040)
                  : const Color(0xFF9C7A45),
        ],
        highlights: brand.highlightChips,
      );
    }
    return _StoreMeta(
      rating: (4.5 + (seed % 4) * 0.1).toStringAsFixed(1),
      location: <String>[
        'Chennai',
        'Bengaluru',
        'Hyderabad',
        'Mumbai',
      ][seed % 4],
      priceBand: <String>['₹₹₹', '₹₹₹', '₹₹₹₹', '₹₹₹'][seed % 4],
      tagline: <String>[
        'Wedding Specialists',
        'Luxury Occasion Tailoring',
        'Refined Formalwear Studio',
        'Couture Fit Experts',
      ][seed % 4],
      description: <String>[
        'Known for precision cuts, occasion-led tailoring, and elevated finishing that feels boutique-made.',
        'This atelier blends premium fabric selection with modern silhouettes for made-to-measure confidence.',
        'A trusted tailoring house for sharp formalwear, festive craftsmanship, and alteration-friendly service.',
        'Focused on premium fits, refined details, and a personal tailoring journey from scan to delivery.',
      ][seed % 4],
      colors: <List<Color>>[
        <Color>[const Color(0xFF121212), const Color(0xFFB48C45)],
        <Color>[const Color(0xFF1D1A17), const Color(0xFF8D6A3E)],
        <Color>[const Color(0xFF13161F), const Color(0xFF866742)],
        <Color>[const Color(0xFF201614), const Color(0xFFAA8A4C)],
      ][seed % 4],
      highlights: brand.highlightChips,
    );
  }

  String _storeInitials(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return 'A';
    }
    return parts.map((item) => item[0].toUpperCase()).join();
  }

  String _rupee(double value) => 'Rs ${value.toStringAsFixed(0)}';

  int _storeExperienceYearsFor(CustomBrand brand) {
    final seed = brand.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return 6 + (seed % 7);
  }

  String _deliveryWindowFor(CustomBrand brand) {
    final seed = brand.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final start = 5 + (seed % 2);
    final end = start + 2;
    return '$start-$end days';
  }

  List<String> _trustBadgesFor(CustomBrand brand, _StoreMeta meta) {
    return <String>[
      'Verified Designer',
      'On-time Delivery 95%',
      if (brand.rankingVisibility == 'top_performer' || brand.rating >= 4.7)
        'Top Rated'
      else
        'Premium Atelier',
    ];
  }

  List<_StoreReview> _reviewsFor(CustomBrand brand) {
    final seed = brand.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final baseRating = brand.rating > 0 ? brand.rating : 4.6;
    return <_StoreReview>[
      _StoreReview(
        name: 'Aarav',
        rating: baseRating,
        comment:
            'The final outfit looked exactly like the preview and the fit was sharp from the first delivery.',
        imageLabel: 'Wedding blazer',
      ),
      _StoreReview(
        name: 'Meera',
        rating: (baseRating - ((seed % 2) * 0.1)).clamp(4.4, 5).toDouble(),
        comment:
            'Clean finishing, premium fabric feel, and a tailoring team that handled adjustments with care.',
        imageLabel: 'Evening gown',
      ),
    ];
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _StoreMeta {
  const _StoreMeta({
    required this.rating,
    required this.location,
    required this.priceBand,
    required this.tagline,
    required this.description,
    required this.colors,
    this.highlights = const <String>[],
  });

  final String rating;
  final String location;
  final String priceBand;
  final String tagline;
  final String description;
  final List<Color> colors;
  final List<String> highlights;
}

class _StoreReview {
  const _StoreReview({
    required this.name,
    required this.rating,
    required this.comment,
    required this.imageLabel,
  });

  final String name;
  final double rating;
  final String comment;
  final String imageLabel;
}

class _StoreDiscoveryCard extends StatelessWidget {
  const _StoreDiscoveryCard({
    required this.brand,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final CustomBrand brand;
  final _StoreMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : const Color(0xFFE6DDCB),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: <BoxShadow>[
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
            Container(
              height: 132,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(colors: meta.colors),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      child: Text(
                        brand.name.isEmpty ? 'A' : brand.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        meta.priceBand,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${meta.rating} ★ • ${meta.location}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6D6455),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta.tagline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF1C1814),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (meta.highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: meta.highlights.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F1DE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF7A602C),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    meta.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6D6455),
                        ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onTap,
                      child: Text(selected ? 'Selected Store' : 'View Store'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreProductTile extends StatelessWidget {
  const _StoreProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final CustomBrandProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : const Color(0xFFE6DDCB),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFF4E9C8),
              ),
              child: const Icon(Icons.checkroom_rounded, color: Color(0xFF6E552B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.category,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6C6459),
                        ),
                  ),
                ],
              ),
            ),
            Text(
              'From Rs ${product.basePrice.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _TailoringCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(colors: category.colors),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : Colors.white.withValues(alpha: 0.26),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                  selected ? Icons.check_circle_rounded : category.icon,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                category.title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final _StudioStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : const Color(0xFFE6DDCB),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(colors: style.colors),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Icon(
                      selected ? Icons.check_circle_rounded : Icons.star_border_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.checkroom_rounded,
                      size: 76,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    style.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF70675A)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MetaPill(label: style.occasionLabel),
                      const SizedBox(width: 8),
                      _MetaPill(label: 'Starting ${style.basePrice.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabricCard extends StatelessWidget {
  const _FabricCard({
    required this.fabric,
    required this.selected,
    required this.onTap,
  });

  final _FabricOption fabric;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : const Color(0xFFE6DDCB),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: fabric.colors),
                ),
                child: const Icon(
                  Icons.texture_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fabric.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '+${fabric.priceImpact.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AbzioTheme.accentColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fabric.feel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF7C725F),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fabric.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF70675A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignOptionCard extends StatelessWidget {
  const _DesignOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _DesignOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0xFFF8EBC4) : const Color(0xFFF8F6F0),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : const Color(0xFFE5DDD0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.72)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(option.icon, color: const Color(0xFF2B231A)),
              ),
              const Spacer(),
              Text(
                option.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                option.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF7A705E)),
              ),
              const SizedBox(height: 6),
              Text(
                option.priceImpact == 0
                    ? 'Included'
                    : '+Rs ${option.priceImpact.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AbzioTheme.accentColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreInfoTile extends StatelessWidget {
  const _StoreInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AbzioTheme.accentColor, size: 18),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A705F),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF181410),
              ),
        ),
      ],
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.imageUrl,
    required this.colors,
    required this.icon,
    required this.label,
  });

  final String imageUrl;
  final List<Color> colors;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => const SizedBox.shrink(),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    colors.first.withValues(alpha: 0.95),
                    colors.last.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: hasImage ? 0.04 : 0),
                  Colors.black.withValues(alpha: 0.58),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreReviewCard extends StatelessWidget {
  const _StoreReviewCard({required this.review});

  final _StoreReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DEC9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8CB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.photo_camera_back_outlined,
              color: AbzioTheme.accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Text(
                      '${review.rating.toStringAsFixed(1)} ★',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AbzioTheme.accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  review.imageLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7A705F),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  review.comment,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5F574A),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LuxuryNote extends StatelessWidget {
  const _LuxuryNote({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EBCF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4B402B),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _TailoringCategory {
  const _TailoringCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gender,
    required this.icon,
    required this.colors,
  });

  final String id;
  final String title;
  final String subtitle;
  final String gender;
  final IconData icon;
  final List<Color> colors;
}

class _StudioStyle {
  const _StudioStyle({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.occasionLabel,
    required this.fitLabel,
    required this.basePrice,
    required this.backendCategory,
    required this.colors,
  });

  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String occasionLabel;
  final String fitLabel;
  final double basePrice;
  final String backendCategory;
  final List<Color> colors;
}

class _FabricOption {
  const _FabricOption({
    required this.id,
    required this.name,
    required this.feel,
    required this.description,
    required this.priceImpact,
    required this.colors,
  });

  final String id;
  final String name;
  final String feel;
  final String description;
  final double priceImpact;
  final List<Color> colors;
}

class _DesignGroup {
  const _DesignGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.options,
  });

  final String id;
  final String title;
  final String description;
  final List<_DesignOption> options;
}

class _DesignOption {
  const _DesignOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.priceImpact = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final double priceImpact;
}

const List<_TailoringCategory> _tailoredCategories = <_TailoringCategory>[
  _TailoringCategory(
    id: 'formal-shirts',
    title: 'Formal Shirts',
    subtitle: 'Clean lines. Boardroom precision.',
    gender: 'Men',
    icon: Icons.checkroom_rounded,
    colors: <Color>[Color(0xFF111111), Color(0xFF4B3E2A)],
  ),
  _TailoringCategory(
    id: 'blazers',
    title: 'Blazers',
    subtitle: 'Structured tailoring with presence.',
    gender: 'Men',
    icon: Icons.business_center_rounded,
    colors: <Color>[Color(0xFF1A1C24), Color(0xFF7B6440)],
  ),
  _TailoringCategory(
    id: 'suits',
    title: 'Suits',
    subtitle: 'Occasion-first luxury suiting.',
    gender: 'Men',
    icon: Icons.workspace_premium_rounded,
    colors: <Color>[Color(0xFF171717), Color(0xFF5B4931)],
  ),
  _TailoringCategory(
    id: 'kurtas-men',
    title: 'Kurtas',
    subtitle: 'Festive tailoring with graceful drape.',
    gender: 'Men',
    icon: Icons.auto_awesome_rounded,
    colors: <Color>[Color(0xFF2A1F19), Color(0xFF8B6A45)],
  ),
  _TailoringCategory(
    id: 'dresses',
    title: 'Dresses',
    subtitle: 'Refined silhouettes for elegant occasions.',
    gender: 'Women',
    icon: Icons.style_rounded,
    colors: <Color>[Color(0xFF24171F), Color(0xFF8A5F63)],
  ),
  _TailoringCategory(
    id: 'gowns',
    title: 'Gowns',
    subtitle: 'Statement evening tailoring.',
    gender: 'Women',
    icon: Icons.nightlife_rounded,
    colors: <Color>[Color(0xFF17131D), Color(0xFF685071)],
  ),
  _TailoringCategory(
    id: 'blouses',
    title: 'Blouses',
    subtitle: 'Delicate structure for couture pairing.',
    gender: 'Women',
    icon: Icons.design_services_rounded,
    colors: <Color>[Color(0xFF221B16), Color(0xFF927053)],
  ),
  _TailoringCategory(
    id: 'kurtas-women',
    title: 'Kurtas',
    subtitle: 'Modern festive craftsmanship.',
    gender: 'Women',
    icon: Icons.auto_awesome_rounded,
    colors: <Color>[Color(0xFF251B1F), Color(0xFF8A5D6A)],
  ),
];

const List<_StudioStyle> _allStyles = <_StudioStyle>[
  _StudioStyle(
    id: 'slim-formal-shirt',
    categoryId: 'formal-shirts',
    title: 'Slim Fit Formal Shirt',
    description: 'A sharp, close-cut shirt designed for polished evening and corporate dressing.',
    occasionLabel: 'Executive',
    fitLabel: 'Slim',
    basePrice: 2499,
    backendCategory: 'shirt',
    colors: <Color>[Color(0xFF0F1114), Color(0xFF4D3F2B)],
  ),
  _StudioStyle(
    id: 'heritage-blazer',
    categoryId: 'blazers',
    title: 'Wedding Blazer',
    description: 'Tailored shoulders, refined lapel roll, and ceremony-grade elegance.',
    occasionLabel: 'Wedding',
    fitLabel: 'Tailored',
    basePrice: 5299,
    backendCategory: 'blazer',
    colors: <Color>[Color(0xFF191B23), Color(0xFF7C623D)],
  ),
  _StudioStyle(
    id: 'signature-suit',
    categoryId: 'suits',
    title: 'Signature Two-Piece Suit',
    description: 'Clean suiting architecture with luxury finishing details for high-value occasions.',
    occasionLabel: 'Black Tie',
    fitLabel: 'Structured',
    basePrice: 6999,
    backendCategory: 'suit',
    colors: <Color>[Color(0xFF111216), Color(0xFF66523C)],
  ),
  _StudioStyle(
    id: 'royal-kurta',
    categoryId: 'kurtas-men',
    title: 'Royal Occasion Kurta',
    description: 'Festive tailoring with elegant placket balance and ceremonial presence.',
    occasionLabel: 'Festive',
    fitLabel: 'Classic',
    basePrice: 3299,
    backendCategory: 'kurta',
    colors: <Color>[Color(0xFF1C1715), Color(0xFF87623D)],
  ),
  _StudioStyle(
    id: 'column-dress',
    categoryId: 'dresses',
    title: 'Elegant Column Dress',
    description: 'A refined body-skimming dress built for sophisticated events and premium dinners.',
    occasionLabel: 'Evening',
    fitLabel: 'Sculpted',
    basePrice: 4499,
    backendCategory: 'dress',
    colors: <Color>[Color(0xFF22171F), Color(0xFF8B5B6B)],
  ),
  _StudioStyle(
    id: 'evening-gown',
    categoryId: 'gowns',
    title: 'Evening Gown',
    description: 'Fluid movement, couture-inspired shaping, and a dramatic premium finish.',
    occasionLabel: 'Red Carpet',
    fitLabel: 'Draped',
    basePrice: 7499,
    backendCategory: 'gown',
    colors: <Color>[Color(0xFF17131D), Color(0xFF6E5376)],
  ),
  _StudioStyle(
    id: 'couture-blouse',
    categoryId: 'blouses',
    title: 'Couture Blouse',
    description: 'Structured elegance designed to elevate sarees, skirts, and formal separates.',
    occasionLabel: 'Ceremony',
    fitLabel: 'Tailored',
    basePrice: 2899,
    backendCategory: 'blouse',
    colors: <Color>[Color(0xFF1F1814), Color(0xFF8A6A4D)],
  ),
  _StudioStyle(
    id: 'atelier-kurta',
    categoryId: 'kurtas-women',
    title: 'Atelier Kurta Set',
    description: 'A made-to-measure ethnic silhouette with luxury fabric play and graceful proportion.',
    occasionLabel: 'Festive',
    fitLabel: 'Graceful',
    basePrice: 3599,
    backendCategory: 'kurta',
    colors: <Color>[Color(0xFF241A20), Color(0xFF865C69)],
  ),
];

const List<_FabricOption> _fabrics = <_FabricOption>[
  _FabricOption(
    id: 'egyptian-cotton',
    name: 'Egyptian Cotton',
    feel: 'Soft • Crisp • Luxurious',
    description: 'Perfect for premium shirts and structured blouses with a polished finish.',
    priceImpact: 650,
    colors: <Color>[Color(0xFFEAE1CD), Color(0xFFC7AF7B)],
  ),
  _FabricOption(
    id: 'linen',
    name: 'Linen',
    feel: 'Breathable • Relaxed • Refined',
    description: 'Ideal for tailored summer kurtas and day-to-evening elegance.',
    priceImpact: 520,
    colors: <Color>[Color(0xFFD8CDB8), Color(0xFF9F8766)],
  ),
  _FabricOption(
    id: 'silk',
    name: 'Silk',
    feel: 'Fluid • Lustrous • Couture',
    description: 'Adds a premium drape for dresses, gowns, and ceremony wear.',
    priceImpact: 1250,
    colors: <Color>[Color(0xFF9C7F5A), Color(0xFF3E291A)],
  ),
  _FabricOption(
    id: 'wool-blend',
    name: 'Wool Blend',
    feel: 'Structured • Warm • Sharp',
    description: 'Best for blazers and suits that need tailored architecture.',
    priceImpact: 980,
    colors: <Color>[Color(0xFF33363D), Color(0xFF141518)],
  ),
];

const List<_DesignGroup> _shirtDesignGroups = <_DesignGroup>[
  _DesignGroup(
    id: 'collar',
    title: 'Collar Type',
    description: 'Define the face framing and the shirt’s sharpness.',
    options: <_DesignOption>[
      _DesignOption(id: 'spread', title: 'Spread', subtitle: 'Formal and confident', icon: Icons.expand),
      _DesignOption(id: 'cutaway', title: 'Cutaway', subtitle: 'Modern and sculpted', icon: Icons.change_history_rounded, priceImpact: 120),
      _DesignOption(id: 'band', title: 'Band', subtitle: 'Minimal and clean', icon: Icons.remove_rounded),
    ],
  ),
  _DesignGroup(
    id: 'cuff',
    title: 'Cuff Style',
    description: 'Choose the finish around the wrist line.',
    options: <_DesignOption>[
      _DesignOption(id: 'barrel', title: 'Barrel', subtitle: 'Classic business finish', icon: Icons.crop_16_9_rounded),
      _DesignOption(id: 'double', title: 'French', subtitle: 'Formal luxury cuff', icon: Icons.crop_din_rounded, priceImpact: 160),
      _DesignOption(id: 'rounded', title: 'Rounded', subtitle: 'Soft tailored edge', icon: Icons.circle_outlined),
    ],
  ),
  _DesignGroup(
    id: 'buttons',
    title: 'Buttons',
    description: 'Refine the detailing and material note.',
    options: <_DesignOption>[
      _DesignOption(id: 'mother-pearl', title: 'Mother of Pearl', subtitle: 'Premium sheen', icon: Icons.adjust_rounded, priceImpact: 140),
      _DesignOption(id: 'matte', title: 'Matte Resin', subtitle: 'Quiet luxury', icon: Icons.blur_circular_rounded),
      _DesignOption(id: 'metal', title: 'Brushed Metal', subtitle: 'Statement trim', icon: Icons.radio_button_checked_rounded, priceImpact: 180),
    ],
  ),
  _DesignGroup(
    id: 'pocket',
    title: 'Pocket',
    description: 'Balance function and minimalism.',
    options: <_DesignOption>[
      _DesignOption(id: 'none', title: 'No Pocket', subtitle: 'Cleaner front', icon: Icons.crop_square_rounded),
      _DesignOption(id: 'single', title: 'Single Pocket', subtitle: 'Classic office touch', icon: Icons.bookmark_border_rounded),
      _DesignOption(id: 'hidden', title: 'Hidden Pocket', subtitle: 'Discreet detailing', icon: Icons.visibility_off_outlined, priceImpact: 90),
    ],
  ),
];

const List<_DesignGroup> _blazerDesignGroups = <_DesignGroup>[
  _DesignGroup(
    id: 'lapel',
    title: 'Lapel',
    description: 'This shapes the blazer’s personality immediately.',
    options: <_DesignOption>[
      _DesignOption(id: 'notch', title: 'Notch', subtitle: 'Timeless tailoring', icon: Icons.architecture_rounded),
      _DesignOption(id: 'peak', title: 'Peak', subtitle: 'Bold ceremony presence', icon: Icons.north_rounded, priceImpact: 220),
      _DesignOption(id: 'shawl', title: 'Shawl', subtitle: 'Evening elegance', icon: Icons.mode_standby_rounded, priceImpact: 260),
    ],
  ),
  _DesignGroup(
    id: 'vent',
    title: 'Vent',
    description: 'Back movement and silhouette control.',
    options: <_DesignOption>[
      _DesignOption(id: 'single', title: 'Single Vent', subtitle: 'Classic movement', icon: Icons.vertical_align_bottom_rounded),
      _DesignOption(id: 'double', title: 'Double Vent', subtitle: 'Luxury tailoring standard', icon: Icons.view_stream_rounded, priceImpact: 140),
      _DesignOption(id: 'none', title: 'No Vent', subtitle: 'Formal ceremonial line', icon: Icons.remove_rounded),
    ],
  ),
  _DesignGroup(
    id: 'lining',
    title: 'Lining',
    description: 'Inside finish that affects comfort and drama.',
    options: <_DesignOption>[
      _DesignOption(id: 'half', title: 'Half Lining', subtitle: 'Breathable and light', icon: Icons.crop_7_5_rounded),
      _DesignOption(id: 'full', title: 'Full Lining', subtitle: 'Rich interior finish', icon: Icons.crop_square_rounded, priceImpact: 180),
      _DesignOption(id: 'contrast', title: 'Contrast Lining', subtitle: 'Statement luxury', icon: Icons.gradient_rounded, priceImpact: 240),
    ],
  ),
];

const List<_DesignGroup> _dressDesignGroups = <_DesignGroup>[
  _DesignGroup(
    id: 'neckline',
    title: 'Neckline',
    description: 'Set the elegance level and visual balance.',
    options: <_DesignOption>[
      _DesignOption(id: 'boat', title: 'Boat Neck', subtitle: 'Soft formal line', icon: Icons.line_weight_rounded),
      _DesignOption(id: 'sweetheart', title: 'Sweetheart', subtitle: 'Romantic couture', icon: Icons.favorite_border_rounded, priceImpact: 180),
      _DesignOption(id: 'high', title: 'High Neck', subtitle: 'Editorial refinement', icon: Icons.keyboard_arrow_up_rounded),
    ],
  ),
  _DesignGroup(
    id: 'length',
    title: 'Length',
    description: 'Choose the drama and movement.',
    options: <_DesignOption>[
      _DesignOption(id: 'midi', title: 'Midi', subtitle: 'Modern elegance', icon: Icons.height_rounded),
      _DesignOption(id: 'floor', title: 'Floor Length', subtitle: 'Gown drama', icon: Icons.vertical_align_bottom_rounded, priceImpact: 280),
      _DesignOption(id: 'ankle', title: 'Ankle Length', subtitle: 'Balanced luxury', icon: Icons.straighten_rounded, priceImpact: 140),
    ],
  ),
  _DesignGroup(
    id: 'sleeve',
    title: 'Sleeve',
    description: 'Affects movement and silhouette finish.',
    options: <_DesignOption>[
      _DesignOption(id: 'cap', title: 'Cap Sleeve', subtitle: 'Soft and graceful', icon: Icons.crop_portrait_rounded),
      _DesignOption(id: 'three-quarter', title: '3/4 Sleeve', subtitle: 'Elegant versatility', icon: Icons.crop_3_2_rounded, priceImpact: 120),
      _DesignOption(id: 'full', title: 'Full Sleeve', subtitle: 'Formal polish', icon: Icons.crop_16_9_rounded, priceImpact: 160),
    ],
  ),
];

const List<_DesignGroup> _blouseDesignGroups = <_DesignGroup>[
  _DesignGroup(
    id: 'neckline',
    title: 'Neckline',
    description: 'Frame the blouse with couture intent.',
    options: <_DesignOption>[
      _DesignOption(id: 'round', title: 'Round', subtitle: 'Classic festive line', icon: Icons.circle_outlined),
      _DesignOption(id: 'square', title: 'Square', subtitle: 'Architectural shape', icon: Icons.crop_square_rounded, priceImpact: 120),
      _DesignOption(id: 'v-neck', title: 'V Neck', subtitle: 'Elongated elegance', icon: Icons.change_history_rounded),
    ],
  ),
  _DesignGroup(
    id: 'back',
    title: 'Back Detail',
    description: 'Control drama and tailoring appeal.',
    options: <_DesignOption>[
      _DesignOption(id: 'closed', title: 'Closed Back', subtitle: 'Minimal couture', icon: Icons.lock_outline_rounded),
      _DesignOption(id: 'tie-back', title: 'Tie Back', subtitle: 'Soft luxury detail', icon: Icons.tune_rounded, priceImpact: 150),
      _DesignOption(id: 'deep-back', title: 'Deep Back', subtitle: 'Evening statement', icon: Icons.expand_more_rounded, priceImpact: 200),
    ],
  ),
];

const List<_DesignGroup> _kurtaDesignGroups = <_DesignGroup>[
  _DesignGroup(
    id: 'placket',
    title: 'Placket',
    description: 'The center line that defines the kurta’s identity.',
    options: <_DesignOption>[
      _DesignOption(id: 'hidden', title: 'Hidden', subtitle: 'Minimal premium line', icon: Icons.remove_rounded),
      _DesignOption(id: 'buttoned', title: 'Buttoned', subtitle: 'Traditional elegance', icon: Icons.radio_button_checked_rounded),
      _DesignOption(id: 'embroidered', title: 'Embroidered', subtitle: 'Ceremonial finish', icon: Icons.auto_fix_high_rounded, priceImpact: 220),
    ],
  ),
  _DesignGroup(
    id: 'sleeve',
    title: 'Sleeve Finish',
    description: 'Refines proportion and comfort.',
    options: <_DesignOption>[
      _DesignOption(id: 'classic', title: 'Classic', subtitle: 'Evergreen tailoring', icon: Icons.crop_16_9_rounded),
      _DesignOption(id: 'rolled', title: 'Rolled Tab', subtitle: 'Modern luxury casual-formal', icon: Icons.unfold_more_rounded, priceImpact: 90),
      _DesignOption(id: 'cuff', title: 'Tailored Cuff', subtitle: 'Sharper festive edge', icon: Icons.fit_screen_rounded, priceImpact: 130),
    ],
  ),
];
