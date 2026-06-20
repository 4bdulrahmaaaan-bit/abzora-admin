part of '../admin_web_panel.dart';

class AdminDashboardSection extends StatelessWidget {
  const AdminDashboardSection({
    super.key,
    required this.analytics,
    required this.vendorCount,
    required this.activeRiderCount,
    required this.pendingKycCount,
    required this.revenueToday,
    required this.recentOrders,
    required this.searchQuery,
    required this.suggestions,
    required this.onSearchGlobal,
    required this.onNavigate,
    required this.formatCurrency,
    required this.storeForId,
    required this.buildOrderStatusChip,
    required this.buildInsightTile,
    required this.searchResults,
    required this.notifications,
    required this.activityLogs,
    required this.activeVendorDrawerStore,
    required this.formatDate,
    required this.activityIconFor,
    required this.buildVendorDetailDrawer,
  });

  final AdminAnalytics? analytics;
  final int vendorCount;
  final int activeRiderCount;
  final int pendingKycCount;
  final double revenueToday;
  final List<OrderModel> recentOrders;
  final String searchQuery;
  final List<String> suggestions;
  final ValueChanged<String> onSearchGlobal;
  final ValueChanged<String> onNavigate;
  final String Function(double value) formatCurrency;
  final Store? Function(String storeId) storeForId;
  final Widget Function(String status) buildOrderStatusChip;
  final Widget Function(String text, IconData icon) buildInsightTile;
  final GlobalSearchResults searchResults;
  final List<AppNotification> notifications;
  final List<ActivityLogEntry> activityLogs;
  final Store? activeVendorDrawerStore;
  final String Function(DateTime value) formatDate;
  final IconData Function(String source) activityIconFor;
  final Widget Function(Store store) buildVendorDetailDrawer;

  @override
  Widget build(BuildContext context) {
    final recent = recentOrders.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final totalRevenue = analytics?.totalRevenue ?? 0;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (searchQuery.isNotEmpty && suggestions.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AbzioTheme.grey200),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map(
                        (item) => InkWell(
                          onTap: () =>
                              onSearchGlobal(item.split(':').last.trim()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F6F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (searchQuery.isNotEmpty && suggestions.isNotEmpty)
              const SizedBox(height: 16),
            SizedBox(
              height: 136,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MetricCard(
                    title: 'Total Orders',
                    value: analytics?.totalOrders.toString() ?? '0',
                  ),
                  _MetricCard(
                    title: 'Revenue Today',
                    value: formatCurrency(revenueToday),
                  ),
                  _MetricCard(title: 'Total Vendors', value: '$vendorCount'),
                  _MetricCard(
                    title: 'Active Riders',
                    value: '$activeRiderCount',
                  ),
                  _MetricCard(title: 'Pending KYC', value: '$pendingKycCount'),
                  _MetricCard(
                    title: 'Total Revenue',
                    value: formatCurrency(totalRevenue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _Panel(
                    title: 'Recent orders',
                    subtitle:
                        'Latest marketplace transactions with fulfillment visibility.',
                    child: recent.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No active order updates',
                            subtitle: 'Platform running smoothly.',
                          )
                        : Column(
                            children: recent.take(8).map((order) {
                              final invoice = order.invoiceNumber.isEmpty
                                  ? order.id
                                  : order.invoiceNumber;
                              final store = storeForId(order.storeId);
                              final status = order.status.trim();
                              final eta = order.deliveryPromise.trim().isEmpty
                                  ? 'ETA recalculating'
                                  : order.deliveryPromise;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Order ID: $invoice',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Vendor: ${store?.name ?? order.storeId} | Amount: ${formatCurrency(order.totalAmount)} | ETA: $eta',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [buildOrderStatusChip(status)],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _Panel(
                    title: 'AI Operational Insights',
                    subtitle:
                        'Suggested interventions based on live marketplace behavior.',
                    child:
                        (searchResults.users.isEmpty &&
                            searchResults.stores.isEmpty &&
                            searchResults.orders.isEmpty)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildInsightTile(
                                'Increase riders in Zone B',
                                Icons.electric_bike_rounded,
                              ),
                              buildInsightTile(
                                'Sneakers trending across premium category',
                                Icons.trending_up_rounded,
                              ),
                              buildInsightTile(
                                'Vendor return anomaly detected',
                                Icons.warning_amber_rounded,
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: () => onNavigate('operations'),
                                  child: const Text('Review'),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SearchMetric(
                                label: 'Users',
                                value: searchResults.users.length,
                              ),
                              _SearchMetric(
                                label: 'Stores',
                                value: searchResults.stores.length,
                              ),
                              _SearchMetric(
                                label: 'Orders',
                                value: searchResults.orders.length,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Panel(
                    title: 'Live activity feed',
                    subtitle:
                        'Realtime operational actions across users, vendors, riders, and payouts.',
                    child: notifications.isEmpty && activityLogs.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No alerts right now',
                            subtitle: 'Platform running smoothly',
                          )
                        : Column(
                            children: [
                              ...notifications.take(4).map((notification) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    activityIconFor(notification.title),
                                    color: const Color(0xFF9C7222),
                                  ),
                                  title: Text(
                                    notification.title,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    notification.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    formatDate(notification.timestamp),
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                              ...activityLogs.take(4).map((entry) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    activityIconFor(entry.action),
                                    color: const Color(0xFF9C7222),
                                  ),
                                  title: Text(
                                    entry.action
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    entry.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    formatDate(entry.timestamp),
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Panel(
                    title: 'Recent admin actions',
                    subtitle: 'Fast scan trail of operational interventions.',
                    child: activityLogs.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No actions recorded yet',
                            subtitle:
                                'Admin activity will appear here once actions are triggered.',
                          )
                        : Column(
                            children: activityLogs.take(8).map((entry) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.bolt_rounded),
                                title: Text(
                                  entry.message,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${entry.actorRole} - ${entry.targetType}',
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                  ),
                                ),
                                trailing: Text(
                                  formatDate(entry.timestamp),
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (activeVendorDrawerStore != null)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: buildVendorDetailDrawer(activeVendorDrawerStore!),
          ),
      ],
    );
  }
}
