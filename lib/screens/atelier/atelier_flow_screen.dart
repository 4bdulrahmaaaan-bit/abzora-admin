
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/soft_auth_gate.dart';
import '../../widgets/tap_scale.dart';
import 'atelier_flow_data.dart';

class AtelierFlowScreen extends StatefulWidget {
  const AtelierFlowScreen({super.key});

  @override
  State<AtelierFlowScreen> createState() => _AtelierFlowScreenState();
}

enum _Step {
  entry,
  store,
  style,
  fabric,
  design,
  measurement,
  preview,
  pricing,
  checkout,
  tracking,
}

enum _StoreTab { recommended, nearby, designers }

class _AtelierFlowScreenState extends State<AtelierFlowScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFFF6F2EA);
  static const Color _ink = Color(0xFF1E1A15);
  static const Color _muted = Color(0xFF6D655A);
  static const Color _gold = Color(0xFFBA944E);
  static const Color _line = Color(0xFFE8DEC9);
  static const Color _card = Color(0xFFFFFCF7);

  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  late final AnimationController _entryController;

  final TextEditingController _chest = TextEditingController();
  final TextEditingController _waist = TextEditingController();
  final TextEditingController _length = TextEditingController();

  _Step _step = _Step.entry;
  _StoreTab _storeTab = _StoreTab.recommended;

  int _selectedStore = 0;
  int _selectedStyle = 0;
  int _selectedFabric = 0;
  int _selectedNeck = 0;
  int _selectedSleeve = 0;
  int _selectedLength = 0;

  String _measurementMode = 'manual';
  String _materialFilter = 'All';
  String _priceFilter = 'All';
  String _occasionFilter = 'All';

  bool _frontView = true;
  bool _savedMeasurements = false;
  bool _orderPlaced = false;

  final List<String> _materials = const <String>[
    'All',
    'Cotton',
    'Linen',
    'Wool',
    'Silk',
  ];
  final List<String> _priceBands = const <String>[
    'All',
    'Under 1500',
    '1500-2500',
    '2500+',
  ];
  final List<String> _occasions = const <String>[
    'All',
    'Office',
    'Festive',
    'Formal',
    'Wedding',
  ];

  final List<String> _necks = const <String>['Classic', 'Band', 'Cutaway'];
  final List<String> _sleeves = const <String>['Full', '3/4', 'Short'];
  final List<String> _lengths = const <String>['Regular', 'Longline', 'Cropped'];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _chest.dispose();
    _waist.dispose();
    _length.dispose();
    super.dispose();
  }

  List<AtelierStore> get _storesForTab {
    switch (_storeTab) {
      case _StoreTab.recommended:
        return atelierRecommendedStores;
      case _StoreTab.nearby:
        return atelierNearbyStores;
      case _StoreTab.designers:
        return atelierDesignerStores;
    }
  }

  int get _basePrice => atelierStyles[_selectedStyle].basePrice;
  int get _fabricDelta => atelierFabrics[_selectedFabric].delta;
  int get _stitching => (_basePrice * 0.35).round();
  int get _addons {
    return (_selectedNeck * 180) +
        (_selectedSleeve * 140) +
        (_selectedLength * 160) +
        (_measurementMode == 'manual' ? 100 : 0);
  }

  int get _total => _basePrice + _fabricDelta + _stitching + _addons;

  List<int> get _filteredFabricIndexes {
    return List<int>.generate(atelierFabrics.length, (int i) => i).where((int i) {
      final fabric = atelierFabrics[i];
      if (_materialFilter != 'All' && fabric.material != _materialFilter) {
        return false;
      }
      if (_occasionFilter != 'All' && fabric.occasion != _occasionFilter) {
        return false;
      }
      if (_priceFilter == 'Under 1500' && fabric.delta >= 1500) {
        return false;
      }
      if (_priceFilter == '1500-2500' &&
          (fabric.delta < 1500 || fabric.delta > 2500)) {
        return false;
      }
      if (_priceFilter == '2500+' && fabric.delta < 2500) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  String get _cta => switch (_step) {
        _Step.entry => 'Enter Atelier',
        _Step.store => 'Start with this Boutique',
        _Step.style => 'Continue to Fabrics',
        _Step.fabric => 'Continue to Design',
        _Step.design => 'Continue to Measurements',
        _Step.measurement => 'Continue to Preview',
        _Step.preview => 'Review Pricing',
        _Step.pricing => 'Proceed to Checkout',
        _Step.checkout => 'Place Atelier Order',
        _Step.tracking => 'Back to Home',
      };

  Future<void> _next() async {
    if (_step == _Step.checkout) {
      await _placeOrder();
      return;
    }
    if (_step == _Step.tracking) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step = _Step.values[_step.index + 1]);
  }

  void _back() {
    if (_step == _Step.entry) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step = _Step.values[_step.index - 1]);
  }

  Future<void> _saveMeasurements() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      final ok = await SoftAuthGate.ensureAuthenticated(
        context,
        intentLabel: 'Save measurements to your Atelier profile',
        trigger: AuthPromptTrigger.cart,
        promptStyle: AuthPromptStyle.softSheet,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _savedMeasurements = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Measurements saved to your profile.',
          style: GoogleFonts.manrope(),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      final ok = await SoftAuthGate.ensureAuthenticated(
        context,
        intentLabel: 'Place your atelier order',
        trigger: AuthPromptTrigger.orders,
        promptStyle: AuthPromptStyle.softSheet,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _orderPlaced = true;
      _step = _Step.tracking;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.03, 0.02),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<_Step>(_step),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _line),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _cta,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Abianzo Atelier',
                      style: GoogleFonts.cormorantGaramond(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 32,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Premium guided tailoring • Step ${_step.index + 1} of ${_Step.values.length}',
                      style: GoogleFonts.manrope(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_step.index + 1) / _Step.values.length,
              minHeight: 6,
              backgroundColor: _line,
              valueColor: const AlwaysStoppedAnimation<Color>(_gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.entry:
        return _entryStep();
      case _Step.store:
        return _storeStep();
      case _Step.style:
        return _styleStep();
      case _Step.fabric:
        return _fabricStep();
      case _Step.design:
        return _designStep();
      case _Step.measurement:
        return _measurementStep();
      case _Step.preview:
        return _previewStep();
      case _Step.pricing:
        return _pricingStep();
      case _Step.checkout:
        return _checkoutStep();
      case _Step.tracking:
        return _trackingStep();
    }
  }

  Widget _entryStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AnimatedBuilder(
          animation: _entryController,
          builder: (BuildContext context, Widget? child) {
            final t = Curves.easeOutCubic.transform(_entryController.value);
            return Opacity(
              opacity: t,
              child: Transform.scale(scale: 1.08 - (0.08 * t), child: child),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _image(
                'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.56),
                      Colors.black.withValues(alpha: 0.76),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Private Atelier\nJourney',
                    style: GoogleFonts.cormorantGaramond(
                      color: Colors.white,
                      fontSize: 52,
                      height: 0.92,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storeStep() {
    final tabs = <(_StoreTab, String)>[
      (_StoreTab.recommended, 'Recommended'),
      (_StoreTab.nearby, 'Nearby'),
      (_StoreTab.designers, 'Designers'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tabs.map((tab) {
            final selected = tab.$1 == _storeTab;
            return ChoiceChip(
              label: Text(tab.$2, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              selected: selected,
              showCheckmark: false,
              side: BorderSide(color: selected ? _gold : _line),
              selectedColor: _gold.withValues(alpha: 0.16),
              backgroundColor: _card,
              onSelected: (bool value) {
                if (!value) return;
                setState(() {
                  _storeTab = tab.$1;
                  _selectedStore = 0;
                });
              },
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(_storesForTab.length, (int index) {
          final store = _storesForTab[index];
          final selected = _selectedStore == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TapScale(
              onTap: () => setState(() => _selectedStore = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 188,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? _gold : _line,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: _image(store.image)),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.66),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(store.name, style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(store.tagline, style: GoogleFonts.manrope(color: Colors.white.withValues(alpha: 0.88), fontSize: 12)),
                          Row(
                            children: <Widget>[
                              Text('★ ${store.rating}', style: GoogleFonts.manrope(color: Colors.white, fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(store.distance, style: GoogleFonts.manrope(color: Colors.white, fontSize: 12))),
                              Text('From ${_money.format(store.startPrice)}', style: GoogleFonts.manrope(color: const Color(0xFFFFD88C), fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _styleStep() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: atelierStyles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.74,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (BuildContext context, int i) {
        final style = atelierStyles[i];
        final selected = _selectedStyle == i;
        return TapScale(
          onTap: () => setState(() => _selectedStyle = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? _gold : _line, width: selected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _image(style.image)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('${style.name}\n${style.subtitle}', style: GoogleFonts.manrope(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fabricStep() {
    final list = _filteredFabricIndexes;
    if (!list.contains(_selectedFabric) && list.isNotEmpty) {
      _selectedFabric = list.first;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: <Widget>[
        _chipFilters(_materials, _materialFilter, (v) => setState(() => _materialFilter = v)),
        _chipFilters(_priceBands, _priceFilter, (v) => setState(() => _priceFilter = v)),
        _chipFilters(_occasions, _occasionFilter, (v) => setState(() => _occasionFilter = v)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (BuildContext context, int j) {
            final i = list[j];
            final fabric = atelierFabrics[i];
            final selected = _selectedFabric == i;
            return TapScale(
              onTap: () => setState(() => _selectedFabric = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: selected ? _gold : _line, width: selected ? 2 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(child: _image(fabric.image)),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(alpha: 0.45),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(4),
                              ),
                              onPressed: () => _zoomFabric(fabric),
                              icon: const Icon(Icons.zoom_in_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('${fabric.name}\n${fabric.description}', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(color: _ink, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _designStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          _optionCard('Neckline', _necks, _selectedNeck, (v) => setState(() => _selectedNeck = v)),
          const SizedBox(height: 12),
          _optionCard('Sleeve', _sleeves, _selectedSleeve, (v) => setState(() => _selectedSleeve = v)),
          const SizedBox(height: 12),
          _optionCard('Length', _lengths, _selectedLength, (v) => setState(() => _selectedLength = v)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
            child: Text('Live preview updates as you customize.', style: GoogleFonts.manrope(color: _muted, fontWeight: FontWeight.w600)),
          ),
        ],
      );

  Widget _measurementStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          _measurementCard('Manual Input', 'Enter chest, waist, and length', Icons.straighten_rounded, _measurementMode == 'manual', () => setState(() => _measurementMode = 'manual')),
          _measurementCard('Saved Profile', 'Use previous verified measurements', Icons.bookmark_rounded, _measurementMode == 'saved', () => setState(() => _measurementMode = 'saved')),
          _measurementCard('AI Body Scan', 'Coming soon for precision scan', Icons.camera_alt_rounded, _measurementMode == 'ai', () {}, enabled: false),
          if (_measurementMode == 'manual')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
              child: Column(
                children: <Widget>[
                  _inputField('Chest (inches)', _chest),
                  const SizedBox(height: 8),
                  _inputField('Waist (inches)', _waist),
                  const SizedBox(height: 8),
                  _inputField('Length (inches)', _length),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saveMeasurements,
            icon: const Icon(Icons.bookmark_add_rounded),
            style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            label: Text(_savedMeasurements ? 'Measurements Saved' : 'Save Measurements (Login Required)', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      );

  Widget _previewStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          Container(
            height: 360,
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _image(atelierStyles[_selectedStyle].image),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Text(_frontView ? 'Front View' : 'Back View', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: _toggle('Front', _frontView, () => setState(() => _frontView = true))),
              const SizedBox(width: 8),
              Expanded(child: _toggle('Back', !_frontView, () => setState(() => _frontView = false))),
              const SizedBox(width: 8),
              Expanded(
                child: _toggle('3D Try-On', false, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('3D try-on can be enabled as next phase.', style: GoogleFonts.manrope())),
                  );
                }),
              ),
            ],
          ),
        ],
      );

  Widget _pricingStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          _priceRow('Garment Base (${atelierStyles[_selectedStyle].name})', _basePrice),
          _priceRow('Fabric (${atelierFabrics[_selectedFabric].name})', _fabricDelta),
          _priceRow('Stitching & Tailoring', _stitching),
          _priceRow('Add-ons & Measurement', _addons),
          const Divider(height: 28, color: _line),
          _priceRow('Total', _total, highlight: true),
        ],
      );

  Widget _checkoutStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          _checkoutTile(Icons.storefront_rounded, 'Boutique', _storesForTab[_selectedStore].name),
          _checkoutTile(Icons.schedule_rounded, 'Delivery Timeline', '10-14 days including fit confirmation'),
          _checkoutTile(Icons.payments_rounded, 'Order Value', _money.format(_total)),
          Text('Browsing stays open without login. Login is required only for saving measurements and placing order.', style: GoogleFonts.manrope(color: _muted, fontSize: 12)),
        ],
      );

  Widget _trackingStep() {
    final milestones = <AtelierTrackingMilestone>[
      AtelierTrackingMilestone(title: 'Fabric Cutting', completed: _orderPlaced),
      AtelierTrackingMilestone(title: 'Stitching', completed: _orderPlaced),
      AtelierTrackingMilestone(title: 'Finishing', completed: _orderPlaced),
      const AtelierTrackingMilestone(title: 'Delivery', completed: false),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Order #ATL-Abianzo-2401', style: GoogleFonts.manrope(color: _ink, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (int i = 0; i < milestones.length; i++) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(milestones[i].completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: milestones[i].completed ? _gold : _muted, size: 20),
                    const SizedBox(width: 10),
                    Text(milestones[i].title, style: GoogleFonts.manrope(color: milestones[i].completed ? _ink : _muted, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (i != milestones.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 9, top: 4, bottom: 6),
                    child: Container(width: 2, height: 20, color: _line),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipFilters(List<String> opts, String selected, ValueChanged<String> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: opts.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int i) {
            final option = opts[i];
            final isSelected = option == selected;
            return ChoiceChip(
              label: Text(option, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12)),
              selected: isSelected,
              showCheckmark: false,
              side: BorderSide(color: isSelected ? _gold : _line),
              selectedColor: _gold.withValues(alpha: 0.16),
              backgroundColor: _card,
              onSelected: (bool value) {
                if (value) onSelect(option);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _optionCard(String title, List<String> options, int selected, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: GoogleFonts.manrope(color: _ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(options.length, (int i) {
              final isSelected = selected == i;
              return ChoiceChip(
                label: Text(options[i], style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12)),
                selected: isSelected,
                showCheckmark: false,
                side: BorderSide(color: isSelected ? _gold : _line),
                selectedColor: _gold.withValues(alpha: 0.16),
                backgroundColor: _card,
                onSelected: (bool value) {
                  if (value) onChanged(i);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _measurementCard(String title, String subtitle, IconData icon, bool selected, VoidCallback onTap, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TapScale(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? _gold : _line, width: selected ? 2 : 1),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: _ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: GoogleFonts.manrope(color: _ink, fontWeight: FontWeight.w800)),
                      Text(subtitle, style: GoogleFonts.manrope(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.manrope(color: _ink, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(color: _muted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold)),
      ),
    );
  }

  Widget _toggle(String label, bool selected, VoidCallback onTap) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: selected ? _gold.withValues(alpha: 0.16) : _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? _gold : _line)),
        child: Center(child: Text(label, style: GoogleFonts.manrope(color: selected ? _ink : _muted, fontWeight: FontWeight.w700, fontSize: 12))),
      ),
    );
  }

  Widget _priceRow(String label, int amount, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: GoogleFonts.manrope(color: highlight ? _ink : _muted, fontWeight: highlight ? FontWeight.w800 : FontWeight.w600, fontSize: highlight ? 16 : 13))),
          Text(_money.format(amount), style: GoogleFonts.manrope(color: highlight ? _gold : _ink, fontWeight: FontWeight.w800, fontSize: highlight ? 24 : 14)),
        ],
      ),
    );
  }

  Widget _checkoutTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
      child: Row(
        children: <Widget>[
          Icon(icon, color: _ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: GoogleFonts.manrope(color: _muted, fontSize: 12)),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(color: _ink, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _zoomFabric(AtelierFabric fabric) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: <Widget>[
              SizedBox(height: 430, child: _image(fabric.image)),
              Positioned(
                right: 10,
                top: 10,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${fabric.name} • ${fabric.description}', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String _) =>
          const ColoredBox(color: Color(0xFFEADFCF)),
      errorWidget: (BuildContext context, String _, Object error) => const ColoredBox(
        color: Color(0xFFEADFCF),
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF7E7465)),
      ),
    );
  }
}

