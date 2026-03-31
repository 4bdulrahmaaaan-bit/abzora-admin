import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/category_management_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class AdminCategoriesSection extends StatefulWidget {
  const AdminCategoriesSection({super.key});

  @override
  State<AdminCategoriesSection> createState() => _AdminCategoriesSectionState();
}

class _AdminCategoriesSectionState extends State<AdminCategoriesSection> {
  final BackendCommerceService _commerce = BackendCommerceService();
  final StorageService _storage = StorageService();

  List<CategoryManagementModel> _categories = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _commerce.getAdminCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
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

  Future<String> _uploadIcon(XFile file) async {
    final actor = context.read<AuthProvider>().user;
    final actorId = actor?.id ?? '';
    final ownerId = actorId.isNotEmpty ? actorId : 'admin';
    return _storage.uploadPickedImage(
      file: file,
      folder: 'category_icons',
      ownerId: ownerId,
      fileName: 'category_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _showCategoryForm([CategoryManagementModel? initialCategory]) async {
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (dialogContext) => CategoryFormModal(initialCategory: initialCategory),
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      var category = result.category;
      if (result.iconFile != null) {
        final iconUrl = await _uploadIcon(result.iconFile!);
        category = category.copyWith(icon: iconUrl);
      }

      if (initialCategory == null) {
        await _commerce.createCategory(category);
      } else {
        await _commerce.updateCategory(category);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialCategory == null
                ? 'Category created successfully.'
                : 'Category updated successfully.',
          ),
        ),
      );
      await _loadCategories();
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

  Future<void> _deleteCategory(CategoryManagementModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category'),
        content: Text('Delete "${category.name}" and all of its subcategories?'),
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
      await _commerce.deleteCategory(category.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully.')),
      );
      await _loadCategories();
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

  Future<void> _toggleCategory(CategoryManagementModel category, bool isActive) async {
    setState(() => _saving = true);
    try {
      await _commerce.toggleCategoryStatus(categoryId: category.id, isActive: isActive);
      if (!mounted) {
        return;
      }
      await _loadCategories();
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

  Future<void> _showSubcategoryForm({
    required CategoryManagementModel category,
    SubcategoryManagementModel? initialSubcategory,
  }) async {
    final result = await showDialog<_SubcategoryFormResult>(
      context: context,
      builder: (dialogContext) => SubcategoryFormModal(
        categoryName: category.name,
        initialSubcategory: initialSubcategory,
      ),
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      var subcategory = result.subcategory;
      if (result.iconFile != null) {
        final iconUrl = await _uploadIcon(result.iconFile!);
        subcategory = subcategory.copyWith(icon: iconUrl);
      }

      if (initialSubcategory == null) {
        await _commerce.addSubcategory(
          categoryId: category.id,
          subcategory: subcategory,
        );
      } else {
        await _commerce.updateSubcategory(
          categoryId: category.id,
          subcategory: subcategory,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialSubcategory == null
                ? 'Subcategory created successfully.'
                : 'Subcategory updated successfully.',
          ),
        ),
      );
      await _loadCategories();
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

  Future<void> _deleteSubcategory({
    required CategoryManagementModel category,
    required SubcategoryManagementModel subcategory,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete subcategory'),
        content: Text('Delete "${subcategory.name}" from ${category.name}?'),
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
      await _commerce.deleteSubcategory(
        categoryId: category.id,
        subcategoryId: subcategory.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subcategory deleted successfully.')),
      );
      await _loadCategories();
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

  Future<void> _toggleSubcategory({
    required CategoryManagementModel category,
    required SubcategoryManagementModel subcategory,
    required bool isActive,
  }) async {
    setState(() => _saving = true);
    try {
      await _commerce.updateSubcategory(
        categoryId: category.id,
        subcategory: subcategory.copyWith(isActive: isActive),
      );
      if (!mounted) {
        return;
      }
      await _loadCategories();
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
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category management',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AbzioTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Organize top-level categories and subcategories shown across customer discovery, category tabs, and navigation rails.',
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
              onPressed: _saving ? null : () => _showCategoryForm(),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add category'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading)
          const SizedBox(
            height: 320,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Center(
            child: AbzioEmptyCard(
              title: 'Could not load categories',
              subtitle: _error!,
              ctaLabel: 'Retry',
              onTap: _loadCategories,
            ),
          )
        else
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
                          'Category inventory',
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
                    'Lower order values appear first. Each category can contain an ordered set of subcategories.',
                    style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  if (_categories.isEmpty)
                    const AbzioEmptyCard(
                      title: 'No categories yet',
                      subtitle: 'Create your first category to start powering customer navigation and storefront filtering.',
                    )
                  else
                    Column(
                      children: _categories
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CategoryCard(
                                category: category,
                                saving: _saving,
                                onEdit: () => _showCategoryForm(category),
                                onDelete: () => _deleteCategory(category),
                                onAddSubcategory: () =>
                                    _showSubcategoryForm(category: category),
                                onToggleActive: (value) =>
                                    _toggleCategory(category, value),
                                onEditSubcategory: (subcategory) =>
                                    _showSubcategoryForm(
                                  category: category,
                                  initialSubcategory: subcategory,
                                ),
                                onDeleteSubcategory: (subcategory) =>
                                    _deleteSubcategory(
                                  category: category,
                                  subcategory: subcategory,
                                ),
                                onToggleSubcategory: (subcategory, value) =>
                                    _toggleSubcategory(
                                  category: category,
                                  subcategory: subcategory,
                                  isActive: value,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubcategory,
    required this.onToggleActive,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
    required this.onToggleSubcategory,
  });

  final CategoryManagementModel category;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddSubcategory;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<SubcategoryManagementModel> onEditSubcategory;
  final ValueChanged<SubcategoryManagementModel> onDeleteSubcategory;
  final void Function(SubcategoryManagementModel subcategory, bool isActive)
      onToggleSubcategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconPreview(
                imageUrl: category.icon,
                size: 72,
                fallbackIcon: Icons.category_outlined,
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
                          category.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AbzioTheme.textPrimary,
                          ),
                        ),
                        _AdminPill(
                          label: category.isActive ? 'Active' : 'Inactive',
                          color: category.isActive
                              ? const Color(0xFF067647)
                              : const Color(0xFF667085),
                        ),
                        _AdminPill(
                          label: 'Order ${category.order}',
                          color: AbzioTheme.accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Slug: ${category.slug}',
                      style: GoogleFonts.inter(
                        color: AbzioTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: saving ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: saving ? null : onDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB42318),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: saving ? null : onAddSubcategory,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Subcategory'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Switch.adaptive(
                value: category.isActive,
                onChanged: saving ? null : onToggleActive,
                activeTrackColor: AbzioTheme.accentColor.withValues(alpha: 0.45),
                activeThumbColor: AbzioTheme.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SubcategoryList(
            subcategories: category.subcategories,
            saving: saving,
            onEdit: onEditSubcategory,
            onDelete: onDeleteSubcategory,
            onToggleActive: onToggleSubcategory,
          ),
        ],
      ),
    );
  }
}

class SubcategoryList extends StatelessWidget {
  const SubcategoryList({
    super.key,
    required this.subcategories,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final List<SubcategoryManagementModel> subcategories;
  final bool saving;
  final ValueChanged<SubcategoryManagementModel> onEdit;
  final ValueChanged<SubcategoryManagementModel> onDelete;
  final void Function(SubcategoryManagementModel subcategory, bool isActive)
      onToggleActive;

  @override
  Widget build(BuildContext context) {
    if (subcategories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AbzioTheme.grey200),
        ),
        child: Text(
          'No subcategories yet. Add one to structure this category.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subcategories',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...subcategories.asMap().entries.map((entry) {
            final subcategory = entry.value;
            final isLast = entry.key == subcategories.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AbzioTheme.grey200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconPreview(
                      imageUrl: subcategory.icon,
                      size: 48,
                      fallbackIcon: Icons.label_outline_rounded,
                    ),
                    const SizedBox(width: 12),
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
                                subcategory.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AbzioTheme.textPrimary,
                                ),
                              ),
                              _AdminPill(
                                label: subcategory.isActive ? 'Active' : 'Inactive',
                                color: subcategory.isActive
                                    ? const Color(0xFF067647)
                                    : const Color(0xFF667085),
                              ),
                              _AdminPill(
                                label: 'Order ${subcategory.order}',
                                color: AbzioTheme.accentColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Slug: ${subcategory.slug}',
                            style: GoogleFonts.inter(
                              color: AbzioTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Switch.adaptive(
                          value: subcategory.isActive,
                          onChanged: saving
                              ? null
                              : (value) => onToggleActive(subcategory, value),
                          activeTrackColor:
                              AbzioTheme.accentColor.withValues(alpha: 0.45),
                          activeThumbColor: AbzioTheme.accentColor,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit subcategory',
                              onPressed: saving ? null : () => onEdit(subcategory),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Delete subcategory',
                              onPressed: saving ? null : () => onDelete(subcategory),
                              color: const Color(0xFFB42318),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class CategoryFormModal extends StatefulWidget {
  const CategoryFormModal({
    super.key,
    this.initialCategory,
  });

  final CategoryManagementModel? initialCategory;

  @override
  State<CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends State<CategoryFormModal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _slugEditedManually = false;
  bool _isActive = true;
  XFile? _pickedIcon;
  Uint8List? _pickedPreview;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    _nameController.addListener(_syncSlug);
    _slugController.addListener(_trackManualSlugEdit);
    if (category != null) {
      _nameController.text = category.name;
      _slugController.text = category.slug;
      _orderController.text = category.order.toString();
      _isActive = category.isActive;
      _slugEditedManually = true;
    } else {
      _orderController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncSlug);
    _slugController.removeListener(_trackManualSlugEdit);
    _nameController.dispose();
    _slugController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _trackManualSlugEdit() {
    final generated = _slugify(_nameController.text);
    if (_slugController.text.trim() != generated) {
      _slugEditedManually = true;
    }
  }

  void _syncSlug() {
    if (_slugEditedManually) {
      return;
    }
    final next = _slugify(_nameController.text);
    _slugController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      imageQuality: 92,
      source: ImageSource.gallery,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedIcon = file;
      _pickedPreview = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CategoryFormResult(
        category: CategoryManagementModel(
          id: widget.initialCategory?.id ?? '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          icon: widget.initialCategory?.icon ?? '',
          order: int.tryParse(_orderController.text.trim()) ?? 0,
          isActive: _isActive,
          subcategories: widget.initialCategory?.subcategories ?? const [],
        ),
        iconFile: _pickedIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialCategory?.icon ?? '';

    return AlertDialog(
      title: Text(widget.initialCategory == null ? 'Add category' : 'Edit category'),
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
                  'Category icon',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _ImagePickerPreview(
                  imageUrl: currentImage,
                  previewBytes: _pickedPreview,
                  onTap: _pickImage,
                  height: 176,
                  fallbackIcon: Icons.category_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        _pickedPreview != null || currentImage.isNotEmpty
                            ? 'Replace icon'
                            : 'Upload icon',
                      ),
                    ),
                    if (_pickedIcon != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedIcon!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Men',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Name is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    hintText: 'men',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Slug is required.' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Order'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        activeTrackColor:
                            AbzioTheme.accentColor.withValues(alpha: 0.45),
                        activeThumbColor: AbzioTheme.accentColor,
                        title: const Text('Active'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
          child: Text(widget.initialCategory == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}

class SubcategoryFormModal extends StatefulWidget {
  const SubcategoryFormModal({
    super.key,
    required this.categoryName,
    this.initialSubcategory,
  });

  final String categoryName;
  final SubcategoryManagementModel? initialSubcategory;

  @override
  State<SubcategoryFormModal> createState() => _SubcategoryFormModalState();
}

class _SubcategoryFormModalState extends State<SubcategoryFormModal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _slugEditedManually = false;
  bool _isActive = true;
  XFile? _pickedIcon;
  Uint8List? _pickedPreview;

  @override
  void initState() {
    super.initState();
    final subcategory = widget.initialSubcategory;
    _nameController.addListener(_syncSlug);
    _slugController.addListener(_trackManualSlugEdit);
    if (subcategory != null) {
      _nameController.text = subcategory.name;
      _slugController.text = subcategory.slug;
      _orderController.text = subcategory.order.toString();
      _isActive = subcategory.isActive;
      _slugEditedManually = true;
    } else {
      _orderController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncSlug);
    _slugController.removeListener(_trackManualSlugEdit);
    _nameController.dispose();
    _slugController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _trackManualSlugEdit() {
    final generated = _slugify(_nameController.text);
    if (_slugController.text.trim() != generated) {
      _slugEditedManually = true;
    }
  }

  void _syncSlug() {
    if (_slugEditedManually) {
      return;
    }
    final next = _slugify(_nameController.text);
    _slugController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      imageQuality: 92,
      source: ImageSource.gallery,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedIcon = file;
      _pickedPreview = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _SubcategoryFormResult(
        subcategory: SubcategoryManagementModel(
          id: widget.initialSubcategory?.id ?? '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          icon: widget.initialSubcategory?.icon ?? '',
          order: int.tryParse(_orderController.text.trim()) ?? 0,
          isActive: _isActive,
        ),
        iconFile: _pickedIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialSubcategory?.icon ?? '';

    return AlertDialog(
      title: Text(
        widget.initialSubcategory == null
            ? 'Add subcategory'
            : 'Edit subcategory',
      ),
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
                  'Parent category: ${widget.categoryName}',
                  style: GoogleFonts.inter(
                    color: AbzioTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Subcategory icon',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _ImagePickerPreview(
                  imageUrl: currentImage,
                  previewBytes: _pickedPreview,
                  onTap: _pickImage,
                  height: 160,
                  fallbackIcon: Icons.label_outline_rounded,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        _pickedPreview != null || currentImage.isNotEmpty
                            ? 'Replace icon'
                            : 'Upload icon',
                      ),
                    ),
                    if (_pickedIcon != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedIcon!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Casual',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Name is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    hintText: 'casual',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Slug is required.' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Order'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        activeTrackColor:
                            AbzioTheme.accentColor.withValues(alpha: 0.45),
                        activeThumbColor: AbzioTheme.accentColor,
                        title: const Text('Active'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
          child: Text(widget.initialSubcategory == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.imageUrl,
    required this.previewBytes,
    required this.onTap,
    required this.height,
    required this.fallbackIcon,
  });

  final String imageUrl;
  final Uint8List? previewBytes;
  final VoidCallback onTap;
  final double height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AbzioTheme.grey200),
          color: const Color(0xFFF8F8F8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: previewBytes != null
              ? Image.memory(previewBytes!, fit: BoxFit.cover)
              : imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _UploadPlaceholder(fallbackIcon: fallbackIcon),
                    )
                  : _UploadPlaceholder(fallbackIcon: fallbackIcon),
        ),
      ),
    );
  }
}

class _IconPreview extends StatelessWidget {
  const _IconPreview({
    required this.imageUrl,
    required this.size,
    required this.fallbackIcon,
  });

  final String imageUrl;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        color: AbzioTheme.grey200,
        child: imageUrl.isEmpty
            ? Icon(fallbackIcon, color: AbzioTheme.textSecondary)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(fallbackIcon, color: AbzioTheme.textSecondary),
              ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  const _UploadPlaceholder({
    required this.fallbackIcon,
  });

  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fallbackIcon, size: 30, color: AbzioTheme.textSecondary),
          const SizedBox(height: 10),
          Text(
            'Upload image',
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

class _AdminPill extends StatelessWidget {
  const _AdminPill({
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

class _CategoryFormResult {
  const _CategoryFormResult({
    required this.category,
    required this.iconFile,
  });

  final CategoryManagementModel category;
  final XFile? iconFile;
}

class _SubcategoryFormResult {
  const _SubcategoryFormResult({
    required this.subcategory,
    required this.iconFile,
  });

  final SubcategoryManagementModel subcategory;
  final XFile? iconFile;
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
