import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/campaign_api.dart';
import '../../services/coupon_api.dart';
import '../../widgets/lazy_indexed_tab_view.dart';

class MarketingCenterScreen extends StatefulWidget {
  const MarketingCenterScreen({super.key});

  @override
  State<MarketingCenterScreen> createState() => _MarketingCenterScreenState();
}

class _MarketingCenterScreenState extends State<MarketingCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CampaignApi _campaignApi = CampaignApi();
  final CouponApi _couponApi = CouponApi();

  List<Map<String, dynamic>> _campaigns = [];
  bool _isLoadingCampaigns = true;
  String? _campaignsError;

  List<Map<String, dynamic>> _coupons = [];
  bool _isLoadingCoupons = true;
  String? _couponsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCampaigns();
    _fetchCoupons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns() async {
    setState(() {
      _isLoadingCampaigns = true;
      _campaignsError = null;
    });
    try {
      final campaigns = await _campaignApi.getCampaigns();
      setState(() {
        _campaigns = campaigns;
        _isLoadingCampaigns = false;
      });
    } catch (e) {
      setState(() {
        _campaignsError = e.toString();
        _isLoadingCampaigns = false;
      });
    }
  }

  Future<void> _fetchCoupons() async {
    setState(() {
      _isLoadingCoupons = true;
      _couponsError = null;
    });
    try {
      final coupons = await _couponApi.getCoupons();
      setState(() {
        _coupons = coupons;
        _isLoadingCoupons = false;
      });
    } catch (e) {
      setState(() {
        _couponsError = e.toString();
        _isLoadingCoupons = false;
      });
    }
  }

  Future<void> _openCreateCouponDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CouponDialog(
        onSave: (payload) => _couponApi.createCoupon(payload),
      ),
    );
    if (saved == true) {
      await _fetchCoupons();
    }
  }

  Future<void> _openEditCouponDialog(Map<String, dynamic> coupon) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CouponDialog(
        coupon: coupon,
        onSave: (payload) => _couponApi.updateCoupon(
          coupon['_id']?.toString() ?? coupon['id']?.toString() ?? '',
          payload,
        ),
      ),
    );
    if (saved == true) {
      await _fetchCoupons();
    }
  }

  Future<void> _duplicateCoupon(Map<String, dynamic> coupon) async {
    final duplicate = Map<String, dynamic>.from(coupon)
      ..remove('_id')
      ..remove('id')
      ..['couponCode'] =
          '${coupon['couponCode'] ?? ''}COPY${DateTime.now().millisecondsSinceEpoch % 10000}'
      ..['status'] = 'draft'
      ..['usedCount'] = 0
      ..['startDate'] = DateTime.now().toIso8601String()
      ..['endDate'] = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    await _couponApi.createCoupon(duplicate);
    if (mounted) {
      await _fetchCoupons();
    }
  }

  Future<void> _setCouponStatus(Map<String, dynamic> coupon, String status) async {
    final id = coupon['_id']?.toString() ?? coupon['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }
    await _couponApi.updateCouponStatus(id, status);
    if (mounted) {
      await _fetchCoupons();
    }
  }

  Future<void> _deleteCoupon(Map<String, dynamic> coupon) async {
    final id = coupon['_id']?.toString() ?? coupon['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete coupon'),
        content: Text(
          'Delete ${coupon['couponCode'] ?? ''}? This removes it from vendor checkout immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _couponApi.deleteCoupon(id);
    if (mounted) {
      await _fetchCoupons();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Marketing Center',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: VendorTheme.primary,
          unselectedLabelColor: VendorTheme.grey500,
          indicatorColor: VendorTheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Campaigns'),
            Tab(text: 'My Coupons'),
            Tab(text: 'Flash Sales'),
          ],
        ),
      ),
      body: LazyIndexedTabView(
        controller: _tabController,
        length: 3,
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return _buildCampaignsTab();
            case 1:
              return _buildCouponsTab();
            case 2:
              return _buildFlashSalesTab();
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildCampaignsTab() {
    return RefreshIndicator(
      onRefresh: _fetchCampaigns,
      color: VendorTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(
              title: 'Boost Your Visibility',
              subtitle:
                  'Join upcoming platform campaigns to increase your reach and sales.',
              buttonText: 'View All Campaigns',
              icon: Icons.campaign_outlined,
            ),
            const SizedBox(height: VendorTheme.spacing24),
            Text(
              'Active Campaigns',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: VendorTheme.spacing16),
            if (_isLoadingCampaigns)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: VendorTheme.primary),
                ),
              )
            else if (_campaignsError != null)
              Center(
                child: Text(
                  'Error: $_campaignsError',
                  style: const TextStyle(color: VendorTheme.error),
                ),
              )
            else if (_campaigns.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No campaigns available'),
                ),
              )
            else
              ..._campaigns.map((c) {
                final status = c['status']?.toString().toUpperCase() ?? 'DRAFT';
                final badgeType = status == 'ACTIVE'
                    ? VendorBadgeType.success
                    : VendorBadgeType.info;
                final startDate =
                    c['startDate']?.toString().substring(0, 10) ?? '';
                final endDate = c['endDate']?.toString().substring(0, 10) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: VendorTheme.spacing12),
                  child: _buildCampaignCard(
                    title: c['title'] ?? 'Untitled',
                    status: status,
                    dateRange: '$startDate to $endDate',
                    participants: 'Platform Campaign',
                    type: badgeType,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _fetchCoupons,
      color: VendorTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(
              title: 'My Coupons',
              subtitle:
                  'Create special discounts to reward loyal customers and drive conversions.',
              buttonText: 'Create Coupon',
              icon: Icons.local_activity_outlined,
              onTap: _openCreateCouponDialog,
            ),
            const SizedBox(height: VendorTheme.spacing24),
            Text(
              'Active Coupons',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: VendorTheme.spacing16),
            if (_isLoadingCoupons)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: VendorTheme.primary),
                ),
              )
            else if (_couponsError != null)
              Center(
                child: Text(
                  'Error: $_couponsError',
                  style: const TextStyle(color: VendorTheme.error),
                ),
              )
            else if (_coupons.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No coupons available'),
                ),
              )
            else
              ..._coupons.map((c) {
                final discount = c['discountType'] == 'percentage'
                    ? '${c['discountValue']}% OFF'
                    : '\u20B9${c['discountValue']} OFF';
                final usage = c['usageLimit'] == null
                    ? '${c['usedCount']} uses'
                    : '${c['usedCount']} / ${c['usageLimit']} uses';
                final expiry =
                    c['endDate']?.toString().substring(0, 10) ?? 'No expiry';
                return Padding(
                  padding: const EdgeInsets.only(bottom: VendorTheme.spacing12),
                  child: _buildCouponCard(
                    coupon: c,
                    code: c['couponCode'] ?? '',
                    discount: discount,
                    usage: usage,
                    expiry: 'Expires $expiry',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashSalesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(
            title: 'Flash Sales',
            subtitle:
                'Create time-bound deep discounts to clear inventory fast.',
            buttonText: 'Schedule Flash Sale',
            icon: Icons.bolt_outlined,
          ),
          const SizedBox(height: VendorTheme.spacing24),
          Text(
            'Upcoming Flash Sales',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          PremiumVendorCard(
            padding: const EdgeInsets.all(VendorTheme.spacing20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    size: 48,
                    color: VendorTheme.grey300,
                  ),
                  const SizedBox(height: VendorTheme.spacing16),
                  Text(
                    'No Flash Sales Scheduled',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: VendorTheme.spacing8),
                  Text(
                    'Create a flash sale to boost immediate sales.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: VendorTheme.grey500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing24),
      backgroundColor: VendorTheme.primary.withValues(alpha: 0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: VendorTheme.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: VendorTheme.primary),
          ),
          const SizedBox(width: VendorTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: VendorTheme.spacing8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VendorTheme.grey600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: VendorTheme.spacing16),
                VendorPrimaryButton(
                  label: buttonText,
                  onTap: onTap ?? () {},
                  isFullWidth: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard({
    required String title,
    required String status,
    required String dateRange,
    required String participants,
    required VendorBadgeType type,
  }) {
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              VendorStatusBadge(label: status, type: type),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: VendorTheme.grey500,
              ),
              const SizedBox(width: VendorTheme.spacing4),
              Text(dateRange, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: VendorTheme.spacing16),
              Icon(Icons.people_outline, size: 16, color: VendorTheme.grey500),
              const SizedBox(width: VendorTheme.spacing4),
              Text(participants, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing16),
          const Divider(height: 1),
          const SizedBox(height: VendorTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              VendorOutlinedButton(label: 'Manage Nominations', onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard({
    required Map<String, dynamic> coupon,
    required String code,
    required String discount,
    required String usage,
    required String expiry,
  }) {
    final status = coupon['status']?.toString().toUpperCase() ?? 'DRAFT';
    final badgeType = status == 'ACTIVE'
        ? VendorBadgeType.success
        : status == 'DISABLED'
            ? VendorBadgeType.warning
            : VendorBadgeType.info;
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VendorTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
              border: Border.all(
                color: VendorTheme.primary.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Text(
                  discount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VendorTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: VendorTheme.spacing4),
                Text(
                  code,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: VendorTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VendorStatusBadge(label: status, type: badgeType),
                const SizedBox(height: VendorTheme.spacing8),
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 14,
                      color: VendorTheme.grey500,
                    ),
                    const SizedBox(width: VendorTheme.spacing4),
                    Text(usage, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: VendorTheme.spacing8),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: VendorTheme.grey500,
                    ),
                    const SizedBox(width: VendorTheme.spacing4),
                    Text(
                      expiry,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: VendorTheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openEditCouponDialog(coupon);
                  break;
                case 'duplicate':
                  _duplicateCoupon(coupon);
                  break;
                case 'activate':
                  _setCouponStatus(coupon, 'active');
                  break;
                case 'pause':
                  _setCouponStatus(coupon, 'disabled');
                  break;
                case 'delete':
                  _deleteCoupon(coupon);
                  break;
              }
            },
            itemBuilder: (context) {
              final status = coupon['status']?.toString().toLowerCase() ?? '';
              final isActive = status == 'active';
              return [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem<String>(
                  value: 'duplicate',
                  child: Text('Duplicate'),
                ),
                PopupMenuItem<String>(
                  value: isActive ? 'pause' : 'activate',
                  child: Text(isActive ? 'Pause Coupon' : 'Activate Coupon'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _CouponDialog extends StatefulWidget {
  const _CouponDialog({
    required this.onSave,
    this.coupon,
  });

  final Map<String, dynamic>? coupon;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data) onSave;

  @override
  State<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends State<_CouponDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _discountValueController;
  late final TextEditingController _minimumOrderController;
  late final TextEditingController _maximumDiscountController;
  late final TextEditingController _usageLimitController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  String _discountType = 'percentage';
  String _status = 'draft';
  bool _saving = false;
  bool _firstOrderOnly = false;

  @override
  void initState() {
    super.initState();
    final coupon = widget.coupon ?? const <String, dynamic>{};
    final now = DateTime.now();
    _codeController = TextEditingController(text: coupon['couponCode']?.toString() ?? '');
    _discountValueController = TextEditingController(
      text: coupon['discountValue']?.toString() ?? '',
    );
    _minimumOrderController = TextEditingController(
      text: coupon['minimumOrderValue']?.toString() ?? '',
    );
    _maximumDiscountController = TextEditingController(
      text: coupon['maximumDiscount']?.toString() ?? '',
    );
    _usageLimitController = TextEditingController(
      text: coupon['usageLimit']?.toString() ?? '',
    );
    _startDateController = TextEditingController(
      text: _dateText(DateTime.tryParse(coupon['startDate']?.toString() ?? '') ?? now),
    );
    _endDateController = TextEditingController(
      text: _dateText(
        DateTime.tryParse(coupon['endDate']?.toString() ?? '') ??
            now.add(const Duration(days: 7)),
      ),
    );
    _discountType = coupon['discountType']?.toString() ?? 'percentage';
    _status = coupon['status']?.toString() ?? 'draft';
    _firstOrderOnly = coupon['firstOrderOnly'] == true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _discountValueController.dispose();
    _minimumOrderController.dispose();
    _maximumDiscountController.dispose();
    _usageLimitController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String _dateText(DateTime date) {
    final value = date.toIso8601String();
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      controller.text = _dateText(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'couponCode': _codeController.text.trim().toUpperCase(),
        'discountType': _discountType,
        'discountValue': double.tryParse(_discountValueController.text.trim()) ?? 0,
        'minimumOrderValue': double.tryParse(_minimumOrderController.text.trim()) ?? 0,
        'maximumDiscount': _maximumDiscountController.text.trim().isEmpty
            ? null
            : double.tryParse(_maximumDiscountController.text.trim()),
        'usageLimit': _usageLimitController.text.trim().isEmpty
            ? null
            : int.tryParse(_usageLimitController.text.trim()),
        'startDate': _startDateController.text.trim(),
        'endDate': _endDateController.text.trim(),
        'status': _status,
        'firstOrderOnly': _firstOrderOnly,
      };
      await widget.onSave(payload);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
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
    return AlertDialog(
      title: Text(widget.coupon == null ? 'Create Coupon' : 'Edit Coupon'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Coupon Code'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Enter a code' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _discountType,
                decoration: const InputDecoration(labelText: 'Discount Type'),
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                ],
                onChanged: (value) => setState(() => _discountType = value ?? 'percentage'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountValueController,
                decoration: const InputDecoration(labelText: 'Discount Value'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a discount value';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minimumOrderController,
                decoration: const InputDecoration(labelText: 'Minimum Order'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maximumDiscountController,
                decoration: const InputDecoration(labelText: 'Maximum Discount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usageLimitController,
                decoration: const InputDecoration(labelText: 'Usage Limit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                onTap: () => _pickDate(_startDateController),
                decoration: const InputDecoration(labelText: 'Start Date'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endDateController,
                readOnly: true,
                onTap: () => _pickDate(_endDateController),
                decoration: const InputDecoration(labelText: 'End Date'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'disabled', child: Text('Paused')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'draft'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _firstOrderOnly,
                onChanged: (value) => setState(() => _firstOrderOnly = value),
                title: const Text('First order only'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}




