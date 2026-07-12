import 'dart:async';
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
import '../../utils/app_error_text.dart';
import '../../widgets/state_views.dart';

class AdminCategoriesSection extends StatefulWidget {
  const AdminCategoriesSection({super.key});

  @override
  State<AdminCategoriesSection> createState() => _AdminCategoriesSectionState();
}

class _AdminCategoriesSectionState extends State<AdminCategoriesSection> {
  final BackendCommerceService _commerce = BackendCommerceService();
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<CategoryManagementModel> _categories = const [];
  List<CategoryManagementModel> _parentOptions = const [];
  bool _loading = true;
  bool _loadingParents = false;
  bool _saving = false;
  String? _error;
  int _page = 1;
  int _limit = 12;
  int _totalPages = 1;
  int _totalCount = 0;
  String _statusFilter = 'all';
  String _parentFilter = 'all';
  String _tabFilter = 'all';
  String _featuredFilter = 'all';
  bool _showOnHomeFilter = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadParentOptions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) {
        _page = page;
      }
    });
    try {
      final result = await _commerce.getAdminCategories(
        page: page ?? _page,
        limit: _limit,
        search: _searchController.text,
        status: _statusFilter,
        parentId: _parentFilter,
        tabType: _tabFilter,
        featured: _featuredFilter,
        showOnHome: _showOnHomeFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = result.items;
        _page = result.page;
        _limit = result.limit;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = AppErrorText.from(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadParentOptions() async {
    setState(() => _loadingParents = true);
    try {
      final result = await _commerce.getAdminCategories(
        page: 1,
        limit: 200,
        status: 'all',
        featured: 'all',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _parentOptions = result.items
            .where((category) => category.parentId.isEmpty)
            .toList();
        _loadingParents = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingParents = false;
      });
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) {
        _loadCategories(page: 1);
      }
    });
  }

  Future<String> _uploadPickedImage(
    XFile file, {
    required String folder,
  }) async {
    final actor = context.read<AuthProvider>().user;
    final actorId = actor?.id ?? '';
    final ownerId = actorId.isNotEmpty ? actorId : 'admin';
    return _storage.uploadPickedImage(
      file: file,
      folder: folder,
      ownerId: ownerId,
      fileName: 'category_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _showCategoryForm([
    CategoryManagementModel? initialCategory,
  ]) async {
    if (_parentOptions.isEmpty && !_loadingParents) {
      await _loadParentOptions();
    }
    if (!mounted) {
      return;
    }
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (dialogContext) => CategoryFormModal(
        initialCategory: initialCategory,
        parentOptions: _parentOptions,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      var category = result.category;
      if (result.imageFile != null) {
        final imageUrl = await _uploadPickedImage(
          result.imageFile!,
          folder: 'category_icons',
        );
        category = category.copyWith(image: imageUrl);
      }
      if (result.bannerFile != null) {
        final bannerUrl = await _uploadPickedImage(
          result.bannerFile!,
          folder: 'category_icons',
        );
        category = category.copyWith(bannerImage: bannerUrl);
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
      await _loadCategories(page: _page);
      await _loadParentOptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
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
        content: Text(
          'Soft delete "${category.name}"? It will remain recoverable in the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
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
      await _loadCategories(page: _page);
      await _loadParentOptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleCategory(
    CategoryManagementModel category,
    bool isActive,
  ) async {
    setState(() => _saving = true);
    try {
      await _commerce.toggleCategoryStatus(
        categoryId: category.id,
        isActive: isActive,
      );
      if (!mounted) {
        return;
      }
      await _loadCategories(page: _page);
      await _loadParentOptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleFeatured(
    CategoryManagementModel category,
    bool isFeatured,
  ) async {
    setState(() => _saving = true);
    try {
      await _commerce.toggleCategoryFeatured(
        categoryId: category.id,
        isFeatured: isFeatured,
      );
      if (!mounted) {
        return;
      }
      await _loadCategories(page: _page);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleShowOnHome(
    CategoryManagementModel category,
    bool value,
  ) async {
    setState(() => _saving = true);
    try {
      await _commerce.updateCategory(category.copyWith(showOnHome: value));
      if (!mounted) {
        return;
      }
      await _loadCategories(page: _page);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _persistOrder(List<CategoryManagementModel> reordered) async {
    setState(() => _saving = true);
    try {
      final normalized = reordered
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(sortOrder: entry.key))
          .toList();
      await _commerce.reorderCategories(normalized);
      if (!mounted) {
        return;
      }
      await _loadCategories(page: _page);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<CategoryManagementModel> _sortedCategories() {
    final items = [..._categories];
    items.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return items;
  }

  CategoryManagementModel? _categoryById(String id) {
    for (final category in _parentOptions) {
      if (category.id == id) {
        return category;
      }
    }
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = 'all';
      _parentFilter = 'all';
      _tabFilter = 'all';
      _featuredFilter = 'all';
      _showOnHomeFilter = false;
    });
    _loadCategories(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _sortedCategories();
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
              constraints: const BoxConstraints(maxWidth: 720),
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
                    'Manage Abianzo categories, parent relationships, premium imagery, home placement, featured flags, and sort order from one place.',
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
        const SizedBox(height: 16),
        _CategoryFilters(
          searchController: _searchController,
          statusFilter: _statusFilter,
          parentFilter: _parentFilter,
          tabFilter: _tabFilter,
          featuredFilter: _featuredFilter,
          showOnHomeFilter: _showOnHomeFilter,
          loadingParents: _loadingParents,
          parentOptions: _parentOptions,
          onSearchChanged: () {
            _scheduleSearch();
          },
          onStatusChanged: (value) {
            setState(() => _statusFilter = value);
            _loadCategories(page: 1);
          },
          onParentChanged: (value) {
            setState(() => _parentFilter = value);
            _loadCategories(page: 1);
          },
          onTabChanged: (value) {
            setState(() => _tabFilter = value);
            _loadCategories(page: 1);
          },
          onFeaturedChanged: (value) {
            setState(() => _featuredFilter = value);
            _loadCategories(page: 1);
          },
          onHomeChanged: (value) {
            setState(() => _showOnHomeFilter = value);
            _loadCategories(page: 1);
          },
          onReset: _resetFilters,
          onRefresh: () => _loadCategories(page: _page),
        ),
        const SizedBox(height: 18),
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
              onTap: () => _loadCategories(page: _page),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category inventory',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lower order values appear first. Drag rows to refine priority.',
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _CountPill(
                            label: 'Total',
                            value: _totalCount.toString(),
                          ),
                          const SizedBox(width: 10),
                          _CountPill(
                            label: 'Page',
                            value: '$_page/$_totalPages',
                          ),
                          if (_saving) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Saving changes...',
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (categories.isEmpty)
                        const AbzioEmptyCard(
                          title: 'No categories yet',
                          subtitle:
                              'Create your first category to start shaping home discovery, navigation, and boutique merchandising.',
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: categories.length,
                          onReorderItem: (oldIndex, newIndex) {
                            final reordered = [...categories];
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            setState(() => _categories = reordered);
                            _persistOrder(reordered);
                          },
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return Padding(
                              key: ValueKey(category.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CategoryInventoryRow(
                                category: category,
                                parentName:
                                    _categoryById(category.parentId)?.name ??
                                    category.parentName,
                                saving: _saving,
                                onEdit: () => _showCategoryForm(category),
                                onDelete: () => _deleteCategory(category),
                                onToggleActive: (value) =>
                                    _toggleCategory(category, value),
                                onToggleFeatured: (value) =>
                                    _toggleFeatured(category, value),
                                onToggleShowOnHome: (value) =>
                                    _toggleShowOnHome(category, value),
                                dragHandle: ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(
                                    Icons.drag_indicator_rounded,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CategoryPagination(
                page: _page,
                totalPages: _totalPages,
                totalCount: _totalCount,
                onPrevious: _page > 1 && !_loading
                    ? () => _loadCategories(page: _page - 1)
                    : null,
                onNext: _page < _totalPages && !_loading
                    ? () => _loadCategories(page: _page + 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.searchController,
    required this.statusFilter,
    required this.parentFilter,
    required this.tabFilter,
    required this.featuredFilter,
    required this.showOnHomeFilter,
    required this.loadingParents,
    required this.parentOptions,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onParentChanged,
    required this.onTabChanged,
    required this.onFeaturedChanged,
    required this.onHomeChanged,
    required this.onReset,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final String parentFilter;
  final String tabFilter;
  final String featuredFilter;
  final bool showOnHomeFilter;
  final bool loadingParents;
  final List<CategoryManagementModel> parentOptions;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onParentChanged;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<String> onFeaturedChanged;
  final ValueChanged<bool> onHomeChanged;
  final VoidCallback onReset;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search & filters',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onSearchChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Search categories',
                      hintText: 'Name, slug, description',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) => onStatusChanged(value ?? 'all'),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: tabFilter,
                    decoration: const InputDecoration(labelText: 'Home tab'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All tabs')),
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Men', child: Text('Men')),
                      DropdownMenuItem(value: 'Women', child: Text('Women')),
                      DropdownMenuItem(value: 'Kids', child: Text('Kids')),
                    ],
                    onChanged: (value) => onTabChanged(value ?? 'all'),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: featuredFilter,
                    decoration: const InputDecoration(labelText: 'Featured'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'true', child: Text('Featured')),
                      DropdownMenuItem(
                        value: 'false',
                        child: Text('Not featured'),
                      ),
                    ],
                    onChanged: (value) => onFeaturedChanged(value ?? 'all'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: parentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Parent category',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All parents'),
                      ),
                      const DropdownMenuItem(
                        value: 'root',
                        child: Text('Top-level only'),
                      ),
                      ...parentOptions.map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: loadingParents
                        ? null
                        : (value) => onParentChanged(value ?? 'all'),
                  ),
                ),
                FilterChip(
                  selected: showOnHomeFilter,
                  label: const Text('Show on home'),
                  onSelected: onHomeChanged,
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryInventoryRow extends StatelessWidget {
  const _CategoryInventoryRow({
    required this.category,
    required this.parentName,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onToggleFeatured,
    required this.onToggleShowOnHome,
    required this.dragHandle,
  });

  final CategoryManagementModel category;
  final String parentName;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleFeatured;
  final ValueChanged<bool> onToggleShowOnHome;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AbzioTheme.grey200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryThumb(imageUrl: category.image),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  dragHandle,
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category.slug,
                                style: GoogleFonts.inter(
                                  color: AbzioTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label: parentName.isEmpty ? 'Top-level' : parentName,
                        ),
                        _InfoChip(label: 'Order ${category.sortOrder}'),
                        _InfoChip(
                          label: category.isActive ? 'Active' : 'Inactive',
                          color: category.isActive
                              ? const Color(0xFF067647)
                              : const Color(0xFF667085),
                        ),
                        _InfoChip(
                          label: category.isFeatured ? 'Featured' : 'Standard',
                          color: category.isFeatured
                              ? AbzioTheme.accentColor
                              : const Color(0xFF667085),
                        ),
                        _InfoChip(
                          label: category.showOnHome ? 'Home' : 'Hidden',
                          color: category.showOnHome
                              ? const Color(0xFFC6A769)
                              : const Color(0xFF667085),
                        ),
                        _InfoChip(label: category.tabType),
                        _InfoChip(label: _formatDate(category.createdAt)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch.adaptive(
                          value: category.isActive,
                          onChanged: saving ? null : onToggleActive,
                          activeTrackColor: AbzioTheme.accentColor.withValues(
                            alpha: 0.45,
                          ),
                          activeThumbColor: AbzioTheme.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Active',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Featured',
                          onPressed: saving
                              ? null
                              : () => onToggleFeatured(!category.isFeatured),
                          icon: Icon(
                            category.isFeatured
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: category.isFeatured
                                ? AbzioTheme.accentColor
                                : AbzioTheme.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Show on home',
                          onPressed: saving
                              ? null
                              : () => onToggleShowOnHome(!category.showOnHome),
                          icon: Icon(
                            category.showOnHome
                                ? Icons.home_rounded
                                : Icons.home_outlined,
                            color: category.showOnHome
                                ? AbzioTheme.accentColor
                                : AbzioTheme.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: saving ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: saving ? null : onDelete,
                          color: const Color(0xFFB42318),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    dragHandle,
                    const SizedBox(width: 12),
                    _CategoryThumb(imageUrl: category.image),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.slug,
                            style: GoogleFonts.inter(
                              color: AbzioTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (category.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              category.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        parentName.isEmpty ? 'Top-level' : parentName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Text(
                        '${category.sortOrder}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: _MiniStatus(
                        label: category.isActive ? 'Active' : 'Inactive',
                        active: category.isActive,
                      ),
                    ),
                    SizedBox(
                      width: 102,
                      child: _MiniStatus(
                        label: category.isFeatured ? 'Featured' : 'Standard',
                        active: category.isFeatured,
                      ),
                    ),
                    SizedBox(
                      width: 108,
                      child: _MiniStatus(
                        label: category.showOnHome ? 'Home' : 'Hidden',
                        active: category.showOnHome,
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Text(
                        category.tabType,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        _formatDate(category.createdAt),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Toggle active',
                          onPressed: saving
                              ? null
                              : () => onToggleActive(!category.isActive),
                          icon: Icon(
                            category.isActive
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_rounded,
                            color: category.isActive
                                ? AbzioTheme.accentColor
                                : AbzioTheme.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Featured',
                          onPressed: saving
                              ? null
                              : () => onToggleFeatured(!category.isFeatured),
                          icon: Icon(
                            category.isFeatured
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: category.isFeatured
                                ? AbzioTheme.accentColor
                                : AbzioTheme.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Show on home',
                          onPressed: saving
                              ? null
                              : () => onToggleShowOnHome(!category.showOnHome),
                          icon: Icon(
                            category.showOnHome
                                ? Icons.home_rounded
                                : Icons.home_outlined,
                            color: category.showOnHome
                                ? AbzioTheme.accentColor
                                : AbzioTheme.textSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: saving ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: saving ? null : onDelete,
                          color: const Color(0xFFB42318),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 64,
        color: AbzioTheme.grey200,
        child: imageUrl.isEmpty
            ? Icon(Icons.category_outlined, color: AbzioTheme.textSecondary)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.category_outlined,
                  color: AbzioTheme.textSecondary,
                ),
              ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (active ? AbzioTheme.accentColor : AbzioTheme.textSecondary)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: active ? AbzioTheme.accentColor : AbzioTheme.textSecondary,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AbzioTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: effectiveColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AbzioTheme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AbzioTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPagination extends StatelessWidget {
  const _CategoryPagination({
    required this.page,
    required this.totalPages,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Text(
              '$totalCount categories',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AbzioTheme.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            Text(
              'Page $page of $totalPages',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryFormModal extends StatefulWidget {
  const CategoryFormModal({
    super.key,
    this.initialCategory,
    required this.parentOptions,
  });

  final CategoryManagementModel? initialCategory;
  final List<CategoryManagementModel> parentOptions;

  @override
  State<CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends State<CategoryFormModal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _seoTitleController = TextEditingController();
  final TextEditingController _seoDescriptionController =
      TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _slugEditedManually = false;
  bool _isActive = true;
  bool _isFeatured = false;
  bool _showOnHome = false;
  String _tabType = 'All';
  String _parentId = '';
  XFile? _pickedImage;
  XFile? _pickedBanner;
  Uint8List? _pickedImagePreview;
  Uint8List? _pickedBannerPreview;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    _nameController.addListener(_syncSlug);
    _slugController.addListener(_trackManualSlugEdit);
    if (category != null) {
      _nameController.text = category.name;
      _slugController.text = category.slug;
      _descriptionController.text = category.description;
      _seoTitleController.text = category.seoTitle;
      _seoDescriptionController.text = category.seoDescription;
      _orderController.text = category.sortOrder.toString();
      _isActive = category.isActive;
      _isFeatured = category.isFeatured;
      _showOnHome = category.showOnHome;
      _tabType = category.tabType;
      _parentId = category.parentId;
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
    _descriptionController.dispose();
    _seoTitleController.dispose();
    _seoDescriptionController.dispose();
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

  Future<void> _pickImage({required bool banner}) async {
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
      if (banner) {
        _pickedBanner = file;
        _pickedBannerPreview = bytes;
      } else {
        _pickedImage = file;
        _pickedImagePreview = bytes;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedParent = _parentId.trim().isEmpty ? '' : _parentId.trim();
    Navigator.of(context).pop(
      _CategoryFormResult(
        category: CategoryManagementModel(
          id: widget.initialCategory?.id ?? '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          image: widget.initialCategory?.image ?? '',
          bannerImage: widget.initialCategory?.bannerImage ?? '',
          description: _descriptionController.text.trim(),
          parentId: selectedParent,
          parentName: '',
          sortOrder: int.tryParse(_orderController.text.trim()) ?? 0,
          isFeatured: _isFeatured,
          isActive: _isActive,
          showOnHome: _showOnHome,
          tabType: _tabType,
          seoTitle: _seoTitleController.text.trim(),
          seoDescription: _seoDescriptionController.text.trim(),
          createdAt: widget.initialCategory?.createdAt ?? '',
          updatedAt: widget.initialCategory?.updatedAt ?? '',
          deletedAt: widget.initialCategory?.deletedAt ?? '',
        ),
        imageFile: _pickedImage,
        bannerFile: _pickedBanner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialCategory?.image ?? '';
    final currentBanner = widget.initialCategory?.bannerImage ?? '';
    final parentOptions = widget.parentOptions
        .where((category) => category.id != widget.initialCategory?.id)
        .toList();

    return AlertDialog(
      title: Text(
        widget.initialCategory == null ? 'Add category' : 'Edit category',
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category image',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _ImagePickerPreview(
                  imageUrl: currentImage,
                  previewBytes: _pickedImagePreview,
                  onTap: () => _pickImage(banner: false),
                  height: 170,
                  fallbackIcon: Icons.category_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(banner: false),
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        _pickedImagePreview != null || currentImage.isNotEmpty
                            ? 'Replace image'
                            : 'Upload image',
                      ),
                    ),
                    if (_pickedImage != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedImage!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AbzioTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Category banner image',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _ImagePickerPreview(
                  imageUrl: currentBanner,
                  previewBytes: _pickedBannerPreview,
                  onTap: () => _pickImage(banner: true),
                  height: 150,
                  fallbackIcon: Icons.image_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(banner: true),
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        _pickedBannerPreview != null || currentBanner.isNotEmpty
                            ? 'Replace banner'
                            : 'Upload banner',
                      ),
                    ),
                    if (_pickedBanner != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pickedBanner!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AbzioTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'Women',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Category name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    hintText: 'women',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Slug is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Elegant occasionwear and modern silhouettes',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parentId.isEmpty ? null : _parentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent Category (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('No parent'),
                    ),
                    ...parentOptions.map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tabType,
                  decoration: const InputDecoration(labelText: 'Home Tab'),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Men', child: Text('Men')),
                    DropdownMenuItem(value: 'Women', child: Text('Women')),
                    DropdownMenuItem(value: 'Kids', child: Text('Kids')),
                  ],
                  onChanged: (value) =>
                      setState(() => _tabType = value ?? 'All'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sort Order',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _isFeatured,
                        onChanged: (value) =>
                            setState(() => _isFeatured = value),
                        title: const Text('Featured'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _showOnHome,
                        onChanged: (value) =>
                            setState(() => _showOnHome = value),
                        title: const Text('Show on home'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        title: const Text('Active'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _seoTitleController,
                  decoration: const InputDecoration(
                    labelText: 'SEO Title',
                    hintText: 'Luxury Women’s Fashion',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _seoDescriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'SEO Description',
                    hintText:
                        'Premium fashion discovery curated for Abianzo shoppers.',
                  ),
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
              ? Image.memory(
                  previewBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
              : imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      _UploadPlaceholder(fallbackIcon: fallbackIcon),
                )
              : _UploadPlaceholder(fallbackIcon: fallbackIcon),
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  const _UploadPlaceholder({required this.fallbackIcon});

  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fallbackIcon, size: 32, color: AbzioTheme.textSecondary),
          const SizedBox(height: 8),
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

class _CategoryFormResult {
  const _CategoryFormResult({
    required this.category,
    required this.imageFile,
    required this.bannerFile,
  });

  final CategoryManagementModel category;
  final XFile? imageFile;
  final XFile? bannerFile;
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return '';
  }
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}
