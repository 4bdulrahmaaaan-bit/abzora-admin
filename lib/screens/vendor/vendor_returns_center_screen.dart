import 'package:flutter/material.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/returns_api.dart';
import '../../services/return_analytics_api.dart';
import '../../services/app_config.dart';

class VendorReturnsCenterScreen extends StatefulWidget {
  const VendorReturnsCenterScreen({super.key});

  @override
  State<VendorReturnsCenterScreen> createState() =>
      _VendorReturnsCenterScreenState();
}

class _VendorReturnsCenterScreenState extends State<VendorReturnsCenterScreen>
    with SingleTickerProviderStateMixin {
  final ReturnsApi _returnsApi = ReturnsApi();
  final ReturnAnalyticsApi _analyticsApi = ReturnAnalyticsApi();

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _returns = [];
  List<Map<String, dynamic>> _refunds = [];
  List<Map<String, dynamic>> _exchanges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _analyticsApi.getAnalytics(),
        _returnsApi.getReturns(limit: 50),
        _returnsApi.getRefunds(limit: 50),
        _returnsApi.getExchanges(limit: 50),
      ]);

      if (!mounted) return;

      setState(() {
        _analytics = futures[0]['data'] ?? {};
        _returns = (futures[1]['data']['returns'] as List)
            .cast<Map<String, dynamic>>();
        _refunds = (futures[2]['data']['refunds'] as List)
            .cast<Map<String, dynamic>>();
        _exchanges = (futures[3]['data']['exchanges'] as List)
            .cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Returns Center',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: VendorTheme.primary,
          unselectedLabelColor: VendorTheme.grey500,
          indicatorColor: VendorTheme.primary,
          tabs: const [
            Tab(text: 'Returns'),
            Tab(text: 'Refunds'),
            Tab(text: 'Exchanges'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VendorTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load data: $_error', textAlign: TextAlign.center),
            const SizedBox(height: VendorTheme.spacing16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: VendorTheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        children: [
          _buildAnalyticsGrid(),
          const SizedBox(height: VendorTheme.spacing24),
          _buildTabContent(),
          const SizedBox(height: VendorTheme.spacing32),
        ],
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    final returnRate = _analytics['returnRate']?.toDouble() ?? 0.0;
    final refundRate = _analytics['refundRate']?.toDouble() ?? 0.0;
    final tbyb = _analytics['tbyb'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Returns Analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: VendorTheme.spacing16),
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Return Rate',
                value: '${returnRate.toStringAsFixed(1)}%',
                icon: Icons.keyboard_return_outlined,
                trend: 0,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Refund Rate',
                value: '${refundRate.toStringAsFixed(1)}%',
                icon: Icons.money_off_outlined,
                trend: 0,
              ),
            ),
          ],
        ),
        if (AppConfig.enableLocalRiderDelivery) ...[
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: VendorMetricCard(
                  title: 'TBYB Returns',
                  value:
                      '${(tbyb['trialReturnRate']?.toDouble() ?? 0.0).toStringAsFixed(1)}%',
                  icon: Icons.assignment_return_outlined,
                  trend: 0,
                ),
              ),
              const SizedBox(width: VendorTheme.spacing16),
              Expanded(
                child: VendorMetricCard(
                  title: 'Avg Trial Days',
                  value: (tbyb['avgTrialDaysUsed']?.toDouble() ?? 0.0)
                      .toStringAsFixed(1),
                  icon: Icons.timelapse_outlined,
                  trend: 0,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTabContent() {
    if (_tabController.index == 0) {
      return _buildList(_returns, 'Returns', _buildReturnCard);
    }
    if (_tabController.index == 1) {
      return _buildList(_refunds, 'Refunds', _buildRefundCard);
    }
    if (_tabController.index == 2) {
      return _buildList(_exchanges, 'Exchanges', _buildExchangeCard);
    }
    return const SizedBox();
  }

  Widget _buildList(
    List<Map<String, dynamic>> items,
    String title,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No $title found.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: VendorTheme.grey500),
          ),
        ),
      );
    }
    return Column(children: items.map((item) => builder(item)).toList());
  }

  Widget _buildReturnCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'requested';
    final reason = req['reason'] ?? 'No reason';
    final type = req['returnType'] ?? 'return';

    return PremiumVendorCard(
      margin: const EdgeInsets.only(bottom: VendorTheme.spacing16),
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${req['orderId']?.substring(0, 8) ?? ''}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              VendorStatusBadge(
                label: status.toUpperCase(),
                type: status == 'requested'
                    ? VendorBadgeType.warning
                    : (status == 'closed'
                          ? VendorBadgeType.success
                          : VendorBadgeType.info),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing8),
          Text(
            'Type: ${type.toUpperCase()}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: VendorTheme.grey500),
          ),
          const SizedBox(height: VendorTheme.spacing4),
          Text(
            'Reason: $reason',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (status == 'requested') ...[
            const SizedBox(height: VendorTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      _updateStatus(req['_id'], 'rejected', 'returns'),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: VendorTheme.error),
                  ),
                ),
                const SizedBox(width: VendorTheme.spacing8),
                ElevatedButton(
                  onPressed: () =>
                      _updateStatus(req['_id'], 'approved', 'returns'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'requested';
    final reason = req['reason'] ?? 'No reason';
    final amount = req['amount'] ?? 0;

    return PremiumVendorCard(
      margin: const EdgeInsets.only(bottom: VendorTheme.spacing16),
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${req['orderId']?.substring(0, 8) ?? ''}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              VendorStatusBadge(
                label: status.toUpperCase(),
                type: status == 'requested'
                    ? VendorBadgeType.warning
                    : (status == 'refunded'
                          ? VendorBadgeType.success
                          : VendorBadgeType.info),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing8),
          Text(
            'Amount: \u20B9$amount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: VendorTheme.success,
            ),
          ),
          const SizedBox(height: VendorTheme.spacing4),
          Text(
            'Reason: $reason',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (status == 'requested') ...[
            const SizedBox(height: VendorTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      _updateStatus(req['_id'], 'rejected', 'refunds'),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: VendorTheme.error),
                  ),
                ),
                const SizedBox(width: VendorTheme.spacing8),
                ElevatedButton(
                  onPressed: () =>
                      _updateStatus(req['_id'], 'approved', 'refunds'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExchangeCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'requested';
    final reason = req['reason'] ?? 'No reason';

    return PremiumVendorCard(
      margin: const EdgeInsets.only(bottom: VendorTheme.spacing16),
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${req['orderId']?.substring(0, 8) ?? ''}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              VendorStatusBadge(
                label: status.toUpperCase(),
                type: status == 'requested'
                    ? VendorBadgeType.warning
                    : (status == 'closed'
                          ? VendorBadgeType.success
                          : VendorBadgeType.info),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing8),
          Text(
            'Reason: $reason',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (status == 'requested') ...[
            const SizedBox(height: VendorTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      _updateStatus(req['_id'], 'rejected', 'exchanges'),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: VendorTheme.error),
                  ),
                ),
                const SizedBox(width: VendorTheme.spacing8),
                ElevatedButton(
                  onPressed: () =>
                      _updateStatus(req['_id'], 'approved', 'exchanges'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(String id, String status, String type) async {
    try {
      if (type == 'returns') {
        await _returnsApi.updateReturnStatus(id, status);
      } else if (type == 'refunds') {
        await _returnsApi.updateRefundStatus(id, status);
      } else if (type == 'exchanges') {
        await _returnsApi.updateExchangeStatus(id, status);
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }
}
