import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/cms_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
import '../../widgets/state_views.dart';

class AdminCmsSection extends StatefulWidget {
  const AdminCmsSection({super.key});

  @override
  State<AdminCmsSection> createState() => _AdminCmsSectionState();
}

class _AdminCmsSectionState extends State<AdminCmsSection> {
  final BackendCommerceService _commerce = BackendCommerceService();
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<CmsEntryModel> _entries = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _page = 1;
  int _limit = 12;
  int _totalPages = 1;
  int _totalCount = 0;
  String _statusFilter = 'all';
  String _featuredFilter = 'all';
  String _publishedFilter = 'all';

  final List<_CmsTab> _tabs = const [
    _CmsTab(type: 'page', label: 'Pages', icon: Icons.article_outlined),
    _CmsTab(type: 'faq', label: 'FAQs', icon: Icons.quiz_outlined),
    _CmsTab(
      type: 'announcement',
      label: 'Announcements',
      icon: Icons.campaign_outlined,
    ),
    _CmsTab(
      type: 'navigation',
      label: 'Navigation',
      icon: Icons.menu_book_outlined,
    ),
  ];

  String _activeType = 'page';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) {
        _page = page;
      }
    });
    try {
      final result = await _commerce.getCmsEntries(
        type: _activeType,
        page: page ?? _page,
        limit: _limit,
        search: _searchController.text,
        status: _statusFilter,
        featured: _featuredFilter,
        published: _publishedFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = result.items;
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

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) {
        _loadEntries(page: 1);
      }
    });
  }

  Future<String> _uploadImage(XFile file) async {
    final actor = context.read<AuthProvider>().user;
    final actorId = actor?.id ?? '';
    return _storage.uploadPickedImage(
      file: file,
      folder: 'cms_assets',
      ownerId: actorId.isNotEmpty ? actorId : 'admin',
      fileName: 'cms_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _showEntryForm([CmsEntryModel? initialEntry]) async {
    final result = await showDialog<_CmsEntryFormResult>(
      context: context,
      builder: (dialogContext) =>
          CmsEntryFormModal(type: _activeType, initialEntry: initialEntry),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      var entry = result.entry;
      if (result.imageFile != null) {
        final imageUrl = await _uploadImage(result.imageFile!);
        entry = entry.copyWith(image: imageUrl);
      }

      if (initialEntry == null) {
        await _commerce.createCmsEntry(entry);
      } else {
        await _commerce.updateCmsEntry(entry);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialEntry == null
                ? 'CMS item created successfully.'
                : 'CMS item updated successfully.',
          ),
        ),
      );
      await _loadEntries(page: _page);
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

  Future<void> _deleteEntry(CmsEntryModel entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete CMS item'),
        content: Text('Soft delete "${entry.title}"?'),
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
      await _commerce.deleteCmsEntry(entry.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CMS item deleted successfully.')),
      );
      await _loadEntries(page: _page);
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

  Future<void> _toggleStatus(CmsEntryModel entry, bool isActive) async {
    setState(() => _saving = true);
    try {
      await _commerce.toggleCmsEntryStatus(
        entryId: entry.id,
        isActive: isActive,
      );
      if (!mounted) {
        return;
      }
      await _loadEntries(page: _page);
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

  Future<void> _persistOrder(List<CmsEntryModel> reordered) async {
    setState(() => _saving = true);
    try {
      final normalized = reordered
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(sortOrder: entry.key))
          .toList();
      await _commerce.reorderCmsEntries(normalized);
      if (!mounted) {
        return;
      }
      await _loadEntries(page: _page);
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

  List<CmsEntryModel> _sortedEntries() {
    final items = [..._entries];
    items.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return items;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = 'all';
      _featuredFilter = 'all';
      _publishedFilter = 'all';
    });
    _loadEntries(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _sortedEntries();
    final activeTab = _tabs.firstWhere((tab) => tab.type == _activeType);

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
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CMS management',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AbzioTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Publish and organize Abianzo pages, FAQs, announcements, and navigation content from a single editorial console.',
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
              onPressed: _saving ? null : () => _showEntryForm(),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text('Add ${_singularLabel(activeTab.label)}'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _tabs
              .map(
                (tab) => ChoiceChip(
                  selected: _activeType == tab.type,
                  label: Text(tab.label),
                  avatar: Icon(
                    tab.icon,
                    size: 18,
                    color: _activeType == tab.type
                        ? AbzioTheme.accentColor
                        : AbzioTheme.textSecondary,
                  ),
                  onSelected: (_) {
                    if (_activeType == tab.type) {
                      return;
                    }
                    setState(() {
                      _activeType = tab.type;
                    });
                    _loadEntries(page: 1);
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _CmsFiltersCard(
          activeType: _activeType,
          searchController: _searchController,
          statusFilter: _statusFilter,
          featuredFilter: _featuredFilter,
          publishedFilter: _publishedFilter,
          onSearchChanged: _scheduleSearch,
          onStatusChanged: (value) {
            setState(() => _statusFilter = value);
            _loadEntries(page: 1);
          },
          onFeaturedChanged: (value) {
            setState(() => _featuredFilter = value);
            _loadEntries(page: 1);
          },
          onPublishedChanged: (value) {
            setState(() => _publishedFilter = value);
            _loadEntries(page: 1);
          },
          onClear: _resetFilters,
          onRefresh: () => _loadEntries(page: _page),
        ),
        const SizedBox(height: 18),
        if (_loading)
          const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Center(
            child: AbzioEmptyCard(
              title: 'Could not load CMS content',
              subtitle: _error!,
              ctaLabel: 'Retry',
              onTap: () => _loadEntries(page: _page),
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
                                  '${activeTab.label} inventory',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lower sort order appears first. Drag items to reorder the collection.',
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
                      if (entries.isEmpty)
                        const AbzioEmptyCard(
                          title: 'No CMS items yet',
                          subtitle:
                              'Create a first entry for this CMS section to start publishing editorial content.',
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: entries.length,
                          onReorderItem: (oldIndex, newIndex) {
                            final reordered = [...entries];
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            setState(() => _entries = reordered);
                            _persistOrder(reordered);
                          },
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return Padding(
                              key: ValueKey(entry.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CmsEntryRow(
                                entry: entry,
                                saving: _saving,
                                onEdit: () => _showEntryForm(entry),
                                onDelete: () => _deleteEntry(entry),
                                onToggleActive: (value) =>
                                    _toggleStatus(entry, value),
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
              _CmsPagination(
                page: _page,
                totalPages: _totalPages,
                totalCount: _totalCount,
                onPrevious: _page > 1 && !_loading
                    ? () => _loadEntries(page: _page - 1)
                    : null,
                onNext: _page < _totalPages && !_loading
                    ? () => _loadEntries(page: _page + 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

class _CmsFiltersCard extends StatelessWidget {
  const _CmsFiltersCard({
    required this.activeType,
    required this.searchController,
    required this.statusFilter,
    required this.featuredFilter,
    required this.publishedFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onFeaturedChanged,
    required this.onPublishedChanged,
    required this.onClear,
    required this.onRefresh,
  });

  final String activeType;
  final TextEditingController searchController;
  final String statusFilter;
  final String featuredFilter;
  final String publishedFilter;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onFeaturedChanged;
  final ValueChanged<String> onPublishedChanged;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
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
                  labelText: 'Search CMS',
                  hintText: 'Title, slug, content, category',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) => onStatusChanged(value ?? 'all'),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: featuredFilter,
                decoration: const InputDecoration(labelText: 'Featured'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'true', child: Text('Featured')),
                  DropdownMenuItem(value: 'false', child: Text('Not featured')),
                ],
                onChanged: (value) => onFeaturedChanged(value ?? 'all'),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: publishedFilter,
                decoration: const InputDecoration(labelText: 'Published'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'true', child: Text('Published')),
                  DropdownMenuItem(value: 'false', child: Text('Drafts')),
                ],
                onChanged: (value) => onPublishedChanged(value ?? 'all'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
            if (activeType == 'faq')
              const _CmsHintChip(
                text: 'FAQ answers publish as support content',
              ),
            if (activeType == 'page')
              const _CmsHintChip(
                text: 'Pages power legal and editorial screens',
              ),
            if (activeType == 'announcement')
              const _CmsHintChip(
                text: 'Announcements are ideal for campaign and promo copy',
              ),
            if (activeType == 'navigation')
              const _CmsHintChip(
                text: 'Navigation items can drive header or footer menus',
              ),
          ],
        ),
      ),
    );
  }
}

class _CmsEntryRow extends StatelessWidget {
  const _CmsEntryRow({
    required this.entry,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.dragHandle,
  });

  final CmsEntryModel entry;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
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
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CmsThumb(imageUrl: entry.image, type: entry.type),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.title,
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
                                entry.slug,
                                style: GoogleFonts.inter(
                                  color: AbzioTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (entry.category.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  entry.category,
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _entryDescription(entry),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniChip(label: entry.type.toUpperCase()),
                        _MiniChip(
                          label: entry.isActive ? 'Active' : 'Inactive',
                        ),
                        _MiniChip(
                          label: entry.isFeatured ? 'Featured' : 'Standard',
                        ),
                        _MiniChip(
                          label: entry.isPublished ? 'Published' : 'Draft',
                        ),
                        _MiniChip(label: 'Order ${entry.sortOrder}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch.adaptive(
                          value: entry.isActive,
                          onChanged: saving ? null : onToggleActive,
                          activeTrackColor: AbzioTheme.accentColor.withValues(
                            alpha: 0.45,
                          ),
                          activeThumbColor: AbzioTheme.accentColor,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: saving ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
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
                    _CmsThumb(imageUrl: entry.image, type: entry.type),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.slug,
                            style: GoogleFonts.inter(
                              color: AbzioTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (entry.summary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry.summary,
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
                        entry.category.isEmpty
                            ? _typeLabel(entry.type)
                            : entry.category,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: _MiniChip(label: entry.type.toUpperCase()),
                    ),
                    SizedBox(
                      width: 100,
                      child: _MiniChip(
                        label: entry.isPublished ? 'Published' : 'Draft',
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: _MiniChip(
                        label: entry.isActive ? 'Active' : 'Inactive',
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: _MiniChip(
                        label: entry.isFeatured ? 'Featured' : 'Standard',
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        '${entry.sortOrder}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Toggle active',
                          onPressed: saving
                              ? null
                              : () => onToggleActive(!entry.isActive),
                          icon: Icon(
                            entry.isActive
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_rounded,
                            color: entry.isActive
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

class CmsEntryFormModal extends StatefulWidget {
  const CmsEntryFormModal({super.key, required this.type, this.initialEntry});

  final String type;
  final CmsEntryModel? initialEntry;

  @override
  State<CmsEntryFormModal> createState() => _CmsEntryFormModalState();
}

class _CmsEntryFormModalState extends State<CmsEntryFormModal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _linkUrlController = TextEditingController();
  final TextEditingController _linkLabelController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _seoTitleController = TextEditingController();
  final TextEditingController _seoDescriptionController =
      TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _slugEditedManually = false;
  bool _isActive = true;
  bool _isFeatured = false;
  bool _isPublished = true;
  XFile? _pickedImage;
  Uint8List? _pickedPreview;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _titleController.addListener(_syncSlug);
    _titleController.addListener(_previewListener);
    _slugController.addListener(_trackManualSlugEdit);
    _summaryController.addListener(_previewListener);
    _contentController.addListener(_previewListener);
    _linkUrlController.addListener(_previewListener);
    _linkLabelController.addListener(_previewListener);
    _sectionController.addListener(_previewListener);
    _categoryController.addListener(_previewListener);
    _seoTitleController.addListener(_previewListener);
    _seoDescriptionController.addListener(_previewListener);
    if (entry != null) {
      _titleController.text = entry.title;
      _slugController.text = entry.slug;
      _categoryController.text = entry.category;
      _summaryController.text = entry.summary;
      _contentController.text = entry.content;
      _linkUrlController.text = entry.linkUrl;
      _linkLabelController.text = entry.linkLabel;
      _sectionController.text = entry.section;
      _seoTitleController.text = entry.seoTitle;
      _seoDescriptionController.text = entry.seoDescription;
      _orderController.text = entry.sortOrder.toString();
      _isActive = entry.isActive;
      _isFeatured = entry.isFeatured;
      _isPublished = entry.isPublished;
      _slugEditedManually = true;
    } else {
      _orderController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_syncSlug);
    _titleController.removeListener(_previewListener);
    _slugController.removeListener(_trackManualSlugEdit);
    _summaryController.removeListener(_previewListener);
    _contentController.removeListener(_previewListener);
    _linkUrlController.removeListener(_previewListener);
    _linkLabelController.removeListener(_previewListener);
    _sectionController.removeListener(_previewListener);
    _categoryController.removeListener(_previewListener);
    _seoTitleController.removeListener(_previewListener);
    _seoDescriptionController.removeListener(_previewListener);
    _titleController.dispose();
    _slugController.dispose();
    _categoryController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _linkUrlController.dispose();
    _linkLabelController.dispose();
    _sectionController.dispose();
    _seoTitleController.dispose();
    _seoDescriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _trackManualSlugEdit() {
    final generated = _slugify(_titleController.text);
    if (_slugController.text.trim() != generated) {
      _slugEditedManually = true;
    }
  }

  void _syncSlug() {
    if (_slugEditedManually) {
      return;
    }
    final next = _slugify(_titleController.text);
    _slugController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _previewListener() {
    if (mounted) {
      setState(() {});
    }
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
      _pickedImage = file;
      _pickedPreview = bytes;
    });
  }

  void _applyInlineFormat(String prefix, String suffix) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    if (!selection.isValid) {
      _contentController.text = '$prefix$text$suffix';
      _contentController.selection = TextSelection.collapsed(
        offset: prefix.length + text.length + suffix.length,
      );
      return;
    }

    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final before = text.substring(0, start);
    final selected = text.substring(start, end);
    final after = text.substring(end);
    final replacement = selected.isEmpty ? 'text' : selected;
    final next = '$before$prefix$replacement$suffix$after';
    _contentController.text = next;
    _contentController.selection = TextSelection(
      baseOffset: before.length + prefix.length,
      extentOffset: before.length + prefix.length + replacement.length,
    );
  }

  void _insertLinePrefix(String prefix) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    if (!selection.isValid) {
      _contentController.text = '$prefix$text';
      _contentController.selection = TextSelection.collapsed(
        offset: prefix.length,
      );
      return;
    }

    final start = selection.start.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', start > 0 ? start - 1 : 0) + 1;
    final before = text.substring(0, lineStart);
    final after = text.substring(lineStart);
    _contentController.text = '$before$prefix$after';
    _contentController.selection = TextSelection.collapsed(
      offset: lineStart + prefix.length,
    );
  }

  void _insertLinkTemplate() {
    final selection = _contentController.selection;
    final text = _contentController.text;
    final selected = selection.isValid && selection.textInside(text).isNotEmpty
        ? selection.textInside(text)
        : 'link text';
    final replacement = '[$selected](https://)';
    if (!selection.isValid) {
      _contentController.text = '${_contentController.text}$replacement';
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
      return;
    }

    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final before = text.substring(0, start);
    final after = text.substring(end);
    _contentController.text = '$before$replacement$after';
    _contentController.selection = TextSelection(
      baseOffset: before.length + 1,
      extentOffset: before.length + 1 + selected.length,
    );
  }

  Widget _buildContentEditor(BuildContext context, bool sideBySide) {
    final contentPreview = _contentController.text.trim();
    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _contentLabel(widget.type),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _RichToolbar(
          onHeading: () => _insertLinePrefix('# '),
          onSubheading: () => _insertLinePrefix('## '),
          onBold: () => _applyInlineFormat('**', '**'),
          onItalic: () => _applyInlineFormat('*', '*'),
          onBullet: () => _insertLinePrefix('- '),
          onQuote: () => _insertLinePrefix('> '),
          onLink: _insertLinkTemplate,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _contentController,
          maxLines: sideBySide ? 16 : 12,
          minLines: sideBySide ? 12 : 8,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: _contentHint(widget.type),
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onChanged: (_) => setState(() {}),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Content is required.'
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          'Tip: use `#` for headings, `**bold**`, `*italic*`, `- bullets`, and `[text](url)` for links.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );

    final preview = _CmsPreviewPane(
      title: widget.type == 'faq' ? 'Answer preview' : 'Live preview',
      content: contentPreview,
      type: widget.type,
      summary: _summaryController.text.trim(),
      linkLabel: _linkLabelController.text.trim(),
      linkUrl: _linkUrlController.text.trim(),
      imageUrl: widget.initialEntry?.image ?? '',
      imageBytes: _pickedPreview,
    );

    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [editor, const SizedBox(height: 16), preview],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: editor),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: preview),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final publishedAt = _isPublished
        ? (widget.initialEntry?.publishedAt.isNotEmpty == true
              ? widget.initialEntry!.publishedAt
              : DateTime.now().toIso8601String())
        : '';
    Navigator.of(context).pop(
      _CmsEntryFormResult(
        entry: CmsEntryModel(
          id: widget.initialEntry?.id ?? '',
          type: widget.type,
          title: _titleController.text.trim(),
          slug: _slugController.text.trim(),
          category: _categoryController.text.trim(),
          summary: _summaryController.text.trim(),
          content: _contentController.text.trim(),
          image: widget.initialEntry?.image ?? '',
          linkUrl: _linkUrlController.text.trim(),
          linkLabel: _linkLabelController.text.trim(),
          section: _sectionController.text.trim(),
          sortOrder: int.tryParse(_orderController.text.trim()) ?? 0,
          isFeatured: _isFeatured,
          isActive: _isActive,
          seoTitle: _seoTitleController.text.trim(),
          seoDescription: _seoDescriptionController.text.trim(),
          publishedAt: publishedAt,
          createdAt: widget.initialEntry?.createdAt ?? '',
          updatedAt: widget.initialEntry?.updatedAt ?? '',
        ),
        imageFile: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.initialEntry?.image ?? '';

    return AlertDialog(
      title: Text(
        widget.initialEntry == null
            ? 'Add ${_typeLabel(widget.type)}'
            : 'Edit ${_typeLabel(widget.type)}',
      ),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sideBySide = MediaQuery.sizeOf(context).width > 1280;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.type != 'faq') ...[
                      Text(
                        'Hero image',
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
                        height: 180,
                        fallbackIcon: Icons.image_outlined,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_outlined),
                            label: Text(
                              _pickedPreview != null || currentImage.isNotEmpty
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
                    ],
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(widget.type),
                        hintText: _fieldHint(widget.type),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'This field is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (widget.type != 'faq')
                      TextFormField(
                        controller: _slugController,
                        decoration: const InputDecoration(
                          labelText: 'Slug',
                          hintText: 'about-us',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Slug is required.'
                            : null,
                      ),
                    if (widget.type != 'faq') const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category / Section',
                        hintText: 'Customer help, Header, Footer, Fashion tips',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _summaryController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _summaryLabel(widget.type),
                        hintText: _summaryHint(widget.type),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContentEditor(context, sideBySide),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _linkUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Link URL',
                              hintText: '/faq or https://...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _linkLabelController,
                            decoration: const InputDecoration(
                              labelText: 'Link label',
                              hintText: 'Read more',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sectionController,
                            decoration: const InputDecoration(
                              labelText: 'Section',
                              hintText: 'header, footer, home',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _orderController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sort Order',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile.adaptive(
                            value: _isFeatured,
                            onChanged: (value) =>
                                setState(() => _isFeatured = value),
                            title: const Text('Featured'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            value: _isPublished,
                            onChanged: (value) =>
                                setState(() => _isPublished = value),
                            title: const Text('Published'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            value: _isActive,
                            onChanged: (value) =>
                                setState(() => _isActive = value),
                            title: const Text('Active'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    if (widget.type == 'page' ||
                        widget.type == 'announcement') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _seoTitleController,
                        decoration: const InputDecoration(
                          labelText: 'SEO Title',
                          hintText: 'Luxury editorial page title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _seoDescriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'SEO Description',
                          hintText: 'Search engine summary for this CMS item',
                        ),
                      ),
                    ],
                  ],
                );
              },
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
          child: Text(widget.initialEntry == null ? 'Create' : 'Update'),
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

class _CmsPreviewPane extends StatelessWidget {
  const _CmsPreviewPane({
    required this.title,
    required this.content,
    required this.type,
    required this.summary,
    required this.linkLabel,
    required this.linkUrl,
    required this.imageUrl,
    required this.imageBytes,
  });

  final String title;
  final String content;
  final String type;
  final String summary;
  final String linkLabel;
  final String linkUrl;
  final String imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      color: AbzioTheme.textPrimary,
      height: 1.55,
      fontSize: 14,
    );
    final hasImage = imageBytes != null || imageUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.14),
        ),
        boxShadow: [
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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AbzioTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: imageBytes != null
                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: Icon(
                            _typeIcon(type),
                            size: 34,
                            color: AbzioTheme.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (summary.isNotEmpty) ...[
            Text(
              summary,
              style: GoogleFonts.inter(
                color: AbzioTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (content.trim().isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AbzioTheme.grey200),
              ),
              child: Text(
                'Start typing to see a live preview.',
                style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
              ),
            )
          else
            _MarkdownPreview(content: content, baseStyle: base),
          if (linkUrl.isNotEmpty || linkLabel.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (linkLabel.isNotEmpty) _MiniChip(label: linkLabel),
                if (linkUrl.isNotEmpty) _MiniChip(label: linkUrl),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.content, required this.baseStyle});

  final String content;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(
          _markdownLine(
            line.substring(4),
            baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        );
        widgets.add(const SizedBox(height: 6));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(
          _markdownLine(
            line.substring(3),
            baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(
          _markdownLine(
            line.substring(2),
            baseStyle.copyWith(fontSize: 23, fontWeight: FontWeight.w800),
          ),
        );
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('> ')) {
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
              ),
            ),
            child: Text.rich(
              TextSpan(
                style: baseStyle.copyWith(fontStyle: FontStyle.italic),
                children: _parseInlineSpans(
                  line.substring(2),
                  baseStyle.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          _MarkdownBullet(text: line.substring(2), baseStyle: baseStyle),
        );
        continue;
      }
      widgets.add(_markdownLine(line, baseStyle));
      widgets.add(const SizedBox(height: 10));
    }
    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _MarkdownBullet extends StatelessWidget {
  const _MarkdownBullet({required this.text, required this.baseStyle});

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFC6A769),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: _parseInlineSpans(text, baseStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _markdownLine(String text, TextStyle style) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Text.rich(
      TextSpan(style: style, children: _parseInlineSpans(text, style)),
    ),
  );
}

List<InlineSpan> _parseInlineSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  var index = 0;
  while (index < text.length) {
    final remaining = text.substring(index);
    if (remaining.startsWith('**')) {
      final end = text.indexOf('**', index + 2);
      if (end > index + 1) {
        final inner = text.substring(index + 2, end);
        spans.add(
          TextSpan(
            text: inner,
            style: style.copyWith(fontWeight: FontWeight.w800),
          ),
        );
        index = end + 2;
        continue;
      }
    }
    if (remaining.startsWith('*')) {
      final end = text.indexOf('*', index + 1);
      if (end > index) {
        final inner = text.substring(index + 1, end);
        spans.add(
          TextSpan(
            text: inner,
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        index = end + 1;
        continue;
      }
    }
    if (remaining.startsWith('[')) {
      final closingText = text.indexOf('](', index + 1);
      final closingParen = closingText == -1
          ? -1
          : text.indexOf(')', closingText + 2);
      if (closingText != -1 && closingParen != -1) {
        final label = text.substring(index + 1, closingText);
        spans.add(
          TextSpan(
            text: label,
            style: style.copyWith(
              color: AbzioTheme.accentColor,
              decoration: TextDecoration.underline,
              decorationColor: AbzioTheme.accentColor,
            ),
          ),
        );
        index = closingParen + 1;
        continue;
      }
    }

    final nextBreaks = <int>[
      text.indexOf('**', index + 1),
      text.indexOf('*', index + 1),
      text.indexOf('[', index + 1),
    ].where((value) => value != -1).toList();
    final next = nextBreaks.isEmpty
        ? text.length
        : nextBreaks.reduce((a, b) => a < b ? a : b);
    spans.add(TextSpan(text: text.substring(index, next), style: style));
    index = next;
  }
  return spans;
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AbzioTheme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AbzioTheme.accentColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RichToolbar extends StatelessWidget {
  const _RichToolbar({
    required this.onHeading,
    required this.onSubheading,
    required this.onBold,
    required this.onItalic,
    required this.onBullet,
    required this.onQuote,
    required this.onLink,
  });

  final VoidCallback onHeading;
  final VoidCallback onSubheading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBullet;
  final VoidCallback onQuote;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    Widget button({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AbzioTheme.grey200),
            ),
            child: Icon(icon, size: 18, color: AbzioTheme.textPrimary),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        button(
          icon: Icons.title_rounded,
          label: 'Heading',
          onPressed: onHeading,
        ),
        button(
          icon: Icons.short_text_rounded,
          label: 'Subheading',
          onPressed: onSubheading,
        ),
        button(
          icon: Icons.format_bold_rounded,
          label: 'Bold',
          onPressed: onBold,
        ),
        button(
          icon: Icons.format_italic_rounded,
          label: 'Italic',
          onPressed: onItalic,
        ),
        button(
          icon: Icons.format_list_bulleted_rounded,
          label: 'Bullet',
          onPressed: onBullet,
        ),
        button(
          icon: Icons.format_quote_rounded,
          label: 'Quote',
          onPressed: onQuote,
        ),
        button(icon: Icons.link_rounded, label: 'Link', onPressed: onLink),
      ],
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

class _CmsPagination extends StatelessWidget {
  const _CmsPagination({
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
              '$totalCount entries',
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

class _CmsHintChip extends StatelessWidget {
  const _CmsHintChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AbzioTheme.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AbzioTheme.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CmsThumb extends StatelessWidget {
  const _CmsThumb({required this.imageUrl, required this.type});

  final String imageUrl;
  final String type;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 64,
        color: AbzioTheme.grey200,
        child: imageUrl.isEmpty
            ? Icon(_typeIcon(type), color: AbzioTheme.textSecondary)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(_typeIcon(type), color: AbzioTheme.textSecondary),
              ),
      ),
    );
  }
}

class _CmsTab {
  const _CmsTab({required this.type, required this.label, required this.icon});

  final String type;
  final String label;
  final IconData icon;
}

class _CmsEntryFormResult {
  const _CmsEntryFormResult({required this.entry, required this.imageFile});

  final CmsEntryModel entry;
  final XFile? imageFile;
}

String _typeLabel(String type) {
  switch (type) {
    case 'faq':
      return 'FAQ';
    case 'announcement':
      return 'Announcement';
    case 'navigation':
      return 'Navigation item';
    default:
      return 'Page';
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'faq':
      return Icons.quiz_outlined;
    case 'announcement':
      return Icons.campaign_outlined;
    case 'navigation':
      return Icons.menu_book_outlined;
    default:
      return Icons.article_outlined;
  }
}

String _fieldLabel(String type) {
  switch (type) {
    case 'faq':
      return 'Question';
    case 'announcement':
      return 'Announcement title';
    case 'navigation':
      return 'Menu label';
    default:
      return 'Page title';
  }
}

String _fieldHint(String type) {
  switch (type) {
    case 'faq':
      return 'How long does delivery take?';
    case 'announcement':
      return 'New collection now live';
    case 'navigation':
      return 'Shop by Category';
    default:
      return 'About Abianzo';
  }
}

String _summaryLabel(String type) {
  switch (type) {
    case 'faq':
      return 'Category';
    case 'navigation':
      return 'Summary';
    default:
      return 'Summary';
  }
}

String _summaryHint(String type) {
  switch (type) {
    case 'faq':
      return 'Delivery, payment, returns, sizing';
    case 'navigation':
      return 'Header or footer descriptor';
    default:
      return 'Short editorial summary or excerpt';
  }
}

String _contentLabel(String type) {
  switch (type) {
    case 'faq':
      return 'Answer';
    case 'announcement':
      return 'Announcement body';
    case 'navigation':
      return 'Destination note';
    default:
      return 'Page body';
  }
}

String _contentHint(String type) {
  switch (type) {
    case 'faq':
      return 'Write a helpful answer for shoppers';
    case 'announcement':
      return 'Describe the campaign, drop, or offer';
    case 'navigation':
      return 'Optional note for internal use';
    default:
      return 'Write the full page content here';
  }
}

String _entryDescription(CmsEntryModel entry) {
  switch (entry.type) {
    case 'faq':
      return entry.content;
    case 'announcement':
      return entry.summary.isNotEmpty ? entry.summary : entry.content;
    case 'navigation':
      return entry.linkUrl.isNotEmpty ? entry.linkUrl : entry.summary;
    default:
      return entry.summary.isNotEmpty ? entry.summary : entry.content;
  }
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _singularLabel(String label) {
  switch (label) {
    case 'Pages':
      return 'Page';
    case 'FAQs':
      return 'FAQ';
    case 'Announcements':
      return 'Announcement';
    case 'Navigation':
      return 'Navigation item';
    default:
      return label;
  }
}
