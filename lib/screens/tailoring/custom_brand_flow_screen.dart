import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import '../user/body_scan_screen.dart';
import 'tailoring_flow_screen.dart';

class CustomBrandFlowScreen extends StatefulWidget {
  const CustomBrandFlowScreen({super.key});

  @override
  State<CustomBrandFlowScreen> createState() => _CustomBrandFlowScreenState();
}

class _CustomBrandFlowScreenState extends State<CustomBrandFlowScreen> {
  final DatabaseService _database = DatabaseService();
  final TextEditingController _styleNotesController = TextEditingController();
  final TextEditingController _fabricNotesController = TextEditingController();
  final TextEditingController _occasionController = TextEditingController(text: 'Wedding');

  late final Future<List<CustomBrand>> _brandsFuture;
  Future<List<CustomBrandProduct>>? _productsFuture;

  CustomBrand? _selectedBrand;
  CustomBrandProduct? _selectedProduct;
  MeasurementProfile? _selectedMeasurement;
  String _fitPreference = 'Classic';
  String _deliveryMode = 'Home Trial';
  String _currentStep = 'brand';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _brandsFuture = _database.getCustomBrands();
  }

  @override
  void dispose() {
    _styleNotesController.dispose();
    _fabricNotesController.dispose();
    _occasionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: AbzioTheme.darkBackground,
        appBar: AppBar(
          title: const Text('Custom Clothing'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _stepStrip(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_currentStep) {
                      'brand' => _brandStep(),
                      'product' => _productStep(),
                      'customize' => _customizeStep(),
                      'measurements' => _measurementStep(),
                      _ => _reviewStep(),
                    },
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepStrip() {
    const steps = ['brand', 'product', 'customize', 'measurements', 'review'];
    return Row(
      children: List.generate(steps.length, (index) {
        final currentIndex = steps.indexOf(_currentStep);
        final isDone = index < currentIndex;
        final isActive = index == currentIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
            child: Column(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDone || isActive ? AbzioTheme.accentColor : AbzioTheme.grey100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[index].toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDone || isActive ? AbzioTheme.accentColor : AbzioTheme.grey500,
                      ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _brandStep() {
    return FutureBuilder<List<CustomBrand>>(
      future: _brandsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AbzioLoadingView(
            title: 'Loading premium brands',
            subtitle: 'Fetching bespoke custom clothing partners.',
          );
        }
        final brands = snapshot.data ?? const <CustomBrand>[];
        if (brands.isEmpty) {
          return const AbzioEmptyCard(
            title: 'No custom brands available',
            subtitle: 'Add premium custom clothing brands like Mizaj or PN Rao in the backend to start this flow.',
          );
        }
        return Column(
          key: const ValueKey('brand-step'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headline('Choose a custom clothing brand'),
            const SizedBox(height: 8),
            Text(
              'Select a premium tailoring house first. This flow now goes brand to product to customization, rather than the old appointment-only path.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ...brands.map((brand) => _brandCard(brand)),
          ],
        );
      },
    );
  }

  Widget _productStep() {
    final brand = _selectedBrand;
    if (brand == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<CustomBrandProduct>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AbzioLoadingView(
            title: 'Loading ${brand.name}',
            subtitle: 'Preparing custom products for this brand.',
          );
        }
        final products = snapshot.data ?? const <CustomBrandProduct>[];
        if (products.isEmpty) {
          return AbzioEmptyCard(
            title: 'No custom products found',
            subtitle: '${brand.name} does not have any custom catalog items configured yet.',
          );
        }
        return Column(
          key: const ValueKey('product-step'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headline('Choose a product from ${brand.name}'),
            const SizedBox(height: 8),
            Text('Pick the garment you want to customize.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            ...products.map((product) => _productCard(product)),
          ],
        );
      },
    );
  }

  Widget _customizeStep() {
    return Column(
      key: const ValueKey('customize-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline('Customize the order'),
        const SizedBox(height: 8),
        Text('Capture the styling preferences before measurement and order review.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _occasionController,
                decoration: const InputDecoration(labelText: 'Occasion', hintText: 'Wedding, Office, Festive'),
              ),
              const SizedBox(height: 14),
              _choiceRow(
                label: 'Fit preference',
                values: const ['Slim', 'Classic', 'Relaxed'],
                selected: _fitPreference,
                onSelected: (value) => setState(() => _fitPreference = value),
              ),
              const SizedBox(height: 18),
              _choiceRow(
                label: 'Delivery mode',
                values: const ['Home Trial', 'Studio Visit', 'Direct Delivery'],
                selected: _deliveryMode,
                onSelected: (value) => setState(() => _deliveryMode = value),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _styleNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Style notes',
                  hintText: 'Neckline, cuff style, lapel, embroidery, monogram, lining...',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fabricNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Fabric notes',
                  hintText: 'Fabric preference, color, season, comfort notes...',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _measurementStep() {
    return Column(
      key: const ValueKey('measurement-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline('Add measurements'),
        const SizedBox(height: 8),
        Text('Choose or create the measurement profile that should be applied to this brand order.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedMeasurement == null)
                const Text('No measurement profile selected yet.', style: TextStyle(color: AbzioTheme.grey600))
              else ...[
                Text(_selectedMeasurement!.label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metricChip('Chest', _selectedMeasurement!.chest),
                    _metricChip('Waist', _selectedMeasurement!.waist),
                    _metricChip('Shoulder', _selectedMeasurement!.shoulder),
                    _metricChip('Sleeve', _selectedMeasurement!.sleeve),
                    _metricChip('Length', _selectedMeasurement!.length),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickMeasurementProfile,
                  icon: const Icon(Icons.straighten_rounded),
                  label: Text(_selectedMeasurement == null ? 'Choose measurements' : 'Change measurements'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _scanMeasurements,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Smart measurements'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final brand = _selectedBrand;
    final product = _selectedProduct;
    final measurement = _selectedMeasurement;
    if (brand == null || product == null || measurement == null) {
      return const SizedBox.shrink();
    }
    final total = _totalPrice(product.basePrice);
    return Column(
      key: const ValueKey('review-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline('Review custom order'),
        const SizedBox(height: 8),
        Text('Everything is now in one place: brand, product, style choices, measurements, and final amount.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('Brand', brand.name),
              _summaryRow('Product', product.name),
              _summaryRow('Fit', _fitPreference),
              _summaryRow('Delivery', _deliveryMode),
              _summaryRow('Measurement Profile', measurement.label),
              _summaryRow('Occasion', _occasionController.text.trim()),
              const Divider(height: 28),
              Text('Style notes', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(_styleNotesController.text.trim().isEmpty ? 'No additional style notes' : _styleNotesController.text.trim()),
              const SizedBox(height: 16),
              Text('Fabric notes', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(_fabricNotesController.text.trim().isEmpty ? 'No additional fabric notes' : _fabricNotesController.text.trim()),
              const Divider(height: 28),
              _summaryRow('Base Price', 'Rs ${product.basePrice.toStringAsFixed(0)}'),
              _summaryRow('Customization Total', 'Rs ${total.toStringAsFixed(0)}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _brandCard(CustomBrand brand) {
    final selected = _selectedBrand?.id == brand.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedBrand = brand),
        borderRadius: BorderRadius.circular(22),
        child: _panel(
          borderColor: selected ? AbzioTheme.accentColor : AbzioTheme.grey100,
          child: Row(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AbzioTheme.grey50,
                ),
                child: brand.logoUrl.isEmpty
                    ? Icon(Icons.workspace_premium_rounded, color: AbzioTheme.accentColor)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AbzioNetworkImage(imageUrl: brand.logoUrl, fallbackLabel: brand.name),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      brand.categories.isEmpty ? 'Premium custom clothing brand' : brand.categories.join('  |  '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                color: selected ? AbzioTheme.accentColor : AbzioTheme.grey500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productCard(CustomBrandProduct product) {
    final selected = _selectedProduct?.id == product.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedProduct = product),
        borderRadius: BorderRadius.circular(22),
        child: _panel(
          borderColor: selected ? AbzioTheme.accentColor : AbzioTheme.grey100,
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: AbzioTheme.grey50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.checkroom_rounded, color: AbzioTheme.accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${product.category}  |  Rs ${product.basePrice.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                color: selected ? AbzioTheme.accentColor : AbzioTheme.grey500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceRow({
    required String label,
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values.map((value) {
            final isSelected = value == selected;
            return ChoiceChip(
              label: Text(value),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              selectedColor: AbzioTheme.accentColor,
              backgroundColor: AbzioTheme.grey100,
              labelStyle: TextStyle(color: isSelected ? Colors.black : AbzioTheme.textPrimary, fontWeight: FontWeight.w700),
              side: BorderSide(color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey300),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final order = ['brand', 'product', 'customize', 'measurements', 'review'];
    final currentIndex = order.indexOf(_currentStep);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(color: const Color(0xFF080808), border: Border(top: BorderSide(color: AbzioTheme.grey100))),
      child: Row(
        children: [
          if (currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => setState(() => _currentStep = order[currentIndex - 1]),
                child: const Text('Back'),
              ),
            ),
          if (currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : (currentIndex == order.length - 1 ? _placeOrder : _advance),
              style: ElevatedButton.styleFrom(backgroundColor: AbzioTheme.accentColor, foregroundColor: Colors.black),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(currentIndex == order.length - 1 ? 'Place Custom Order' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _advance() async {
    switch (_currentStep) {
      case 'brand':
        if (_selectedBrand == null) {
          _showSnackBar('Choose a custom clothing brand first.');
          return;
        }
        _productsFuture = _database.getCustomProductsByBrand(_selectedBrand!.id);
        setState(() {
          _selectedProduct = null;
          _currentStep = 'product';
        });
        return;
      case 'product':
        if (_selectedProduct == null) {
          _showSnackBar('Choose a product to customize.');
          return;
        }
        setState(() => _currentStep = 'customize');
        return;
      case 'customize':
        if (_occasionController.text.trim().isEmpty) {
          _showSnackBar('Add the occasion for this order.');
          return;
        }
        setState(() => _currentStep = 'measurements');
        return;
      case 'measurements':
        if (_selectedMeasurement == null) {
          _showSnackBar('Choose a measurement profile to continue.');
          return;
        }
        setState(() => _currentStep = 'review');
        return;
      default:
        return;
    }
  }

  Future<void> _pickMeasurementProfile() async {
    final result = await Navigator.of(context).push<MeasurementProfile>(
      MaterialPageRoute(builder: (_) => const CustomTailoringFlowScreen(selectionOnly: true)),
    );
    if (result != null && mounted) {
      setState(() => _selectedMeasurement = result);
    }
  }

  Future<void> _scanMeasurements() async {
    final result = await Navigator.of(context).push<MeasurementProfile>(
      MaterialPageRoute(builder: (_) => const BodyScanScreen()),
    );
    if (result != null && mounted) {
      setState(() => _selectedMeasurement = result);
    }
  }

  Future<void> _placeOrder() async {
    final user = context.read<AuthProvider>().user;
    final brand = _selectedBrand;
    final product = _selectedProduct;
    final measurement = _selectedMeasurement;
    if (user == null) {
      _showSnackBar('Sign in to place a custom order.');
      return;
    }
    if (brand == null || product == null || measurement == null) {
      _showSnackBar('Complete the brand, product, customization, and measurement steps first.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final total = _totalPrice(product.basePrice);
      final orderId = await _database.placeCustomBrandOrder(
        user: user,
        brand: brand,
        product: product,
        customizationData: {
          'occasion': _occasionController.text.trim(),
          'fit_preference': _fitPreference,
          'delivery_mode': _deliveryMode,
          'style_notes': _styleNotesController.text.trim(),
          'fabric_notes': _fabricNotesController.text.trim(),
          'measurement_mode': measurement.method,
          'measurement_profile_label': measurement.label,
          'measurement_profile_id': measurement.id,
          'measurements': measurement.toMap(),
        },
        price: total,
      );

      if (!mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Custom order placed'),
          content: Text('Your order for ${product.name} with ${brand.name} has been created.\n\nOrder ID: $orderId'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  double _totalPrice(double basePrice) {
    var total = basePrice;
    if (_fitPreference == 'Slim') {
      total += 400;
    }
    if (_fitPreference == 'Relaxed') {
      total += 250;
    }
    if (_deliveryMode == 'Home Trial') {
      total += 600;
    }
    if (_deliveryMode == 'Direct Delivery') {
      total += 200;
    }
    return total;
  }

  Widget _metricChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AbzioTheme.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Text('$label ${value.toStringAsFixed(1)} cm', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.textPrimary)),
    );
  }

  Widget _panel({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AbzioTheme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AbzioTheme.grey100),
      ),
      child: child,
    );
  }

  Widget _headline(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
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
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.grey600)),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.textPrimary))),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
