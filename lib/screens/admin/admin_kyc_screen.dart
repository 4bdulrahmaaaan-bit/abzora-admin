import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/kyc_detail_view.dart';
import '../../widgets/kyc_request_card.dart';
import '../../widgets/state_views.dart';
import 'kyc_review_filters.dart';

sealed class _KycSelection {
  const _KycSelection();

  String get id;
  String get phone;
  String get status;
}

class _VendorSelection extends _KycSelection {
  const _VendorSelection(this.request);

  final VendorKycRequest request;

  @override
  String get id => request.id;

  @override
  String get phone => request.phone;

  @override
  String get status => request.status;
}

class _RiderSelection extends _KycSelection {
  const _RiderSelection(this.request);

  final RiderKycRequest request;

  @override
  String get id => request.id;

  @override
  String get phone => request.phone;

  @override
  String get status => request.status;
}

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  static const int _maxVisibleItems = 50;

  final OnboardingService _service = OnboardingService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  KycRequestFilterTab _tab = KycRequestFilterTab.all;
  _KycSelection? _selected;
  bool _busy = false;
  bool _todaysOnly = false;
  bool _missingDocumentsOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_scheduleRefresh);
    _cityController.addListener(_scheduleRefresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_scheduleRefresh)
      ..dispose();
    _cityController
      ..removeListener(_scheduleRefresh)
      ..dispose();
    super.dispose();
  }

  void _scheduleRefresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _approve(_KycSelection selection, AppUser actor) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (selection is _VendorSelection) {
        await _service.approveVendorRequest(
          requestId: selection.request.id,
          actor: actor,
        );
      } else if (selection is _RiderSelection) {
        await _service.approveRiderRequest(
          requestId: selection.request.id,
          actor: actor,
        );
      }
      _selectedIds.remove(selection.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            selection is _VendorSelection
                ? 'Vendor approved successfully. Store created and role assigned.'
                : 'Rider approved successfully. Role assigned and partner activated.',
          ),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reject(_KycSelection selection, AppUser actor) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter rejection reason'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell the applicant what to correct before re-submitting.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save reason'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (selection is _VendorSelection) {
        await _service.rejectVendorRequest(
          requestId: selection.request.id,
          reason: reason,
          actor: actor,
        );
      } else if (selection is _RiderSelection) {
        await _service.rejectRiderRequest(
          requestId: selection.request.id,
          reason: reason,
          actor: actor,
        );
      }
      _selectedIds.remove(selection.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('KYC rejected and applicant notified.'),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _approveSelected(
    List<_KycSelection> selectedItems,
    AppUser actor,
  ) async {
    if (_busy || selectedItems.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      for (final item in selectedItems) {
        if (item is _VendorSelection) {
          await _service.approveVendorRequest(
            requestId: item.request.id,
            actor: actor,
          );
        } else if (item is _RiderSelection) {
          await _service.approveRiderRequest(
            requestId: item.request.id,
            actor: actor,
          );
        }
      }
      _selectedIds.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${selectedItems.length} KYC request${selectedItems.length == 1 ? '' : 's'} approved.',
          ),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _rejectSelected(
    List<_KycSelection> selectedItems,
    AppUser actor,
  ) async {
    if (selectedItems.isEmpty) {
      return;
    }
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter rejection reason'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell the applicants what to correct before re-submitting.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Reject selected'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      for (final item in selectedItems) {
        if (item is _VendorSelection) {
          await _service.rejectVendorRequest(
            requestId: item.request.id,
            reason: reason,
            actor: actor,
          );
        } else if (item is _RiderSelection) {
          await _service.rejectRiderRequest(
            requestId: item.request.id,
            reason: reason,
            actor: actor,
          );
        }
      }
      _selectedIds.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${selectedItems.length} KYC request${selectedItems.length == 1 ? '' : 's'} rejected.',
          ),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  List<_KycSelection> _buildSelections({
    required List<VendorKycRequest> vendors,
    required List<RiderKycRequest> riders,
  }) {
    final entries = filterKycReviewEntries(
      vendors: vendors,
      riders: riders,
      tab: _tab,
      searchQuery: _searchController.text,
      cityQuery: _cityController.text,
      todaysOnly: _todaysOnly,
      missingDocumentsOnly: _missingDocumentsOnly,
    );
    return entries
        .map<_KycSelection>(
          (entry) => entry.vendorRequest != null
              ? _VendorSelection(entry.vendorRequest!)
              : _RiderSelection(entry.riderRequest!),
        )
        .toList();
  }

  List<String> _missingDocumentFlags(_KycSelection selection) {
    if (selection is _VendorSelection) {
      final kyc = selection.request.kyc;
      return [
        if (kyc.ownerPhotoUrl.trim().isEmpty) 'Missing photo',
        if (kyc.storeImageUrl.trim().isEmpty) 'Missing store image',
        if (kyc.aadhaarUrl.trim().isEmpty) 'Missing Aadhaar',
        if (kyc.panUrl.trim().isEmpty) 'Missing PAN',
      ];
    }
    final kyc = (selection as _RiderSelection).request.kyc;
    return [
      if (kyc.profilePhotoUrl.trim().isEmpty) 'Missing photo',
      if (kyc.aadhaarUrl.trim().isEmpty) 'Missing Aadhaar',
      if (kyc.licenseUrl.trim().isEmpty) 'Missing license',
    ];
  }

  List<String> _riskFlagsForSelection(
    _KycSelection selection, {
    required List<VendorKycRequest> vendors,
    required List<RiderKycRequest> riders,
  }) {
    final normalizedPhone = selection.phone.trim();
    final phones = <String>[
      ...vendors.map((item) => item.phone.trim()).where((value) => value.isNotEmpty),
      ...riders.map((item) => item.phone.trim()).where((value) => value.isNotEmpty),
    ];
    final duplicatePhone =
        normalizedPhone.isNotEmpty && phones.where((value) => value == normalizedPhone).length > 1;

    return [
      ..._missingDocumentFlags(selection),
      if (duplicatePhone) 'Duplicate phone',
      if (selection.status == 'rejected') 'Needs resubmission',
    ];
  }

  KycRequestListItem _toListItem(
    _KycSelection selection, {
    required List<VendorKycRequest> vendors,
    required List<RiderKycRequest> riders,
  }) {
    final riskFlags = _riskFlagsForSelection(
      selection,
      vendors: vendors,
      riders: riders,
    );

    if (selection is _VendorSelection) {
      return KycRequestListItem(
        id: selection.request.id,
        name: selection.request.ownerName,
        role: 'Vendor',
        city: selection.request.city,
        status: selection.request.status,
        submittedTime: selection.request.createdAt
            .replaceFirst('T', ' ')
            .split('.')
            .first,
        phone: selection.request.phone,
        thumbnailUrl: selection.request.kyc.ownerPhotoUrl,
        documentLabels: [
          if (selection.request.kyc.aadhaarUrl.trim().isNotEmpty) 'Aadhaar',
          if (selection.request.kyc.panUrl.trim().isNotEmpty) 'PAN',
        ],
        riskFlags: riskFlags,
        selected: _selectedIds.contains(selection.request.id),
      );
    }

    final rider = selection as _RiderSelection;
    return KycRequestListItem(
      id: rider.request.id,
      name: rider.request.name,
      role: 'Rider',
      city: rider.request.city,
      status: rider.request.status,
      submittedTime: rider.request.createdAt.replaceFirst('T', ' ').split('.').first,
      phone: rider.request.phone,
      thumbnailUrl: rider.request.kyc.profilePhotoUrl,
      documentLabels: [
        if (rider.request.kyc.aadhaarUrl.trim().isNotEmpty) 'Aadhaar',
        if (rider.request.kyc.licenseUrl.trim().isNotEmpty) 'License',
      ],
      riskFlags: riskFlags,
      selected: _selectedIds.contains(rider.request.id),
    );
  }

  KycDetailData? _toDetailData(
    _KycSelection? selection, {
    required List<VendorKycRequest> vendors,
    required List<RiderKycRequest> riders,
  }) {
    if (selection == null) {
      return null;
    }

    final riskFlags = _riskFlagsForSelection(
      selection,
      vendors: vendors,
      riders: riders,
    );

    if (selection is _VendorSelection) {
      final request = selection.request;
      return KycDetailData(
        id: request.id,
        name: request.ownerName,
        phone: request.phone,
        role: 'Vendor',
        city: request.city,
        status: request.status,
        createdAt: request.createdAt.replaceFirst('T', ' ').split('.').first,
        address: request.address,
        subtitle: request.storeName,
        rejectionReason: request.rejectionReason,
        primaryPhotoUrl: request.kyc.ownerPhotoUrl,
        secondaryPhotoUrl: request.kyc.storeImageUrl,
        primaryPhotoLabel: 'Owner Photo',
        secondaryPhotoLabel: 'Store Image',
        documents: [
          KycDocumentEntry(label: 'Aadhaar', url: request.kyc.aadhaarUrl),
          KycDocumentEntry(label: 'PAN', url: request.kyc.panUrl),
        ],
        riskFlags: riskFlags,
        reviewedByName: request.reviewedByName,
        reviewedAt: request.reviewedAt.replaceFirst('T', ' ').split('.').first,
        actionHistory: request.actionHistory,
      );
    }

    final request = (selection as _RiderSelection).request;
    return KycDetailData(
      id: request.id,
      name: request.name,
      phone: request.phone,
      role: 'Rider',
      city: request.city,
      status: request.status,
      createdAt: request.createdAt.replaceFirst('T', ' ').split('.').first,
      subtitle: request.vehicle,
      rejectionReason: request.rejectionReason,
      primaryPhotoUrl: request.kyc.profilePhotoUrl,
      primaryPhotoLabel: 'Profile Photo',
      documents: [
        KycDocumentEntry(label: 'Aadhaar', url: request.kyc.aadhaarUrl),
        KycDocumentEntry(label: 'License', url: request.kyc.licenseUrl),
      ],
      riskFlags: riskFlags,
      reviewedByName: request.reviewedByName,
      reviewedAt: request.reviewedAt.replaceFirst('T', ' ').split('.').first,
      actionHistory: request.actionHistory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthProvider>().user;
    if (actor == null || !context.read<AuthProvider>().isSuperAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Admin access only',
              subtitle: 'KYC review is available only to platform administrators.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('KYC Requests'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          _service.getVendorRequests(actor: actor),
          _service.getRiderRequests(actor: actor),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _KycLoadingState();
          }

          final vendors = snapshot.data![0] as List<VendorKycRequest>;
          final riders = snapshot.data![1] as List<RiderKycRequest>;
          final items = _buildSelections(vendors: vendors, riders: riders);
          final visibleItems = items.take(_maxVisibleItems).toList();
          _selectedIds.removeWhere((id) => !items.any((item) => item.id == id));

          if (_selected != null && !items.any((item) => item.id == _selected!.id)) {
            _selected = items.isEmpty ? null : items.first;
          } else if (_selected == null && items.isNotEmpty) {
            _selected = items.first;
          }

          final selectedItems =
              items.where((item) => _selectedIds.contains(item.id)).toList();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _topBar(
                  context,
                  items.length,
                  selectedItems,
                  actor,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1100;
                      if (!isWide) {
                        return _buildNarrowLayout(
                          visibleItems,
                          actor,
                          vendors,
                          riders,
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 400,
                            child: _buildRequestList(
                              visibleItems,
                              actor,
                              vendors,
                              riders,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: KycDetailView(
                              data: _toDetailData(
                                _selected,
                                vendors: vendors,
                                riders: riders,
                              ),
                              onApprove:
                                  _selected == null ? null : () => _approve(_selected!, actor),
                              onReject:
                                  _selected == null ? null : () => _reject(_selected!, actor),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(
    BuildContext context,
    int count,
    List<_KycSelection> selectedItems,
    AppUser actor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC Requests',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Review vendor and rider verification with fewer clicks and clearer evidence.',
                      style: TextStyle(color: Color(0xFF676767), height: 1.45),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$count request${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF7A5A00),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _tabChip(KycRequestFilterTab.all, 'All'),
              _tabChip(KycRequestFilterTab.vendor, 'Vendor'),
              _tabChip(KycRequestFilterTab.rider, 'Rider'),
              _tabChip(KycRequestFilterTab.pending, 'Pending'),
              _tabChip(KycRequestFilterTab.approved, 'Approved'),
              _tabChip(KycRequestFilterTab.rejected, 'Rejected'),
              _tabChip(KycRequestFilterTab.highPriority, 'High Priority'),
              const SizedBox(width: 12),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search name, phone, city, status',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    hintText: 'Filter by city',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
              ),
              FilterChip(
                label: const Text("Today's requests"),
                selected: _todaysOnly,
                onSelected: (value) => setState(() => _todaysOnly = value),
              ),
              FilterChip(
                label: const Text('Missing documents'),
                selected: _missingDocumentsOnly,
                onSelected: (value) => setState(() => _missingDocumentsOnly = value),
              ),
              if (selectedItems.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _rejectSelected(selectedItems, actor),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFB42318)),
                  label: Text('Reject ${selectedItems.length}'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _approveSelected(selectedItems, actor),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text('Approve ${selectedItems.length}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF067647),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          if (count > _maxVisibleItems) ...[
            const SizedBox(height: 14),
            Text(
              'Showing the latest $_maxVisibleItems requests for fast review. Narrow filters to refine the queue.',
              style: const TextStyle(
                color: Color(0xFF6C6C6C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabChip(KycRequestFilterTab tab, String label) {
    final selected = _tab == tab;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _tab = tab),
      selectedColor: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFFF3F3F3),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF444444),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildRequestList(
    List<_KycSelection> items,
    AppUser actor,
    List<VendorKycRequest> vendors,
    List<RiderKycRequest> riders,
  ) {
    if (items.isEmpty) {
      return const AbzioEmptyCard(
        title: 'No pending requests',
        subtitle: 'New verification requests will appear here when partners apply.',
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KycRequestCard(
            item: _toListItem(item, vendors: vendors, riders: riders),
            isSelected: _selected?.id == item.id,
            onTap: () => setState(() => _selected = item),
            onSelectedChanged: (selected) => setState(() {
              if (selected) {
                _selectedIds.add(item.id);
              } else {
                _selectedIds.remove(item.id);
              }
            }),
            onApprove: () => _approve(item, actor),
            onReject: () => _reject(item, actor),
          ),
        );
      },
    );
  }

  Widget _buildNarrowLayout(
    List<_KycSelection> items,
    AppUser actor,
    List<VendorKycRequest> vendors,
    List<RiderKycRequest> riders,
  ) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AbzioEmptyCard(
            title: 'No pending requests',
            subtitle: 'Try another tab or search term. New verification requests will show up here.',
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KycRequestCard(
            item: _toListItem(item, vendors: vendors, riders: riders),
            isSelected: false,
            onSelectedChanged: (selected) => setState(() {
              if (selected) {
                _selectedIds.add(item.id);
              } else {
                _selectedIds.remove(item.id);
              }
            }),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: const Color(0xFFF8F8F8),
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      title: const Text('KYC Detail'),
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: KycDetailView(
                        data: _toDetailData(
                          item,
                          vendors: vendors,
                          riders: riders,
                        ),
                        onApprove: () => _approve(item, actor),
                        onReject: () => _reject(item, actor),
                      ),
                    ),
                  ),
                ),
              );
            },
            onApprove: () => _approve(item, actor),
            onReject: () => _reject(item, actor),
          ),
        );
      },
    );
  }
}

class _KycLoadingState extends StatelessWidget {
  const _KycLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 146,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(
            2,
            (index) => Expanded(
              child: Container(
                height: 420,
                margin: EdgeInsets.only(
                  right: index == 0 ? 8 : 0,
                  left: index == 1 ? 8 : 0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
