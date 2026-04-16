import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/banner_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class AdminBannersSection extends StatefulWidget {
  const AdminBannersSection({super.key});

  @override
  State<AdminBannersSection> createState() => _AdminBannersSectionState();
}

class _AdminBannersSectionState extends State<AdminBannersSection> {
  final BackendCommerceService _commerce = BackendCommerceService();
  final StorageService _storage = StorageService();

  List<BannerModel> _banners = const [];
  HomeVisualConfigModel _homeVisualConfig = const HomeVisualConfigModel();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _commerce.getBanners(includeInactive: true),
        _commerce.getHomeVisualConfig(adminView: true),
      ]);
      final banners = results[0] as List<BannerModel>;
      final config = results[1] as HomeVisualConfigModel;
      if (!mounted) {
        return;
      }
      setState(() {
        _banners = banners;
        _homeVisualConfig = config;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showBannerForm([BannerModel? initialBanner]) async {
    final result = await showDialog<_BannerFormResult>(
      context: context,
      builder: (dialogContext) => BannerFormModal(initialBanner: initialBanner),
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final actor = context.read<AuthProvider>().user;
    final actorId = actor?.id ?? '';
    final ownerId = actorId.isNotEmpty ? actorId : 'admin';

    setState(() => _saving = true);
    try {
      var banner = result.banner;
      if (result.imageFile != null) {
        final imageUrl = await _storage.uploadPickedImage(
          file: result.imageFile!,
          folder: 'homepage_banners',
          ownerId: ownerId,
          fileName: 'banner_${DateTime.now().millisecondsSinceEpoch}',
        );
        banner = banner.copyWith(imageUrl: imageUrl);
      }

      if (banner.imageUrl.trim().isEmpty) {
        throw StateError('Banner image is required.');
      }

      if (initialBanner == null) {
        await _commerce.createBanner(banner);
      } else {
        await _commerce.updateBanner(banner);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialBanner == null ? 'Banner created successfully.' : 'Banner updated successfully.',
          ),
        ),
      );
      await _loadBanners();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveHomeVisualConfig(HomeVisualConfigModel config) async {
    if (!mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _commerce.saveHomeVisualConfig(config);
      if (!mounted) {
        return;
      }
      setState(() => _homeVisualConfig = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home visuals updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleBanner(BannerModel banner, bool value) async {
    setState(() => _saving = true);
    try {
      await _commerce.updateBanner(banner.copyWith(isActive: value));
      if (!mounted) {
        return;
      }
      await _loadBanners();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteBanner(BannerModel banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete banner'),
        content: Text('Delete "${banner.title.isEmpty ? 'Untitled banner' : banner.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _commerce.deleteBanner(banner.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner deleted successfully.')),
      );
      await _loadBanners();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _showCategoryVisualForm([
    HomeCategoryVisualModel? initialVisual,
  ]) async {
    final result = await showDialog<_CategoryVisualFormResult>(
      context: context,
      builder: (dialogContext) => _CategoryVisualFormModal(initialVisual: initialVisual),
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final actor = context.read<AuthProvider>().user;
    final actorId = actor?.id ?? '';
    final ownerId = actorId.isNotEmpty ? actorId : 'admin';
    setState(() => _saving = true);
    try {
      var visual = result.visual;
      if (result.imageFile != null) {
        final imageUrl = await _storage.uploadPickedImage(
          file: result.imageFile!,
          folder: 'home_category_visuals',
          ownerId: ownerId,
          fileName: 'category_${DateTime.now().millisecondsSinceEpoch}',
        );
        visual = visual.copyWith(imageUrl: imageUrl);
      }
      if (visual.imageUrl.trim().isEmpty) {
        throw StateError('Category image is required.');
      }
      final visuals = [..._homeVisualConfig.categoryVisuals];
      final index = visuals.indexWhere((item) => item.id == visual.id);
      if (index >= 0) {
        visuals[index] = visual;
      } else {
        visuals.add(visual);
      }
      await _saveHomeVisualConfig(_homeVisualConfig.copyWith(categoryVisuals: visuals));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleCategoryVisual(
    HomeCategoryVisualModel visual,
    bool value,
  ) async {
    final visuals = _homeVisualConfig.categoryVisuals
        .map((item) => item.id == visual.id ? item.copyWith(isActive: value) : item)
        .toList();
    await _saveHomeVisualConfig(_homeVisualConfig.copyWith(categoryVisuals: visuals));
  }

  Future<void> _deleteCategoryVisual(HomeCategoryVisualModel visual) async {
    final visuals = _homeVisualConfig.categoryVisuals
        .where((item) => item.id != visual.id)
        .toList();
    await _saveHomeVisualConfig(_homeVisualConfig.copyWith(categoryVisuals: visuals));
  }

  Future<void> _showPromoBlockForm([
    HomePromoBlockModel? initialBlock,
  ]) async {
    final result = await showDialog<_PromoBlockFormResult>(
      context: context,
      builder: (dialogContext) => _PromoBlockFormModal(initialBlock: initialBlock),
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final actor = context.read<AuthProvider>().user;
    final actorId = actor?.id ?? '';
    final ownerId = actorId.isNotEmpty ? actorId : 'admin';
    setState(() => _saving = true);
    try {
      var block = result.block;
      if (result.imageFile != null) {
        final imageUrl = await _storage.uploadPickedImage(
          file: result.imageFile!,
          folder: 'home_promo_blocks',
          ownerId: ownerId,
          fileName: 'promo_${DateTime.now().millisecondsSinceEpoch}',
        );
        block = block.copyWith(imageUrl: imageUrl);
      }
      if (block.imageUrl.trim().isEmpty) {
        throw StateError('Promo image is required.');
      }
      final promoBlocks = [..._homeVisualConfig.promoBlocks];
      final index = promoBlocks.indexWhere((item) => item.id == block.id);
      if (index >= 0) {
        promoBlocks[index] = block;
      } else {
        promoBlocks.add(block);
      }
      await _saveHomeVisualConfig(_homeVisualConfig.copyWith(promoBlocks: promoBlocks));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _togglePromoBlock(HomePromoBlockModel block, bool value) async {
    final promoBlocks = _homeVisualConfig.promoBlocks
        .map((item) => item.id == block.id ? item.copyWith(isActive: value) : item)
        .toList();
    await _saveHomeVisualConfig(_homeVisualConfig.copyWith(promoBlocks: promoBlocks));
  }

  Future<void> _deletePromoBlock(HomePromoBlockModel block) async {
    final promoBlocks = _homeVisualConfig.promoBlocks
        .where((item) => item.id != block.id)
        .toList();
    await _saveHomeVisualConfig(_homeVisualConfig.copyWith(promoBlocks: promoBlocks));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Homepage banners',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AbzioTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Control the hero promotions shown on the customer home screen without shipping a new app build.',
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : () => _showBannerForm(),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add banner'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading)
          const SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Center(
            child: AbzioEmptyCard(
              title: 'Could not load banners',
              subtitle: _error!,
              ctaLabel: 'Retry',
              onTap: _loadBanners,
            ),
          )
        else
          Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Banner inventory',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (_saving)
                            Text(
                              'Saving changes...',
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Banners are sorted by order. Lower values show first on the home page.',
                        style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      if (_banners.isEmpty)
                        const AbzioEmptyCard(
                          title: 'No banners yet',
                          subtitle:
                              'Create your first homepage banner to start promoting stores, products, or categories.',
                        )
                      else
                        Column(
                          children: _banners
                              .map(
                                (banner) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: BannerRow(
                                    banner: banner,
                                    onEdit: _saving ? null : () => _showBannerForm(banner),
                                    onDelete: _saving ? null : () => _deleteBanner(banner),
                                    onToggleActive:
                                        _saving ? null : (value) => _toggleBanner(banner, value),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _HomeVisualInventoryCard(
                title: 'Category visuals',
                subtitle:
                    'Control the image-led category cards shown at the top of home. These images strongly affect premium feel.',
                emptyTitle: 'No category visuals yet',
                emptySubtitle:
                    'Add category imagery for All, Men, Women, and Kids to make discovery feel merchandised.',
                addLabel: 'Add category visual',
                onAdd: _saving ? null : () => _showCategoryVisualForm(),
                children: _homeVisualConfig.categoryVisuals
                    .map(
                      (visual) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HomeCategoryVisualRow(
                          visual: visual,
                          onEdit: _saving ? null : () => _showCategoryVisualForm(visual),
                          onDelete: _saving ? null : () => _deleteCategoryVisual(visual),
                          onToggleActive:
                              _saving ? null : (value) => _toggleCategoryVisual(visual, value),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _HomeVisualInventoryCard(
                title: 'Promo blocks',
                subtitle:
                    'Manage the editorial promo cards that sit between product rails on home without shipping a new build.',
                emptyTitle: 'No promo blocks yet',
                emptySubtitle:
                    'Add campaign cards with image, CTA, and redirect target for the home feed.',
                addLabel: 'Add promo block',
                onAdd: _saving ? null : () => _showPromoBlockForm(),
                children: _homeVisualConfig.promoBlocks
                    .map(
                      (block) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HomePromoBlockRow(
                          block: block,
                          onEdit: _saving ? null : () => _showPromoBlockForm(block),
                          onDelete: _saving ? null : () => _deletePromoBlock(block),
                          onToggleActive:
                              _saving ? null : (value) => _togglePromoBlock(block, value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
      ],
    );
  }
}

class BannerRow extends StatelessWidget {
  const BannerRow({
    super.key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final BannerModel banner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 148,
              height: 88,
              color: AbzioTheme.grey200,
              child: banner.imageUrl.isEmpty
                  ? const Icon(Icons.image_not_supported_outlined)
                  : Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      banner.title.isEmpty ? 'Untitled banner' : banner.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                    _MiniPill(
                      label: banner.isActive ? 'Active' : 'Inactive',
                      color: banner.isActive ? const Color(0xFF067647) : const Color(0xFF667085),
                    ),
                    _MiniPill(
                      label: 'Order ${banner.order}',
                      color: AbzioTheme.accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  banner.subtitle.isEmpty ? 'No subtitle provided.' : banner.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AbzioTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: 'CTA: ${banner.ctaText}'),
                    _MetaChip(label: 'Redirect: ${banner.redirectType}'),
                    _MetaChip(label: banner.redirectId.isEmpty ? 'No redirect ID' : 'ID: ${banner.redirectId}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Switch.adaptive(
                value: banner.isActive,
                onChanged: onToggleActive,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BannerFormModal extends StatefulWidget {
  const BannerFormModal({
    super.key,
    this.initialBanner,
  });

  final BannerModel? initialBanner;

  @override
  State<BannerFormModal> createState() => _BannerFormModalState();
}

class _BannerFormModalState extends State<BannerFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _ctaController = TextEditingController();
  final _redirectIdController = TextEditingController();
  final _orderController = TextEditingController();
  final _picker = ImagePicker();

  String _redirectType = 'store';
  bool _isActive = true;
  XFile? _pickedImage;
  Uint8List? _pickedPreview;

  @override
  void initState() {
    super.initState();
    final banner = widget.initialBanner;
    if (banner != null) {
      _titleController.text = banner.title;
      _subtitleController.text = banner.subtitle;
      _ctaController.text = banner.ctaText;
      _redirectIdController.text = banner.redirectId;
      _orderController.text = banner.order.toString();
      _redirectType = banner.redirectType;
      _isActive = banner.isActive;
    } else {
      _ctaController.text = 'Shop Now';
      _orderController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _ctaController.dispose();
    _redirectIdController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(imageQuality: 92, source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedImage = file;
      _pickedPreview = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_pickedImage == null && (widget.initialBanner?.imageUrl.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a banner image.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _BannerFormResult(
        banner: BannerModel(
          id: widget.initialBanner?.id ?? '',
          imageUrl: widget.initialBanner?.imageUrl ?? '',
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          ctaText: _ctaController.text.trim().isEmpty ? 'Shop Now' : _ctaController.text.trim(),
          redirectType: _redirectType,
          redirectId: _redirectIdController.text.trim(),
          order: int.tryParse(_orderController.text.trim()) ?? 0,
          isActive: _isActive,
        ),
        imageFile: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialBanner?.imageUrl ?? '';
    final hasPreview = _pickedPreview != null;

    return AlertDialog(
      title: Text(widget.initialBanner == null ? 'Add banner' : 'Edit banner'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Banner image',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    height: 176,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AbzioTheme.grey200),
                      color: const Color(0xFFF8F8F8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: hasPreview
                          ? Image.memory(_pickedPreview!, fit: BoxFit.cover)
                          : currentImage.isNotEmpty
                              ? Image.network(
                                  currentImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _UploadPlaceholder(
                                    hasImage: false,
                                  ),
                                )
                              : const _UploadPlaceholder(hasImage: false),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(hasPreview || currentImage.isNotEmpty ? 'Replace image' : 'Upload image'),
                    ),
                    if (_pickedImage != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedImage!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Top-rated stores around you',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Title is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitleController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle',
                    hintText: 'Handpicked fashion destinations',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ctaController,
                        decoration: const InputDecoration(
                          labelText: 'CTA text',
                          hintText: 'Shop Now',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Order',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _redirectType,
                  decoration: const InputDecoration(
                    labelText: 'Redirect type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'product', child: Text('product')),
                    DropdownMenuItem(value: 'store', child: Text('store')),
                    DropdownMenuItem(value: 'category', child: Text('category')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _redirectType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _redirectIdController,
                  decoration: const InputDecoration(
                    labelText: 'Redirect ID',
                    hintText: 'Product/store/category ID',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AbzioTheme.accentColor,
                  activeTrackColor: AbzioTheme.accentColor.withValues(alpha: 0.32),
                  title: const Text('Active banner'),
                  subtitle: const Text('Inactive banners stay saved but will not show on the customer app.'),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialBanner == null ? 'Create banner' : 'Save changes'),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AbzioTheme.grey200),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AbzioTheme.textSecondary,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  const _UploadPlaceholder({
    required this.hasImage,
  });

  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.image_outlined : Icons.add_photo_alternate_outlined,
            size: 32,
            color: AbzioTheme.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            hasImage ? 'Preview unavailable' : 'Tap to upload banner artwork',
            style: GoogleFonts.inter(
              color: AbzioTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerFormResult {
  const _BannerFormResult({
    required this.banner,
    required this.imageFile,
  });

  final BannerModel banner;
  final XFile? imageFile;
}

class _HomeVisualInventoryCard extends StatelessWidget {
  const _HomeVisualInventoryCard({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final String addLabel;
  final VoidCallback? onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(addLabel),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (children.isEmpty)
              AbzioEmptyCard(
                title: emptyTitle,
                subtitle: emptySubtitle,
              )
            else
              Column(children: children),
          ],
        ),
      ),
    );
  }
}

class _HomeCategoryVisualRow extends StatelessWidget {
  const _HomeCategoryVisualRow({
    required this.visual,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final HomeCategoryVisualModel visual;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 86,
              height: 86,
              child: Image.network(
                visual.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(
                      color: Color(0xFFF2EEE5),
                      child: Icon(Icons.broken_image_outlined),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      visual.label,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    _MiniPill(
                      label: visual.tab,
                      color: const Color(0xFF6941C6),
                    ),
                    _MiniPill(
                      label: visual.isActive ? 'Active' : 'Inactive',
                      color: visual.isActive
                          ? const Color(0xFF067647)
                          : const Color(0xFF667085),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: 'Icon: ${visual.icon}'),
                    _MetaChip(label: 'Order: ${visual.sortOrder}'),
                    _MetaChip(label: 'ID: ${visual.id}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Switch.adaptive(
                value: visual.isActive,
                onChanged: onToggleActive,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomePromoBlockRow extends StatelessWidget {
  const _HomePromoBlockRow({
    required this.block,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final HomePromoBlockModel block;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 148,
              height: 96,
              child: Image.network(
                block.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(
                      color: Color(0xFFF2EEE5),
                      child: Icon(Icons.broken_image_outlined),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      block.title.isEmpty ? 'Untitled promo' : block.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    _MiniPill(
                      label: 'Slot ${block.slot}',
                      color: AbzioTheme.accentColor,
                    ),
                    _MiniPill(
                      label: block.isActive ? 'Active' : 'Inactive',
                      color: block.isActive
                          ? const Color(0xFF067647)
                          : const Color(0xFF667085),
                    ),
                  ],
                ),
                if (block.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    block.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (block.eyebrow.isNotEmpty)
                      _MetaChip(label: block.eyebrow),
                    _MetaChip(label: 'CTA: ${block.ctaText}'),
                    _MetaChip(label: 'Redirect: ${block.redirectType}'),
                    _MetaChip(
                      label: block.redirectId.isEmpty
                          ? 'No redirect ID'
                          : 'ID: ${block.redirectId}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Switch.adaptive(
                value: block.isActive,
                onChanged: onToggleActive,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryVisualFormModal extends StatefulWidget {
  const _CategoryVisualFormModal({this.initialVisual});

  final HomeCategoryVisualModel? initialVisual;

  @override
  State<_CategoryVisualFormModal> createState() => _CategoryVisualFormModalState();
}

class _CategoryVisualFormModalState extends State<_CategoryVisualFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _sortOrderController = TextEditingController();
  final _picker = ImagePicker();

  static const _tabOptions = ['All', 'Men', 'Women', 'Kids', 'Atelier'];
  static const _iconOptions = [
    'category',
    'designer',
    'male',
    'female',
    'sparkle',
    'watch',
    'shirt',
    'celebration',
    'sneakers',
    'beauty',
  ];

  String _tab = 'All';
  String _icon = 'category';
  bool _isActive = true;
  XFile? _pickedImage;
  Uint8List? _pickedPreview;

  @override
  void initState() {
    super.initState();
    final visual = widget.initialVisual;
    if (visual != null) {
      _labelController.text = visual.label;
      _sortOrderController.text = visual.sortOrder.toString();
      _tab = visual.tab;
      _icon = visual.icon;
      _isActive = visual.isActive;
    } else {
      _sortOrderController.text = '0';
      _icon = _iconOptions.first;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(imageQuality: 92, source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedImage = file;
      _pickedPreview = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_pickedImage == null && (widget.initialVisual?.imageUrl.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a category image.')),
      );
      return;
    }
    final normalizedLabel = _labelController.text.trim();
    final generatedId =
        '${_tab.toLowerCase()}-${normalizedLabel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    Navigator.of(context).pop(
      _CategoryVisualFormResult(
        visual: HomeCategoryVisualModel(
          id: widget.initialVisual?.id.isNotEmpty == true ? widget.initialVisual!.id : generatedId,
          tab: _tab,
          label: normalizedLabel,
          imageUrl: widget.initialVisual?.imageUrl ?? '',
          icon: _icon,
          sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
          isActive: _isActive,
        ),
        imageFile: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialVisual?.imageUrl ?? '';
    final hasPreview = _pickedPreview != null;
    return AlertDialog(
      title: Text(widget.initialVisual == null ? 'Add category visual' : 'Edit category visual'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _VisualUploadPreview(
                  title: 'Category image',
                  pickedPreview: _pickedPreview,
                  currentImage: currentImage,
                  onPickImage: _pickImage,
                  buttonLabel: hasPreview || currentImage.isNotEmpty ? 'Replace image' : 'Upload image',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _tab,
                  decoration: const InputDecoration(labelText: 'Audience tab'),
                  items: _tabOptions
                      .map((tab) => DropdownMenuItem(value: tab, child: Text(tab)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _tab = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'Casual / atelier-noir / blazers',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Label is required.' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _icon,
                        decoration: const InputDecoration(labelText: 'Icon key'),
                        items: _iconOptions
                            .map(
                              (icon) => DropdownMenuItem(
                                value: icon,
                                child: Text(icon),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _icon = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Order'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active visual'),
                  subtitle: const Text('Inactive visuals stay saved but will not appear on home.'),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialVisual == null ? 'Create visual' : 'Save changes'),
        ),
      ],
    );
  }
}

class _PromoBlockFormModal extends StatefulWidget {
  const _PromoBlockFormModal({this.initialBlock});

  final HomePromoBlockModel? initialBlock;

  @override
  State<_PromoBlockFormModal> createState() => _PromoBlockFormModalState();
}

class _PromoBlockFormModalState extends State<_PromoBlockFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _eyebrowController = TextEditingController();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _ctaController = TextEditingController();
  final _redirectIdController = TextEditingController();
  final _slotController = TextEditingController();
  final _sortOrderController = TextEditingController();
  final _picker = ImagePicker();

  String _redirectType = 'category';
  bool _isActive = true;
  XFile? _pickedImage;
  Uint8List? _pickedPreview;

  @override
  void initState() {
    super.initState();
    final block = widget.initialBlock;
    if (block != null) {
      _eyebrowController.text = block.eyebrow;
      _titleController.text = block.title;
      _subtitleController.text = block.subtitle;
      _ctaController.text = block.ctaText;
      _redirectIdController.text = block.redirectId;
      _slotController.text = block.slot.toString();
      _sortOrderController.text = block.sortOrder.toString();
      _redirectType = block.redirectType;
      _isActive = block.isActive;
    } else {
      _ctaController.text = 'Explore';
      _slotController.text = '1';
      _sortOrderController.text = '0';
    }
  }

  @override
  void dispose() {
    _eyebrowController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _ctaController.dispose();
    _redirectIdController.dispose();
    _slotController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(imageQuality: 92, source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedImage = file;
      _pickedPreview = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_pickedImage == null && (widget.initialBlock?.imageUrl.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a promo image.')),
      );
      return;
    }
    final normalizedTitle = _titleController.text.trim();
    final generatedId =
        'promo-${normalizedTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    Navigator.of(context).pop(
      _PromoBlockFormResult(
        block: HomePromoBlockModel(
          id: widget.initialBlock?.id.isNotEmpty == true ? widget.initialBlock!.id : generatedId,
          slot: int.tryParse(_slotController.text.trim()) ?? 1,
          eyebrow: _eyebrowController.text.trim(),
          title: normalizedTitle,
          subtitle: _subtitleController.text.trim(),
          ctaText: _ctaController.text.trim().isEmpty ? 'Explore' : _ctaController.text.trim(),
          imageUrl: widget.initialBlock?.imageUrl ?? '',
          redirectType: _redirectType,
          redirectId: _redirectIdController.text.trim(),
          sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
          isActive: _isActive,
        ),
        imageFile: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialBlock?.imageUrl ?? '';
    final hasPreview = _pickedPreview != null;
    return AlertDialog(
      title: Text(widget.initialBlock == null ? 'Add promo block' : 'Edit promo block'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _VisualUploadPreview(
                  title: 'Promo image',
                  pickedPreview: _pickedPreview,
                  currentImage: currentImage,
                  onPickImage: _pickImage,
                  buttonLabel: hasPreview || currentImage.isNotEmpty ? 'Replace image' : 'Upload image',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _eyebrowController,
                  decoration: const InputDecoration(
                    labelText: 'Eyebrow',
                    hintText: 'Brand Spotlight',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'New arrivals from Mizaj',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Title is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitleController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle',
                    hintText: 'Modern occasion wear, refined for every celebration.',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ctaController,
                        decoration: const InputDecoration(labelText: 'CTA text'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: _slotController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Slot'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: _sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Order'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _redirectType,
                  decoration: const InputDecoration(labelText: 'Redirect type'),
                  items: const [
                    DropdownMenuItem(value: 'product', child: Text('product')),
                    DropdownMenuItem(value: 'store', child: Text('store')),
                    DropdownMenuItem(value: 'category', child: Text('category')),
                    DropdownMenuItem(value: 'custom', child: Text('custom')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _redirectType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _redirectIdController,
                  decoration: const InputDecoration(
                    labelText: 'Redirect ID',
                    hintText: 'Category / store / product ID',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active promo'),
                  subtitle: const Text('Inactive promos stay saved but will not appear on home.'),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialBlock == null ? 'Create promo' : 'Save changes'),
        ),
      ],
    );
  }
}

class _VisualUploadPreview extends StatelessWidget {
  const _VisualUploadPreview({
    required this.title,
    required this.pickedPreview,
    required this.currentImage,
    required this.onPickImage,
    required this.buttonLabel,
  });

  final String title;
  final Uint8List? pickedPreview;
  final String currentImage;
  final VoidCallback onPickImage;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onPickImage,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 176,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AbzioTheme.grey200),
              color: const Color(0xFFF8F8F8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: pickedPreview != null
                  ? Image.memory(pickedPreview!, fit: BoxFit.cover)
                  : currentImage.isNotEmpty
                      ? Image.network(
                          currentImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const _UploadPlaceholder(hasImage: false),
                        )
                      : const _UploadPlaceholder(hasImage: false),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.upload_outlined),
          label: Text(buttonLabel),
        ),
      ],
    );
  }
}

class _CategoryVisualFormResult {
  const _CategoryVisualFormResult({
    required this.visual,
    required this.imageFile,
  });

  final HomeCategoryVisualModel visual;
  final XFile? imageFile;
}

class _PromoBlockFormResult {
  const _PromoBlockFormResult({
    required this.block,
    required this.imageFile,
  });

  final HomePromoBlockModel block;
  final XFile? imageFile;
}
