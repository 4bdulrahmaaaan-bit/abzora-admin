import 'package:flutter/material.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/support_api.dart';

class VendorSupportCenterScreen extends StatefulWidget {
  const VendorSupportCenterScreen({super.key});

  @override
  State<VendorSupportCenterScreen> createState() =>
      _VendorSupportCenterScreenState();
}

class _VendorSupportCenterScreenState extends State<VendorSupportCenterScreen> {
  final SupportApi _api = SupportApi();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _api.getAnalytics(),
        _api.getTickets(limit: 50),
      ]);

      setState(() {
        _analytics = futures[0]['data'] ?? {};
        _tickets = (futures[1]['data']['tickets'] as List)
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

  void _openCreateTicketDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'technical';
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Support Ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items:
                    [
                          'technical',
                          'payout',
                          'orders',
                          'returns',
                          'store',
                          'other',
                        ]
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged: (val) => category = val!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: ['low', 'normal', 'high', 'critical']
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (val) => priority = val!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.createTicket({
                  'subject': titleCtrl.text,
                  'description': descCtrl.text,
                  'category': category,
                  'priority': priority,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchData();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _viewTicket(String ticketId) {
    // In a full app, this would push a chat screen
    // For now, we'll just show a dialog to demonstrate adding messages
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ticket $ticketId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: msgCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Send a reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.addMessage(ticketId, {'message': msgCtrl.text});
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchData();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Support Center',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openCreateTicketDialog,
          ),
        ],
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
            Text(
              'Failed to load tickets: $_error',
              textAlign: TextAlign.center,
            ),
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
          Text(
            'Recent Tickets',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: VendorTheme.spacing16),
          ..._tickets.map(_buildTicketCard),
          if (_tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No support tickets found.',
                  style: TextStyle(color: VendorTheme.grey500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    final open = _analytics['openTickets'] ?? 0;
    final resolved = _analytics['resolvedTickets'] ?? 0;
    final rate = (_analytics['resolutionRate'] ?? 0.0) as num;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Open Tickets',
                value: open.toString(),
                icon: Icons.support_agent_outlined,
                trend: 0,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Resolved',
                value: resolved.toString(),
                icon: Icons.check_circle_outline,
                trend: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        VendorMetricCard(
          title: 'Resolution Rate',
          value: '${rate.toStringAsFixed(1)}%',
          icon: Icons.analytics_outlined,
          trend: 0,
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final status = t['status'] ?? 'open';
    final type = status == 'open' || status == 'pending'
        ? VendorBadgeType.warning
        : VendorBadgeType.success;

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
                t['ticketId'] ?? '',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              VendorStatusBadge(label: status, type: type),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing8),
          Text(
            t['subject'] ?? 'No Subject',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: VendorTheme.spacing4),
          Text(
            t['description'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _viewTicket(t['ticketId']),
                child: const Text('View Ticket'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
