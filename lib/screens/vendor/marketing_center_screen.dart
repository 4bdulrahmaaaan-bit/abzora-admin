import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/campaign_api.dart';
import '../../services/coupon_api.dart';

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
            Tab(text: 'Coupons'),
            Tab(text: 'Flash Sales'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCampaignsTab(),
          _buildCouponsTab(),
          _buildFlashSalesTab(),
        ],
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
              title: 'Store Coupons',
              subtitle:
                  'Create special discounts to reward loyal customers and drive conversions.',
              buttonText: 'Create Coupon',
              icon: Icons.local_activity_outlined,
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
                  onTap: () {},
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
    required String code,
    required String discount,
    required String usage,
    required String expiry,
  }) {
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
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
    );
  }
}
