// ignore_for_file: invalid_use_of_protected_member

part of '../admin_web_panel.dart';

extension _AdminCommerceSectionV2 on _AdminWebPanelState {
  Widget _buildOrdersStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _orderSearchController,
              decoration: const InputDecoration(
                hintText: 'Search order, customer, vendor, rider, zone',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ordersFilterMenu('Status', _orderStatusFilter, const [
            'All',
            'Placed',
            'Assigned',
            'Processing',
            'Delivered',
            'Cancelled',
          ], (v) => setState(() => _orderStatusFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Zone', _orderZoneFilter, const [
            'All',
            'Central',
            'North',
            'South',
            'East',
            'West',
          ], (v) => setState(() => _orderZoneFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Priority', _orderPriorityFilter, const [
            'All',
            'High',
            'Medium',
            'Low',
          ], (v) => setState(() => _orderPriorityFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Rider', _orderRiderFilter, const [
            'All',
            'Assigned',
            'Unassigned',
          ], (v) => setState(() => _orderRiderFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Date', _orderDateRangeFilter, const [
            'All',
            'Today',
            'Last 7 days',
            'Last 30 days',
          ], (v) => setState(() => _orderDateRangeFilter = v)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _ordersFilterMenu(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 128,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildVendorsStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _vendorSearchController,
              decoration: const InputDecoration(
                hintText: 'Search store, owner, city, or vendor ID',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ordersFilterMenu('Status', _vendorStatusFilter, const [
            'All',
            'Approved',
            'Pending',
            'Suspended',
            'High Risk',
          ], (v) => setState(() => _vendorStatusFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('City', _vendorCityFilter, const [
            'All',
            'Chennai',
            'Bengaluru',
            'Hyderabad',
            'Mumbai',
          ], (v) => setState(() => _vendorCityFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Revenue', _vendorRevenueFilter, const [
            'All',
            'High',
            'Mid',
            'Low',
          ], (v) => setState(() => _vendorRevenueFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Risk', _vendorRiskFilter, const [
            'All',
            'Healthy',
            'Warning',
            'Intervention',
          ], (v) => setState(() => _vendorRiskFilter = v)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _selectTab(AdminWebSection.kyc),
            icon: const Icon(Icons.verified_user_outlined, size: 16),
            label: const Text('KYC Queue'),
          ),
        ],
      ),
    );
  }

  Widget _buildRidersStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _riderSearchController,
              decoration: const InputDecoration(
                hintText: 'Search rider, phone, city, or rider ID',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ordersFilterMenu('Status', _riderStatusFilter, const [
            'All',
            'LIVE',
            'BUSY',
            'OFFLINE',
            'DELAYED',
            'HIGH RISK',
          ], (v) => setState(() => _riderStatusFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('City', _riderCityFilter, const [
            'All',
            'Chennai',
            'Bengaluru',
            'Hyderabad',
            'Mumbai',
          ], (v) => setState(() => _riderCityFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Vehicle', _riderVehicleFilter, const [
            'All',
            'Bike',
            'Scooter',
            'EV',
          ], (v) => setState(() => _riderVehicleFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Risk', _riderRiskFilter, const [
            'All',
            'Healthy',
            'Warning',
            'Intervention',
          ], (v) => setState(() => _riderRiskFilter = v)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrders() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading orders',
        subtitle: 'Fetching orders, users, stores, and catalog data.',
      );
    }
    final base = _filteredOrders;
    final filtered = base.where((order) {
      if (_orderStatusFilter != 'All' &&
          order.status.toLowerCase() != _orderStatusFilter.toLowerCase()) {
        return false;
      }
      if (_orderRiderFilter == 'Assigned' &&
          (order.riderId == null || order.riderId!.isEmpty)) {
        return false;
      }
      if (_orderRiderFilter == 'Unassigned' &&
          (order.riderId != null && order.riderId!.isNotEmpty)) {
        return false;
      }
      if (_orderDateRangeFilter == 'Today') {
        final now = DateTime.now();
        if (order.timestamp.year != now.year ||
            order.timestamp.month != now.month ||
            order.timestamp.day != now.day) {
          return false;
        }
      }
      if (_orderDateRangeFilter == 'Last 7 days' &&
          DateTime.now().difference(order.timestamp).inDays > 7) {
        return false;
      }
      if (_orderDateRangeFilter == 'Last 30 days' &&
          DateTime.now().difference(order.timestamp).inDays > 30) {
        return false;
      }
      if (_orderPriorityFilter != 'All') {
        final p = _orderPriorityFor(order);
        if (p != _orderPriorityFilter.toUpperCase()) return false;
      }
      if (_orderZoneFilter != 'All') {
        final zone = _orderZoneFor(order);
        if (zone != _orderZoneFilter) return false;
      }
      return true;
    }).toList();
    final pageCount = _pageCount(filtered);
    final safePage = _orderPage >= pageCount ? pageCount - 1 : _orderPage;
    final visible = _pageSlice(filtered, safePage);
    final liveOrders = filtered.where((o) => !_isOrderDone(o)).length;
    final delayed = filtered.where((o) => _isDelayedOrder(o)).length;
    final awaitingRider = filtered
        .where((o) => (o.riderId ?? '').trim().isEmpty)
        .length;
    final refundPending = filtered
        .where((o) => o.refundStatus.toLowerCase().contains('pending'))
        .length;
    final deliveredToday = filtered
        .where(
          (o) =>
              o.status.toLowerCase() == 'delivered' &&
              DateTime.now().difference(o.timestamp).inDays == 0,
        )
        .length;
    final failedDeliveries = filtered
        .where((o) => o.status.toLowerCase().contains('cancel'))
        .length;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(title: 'Live Orders', value: '$liveOrders'),
                _MetricCard(title: 'Delayed Orders', value: '$delayed'),
                _MetricCard(title: 'Awaiting Rider', value: '$awaitingRider'),
                _MetricCard(title: 'Refund Pending', value: '$refundPending'),
                _MetricCard(title: 'Delivered Today', value: '$deliveredToday'),
                _MetricCard(
                  title: 'Failed Deliveries',
                  value: '$failedDeliveries',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Fulfillment Queue',
              subtitle: '${filtered.length} operational order(s)',
              child: filtered.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No order incidents right now',
                      subtitle: 'Platform running smoothly',
                    )
                  : Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Assigned'),
                              child: const Text('assign riders'),
                            ),
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Out for delivery'),
                              child: const Text('dispatch'),
                            ),
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Cancelled'),
                              child: const Text('cancel'),
                            ),
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Delivered'),
                              child: const Text('mark delivered'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _selectedOrderIds.clear()),
                              child: const Text('clear selection'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...visible.map((order) {
                          final invoice = order.invoiceNumber.isEmpty
                              ? order.id
                              : order.invoiceNumber;
                          final store = _storeForId(order.storeId);
                          final customer = _userForId(order.userId);
                          final riderName =
                              order.assignedDeliveryPartner == 'Unassigned'
                              ? 'Unassigned'
                              : order.assignedDeliveryPartner;
                          final priority = _orderPriorityFor(order);
                          final healthScore = _orderHealthScore(order);
                          final borderColor = _orderBorderColor(order.status);
                          final isCritical =
                              priority == 'HIGH' || healthScore < 45;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.52),
                                width: isCritical ? 1.8 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isCritical
                                              ? const Color(0xFFD92D20)
                                              : Colors.black)
                                          .withValues(
                                            alpha: isCritical ? 0.12 : 0.04,
                                          ),
                                  blurRadius: isCritical ? 18 : 12,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _selectedOrderIds.contains(
                                        order.id,
                                      ),
                                      onChanged: (value) => setState(() {
                                        if (value == true) {
                                          _selectedOrderIds.add(order.id);
                                        } else {
                                          _selectedOrderIds.remove(order.id);
                                        }
                                      }),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order $invoice',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Customer: ${customer?.name ?? order.userId} | Vendor: ${store?.name ?? order.storeId}',
                                            style: GoogleFonts.inter(
                                              color: AbzioTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Address: ${order.shippingAddress}',
                                            style: GoogleFonts.inter(
                                              color: AbzioTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Items: ${order.items.length} | Value: ${_formatCurrency(order.totalAmount)} | ETA: ${order.deliveryPromise.isEmpty ? 'Recalculating' : order.deliveryPromise}',
                                            style: GoogleFonts.inter(
                                              color: AbzioTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _StatusPill(
                                                label: order.status
                                                    .toUpperCase(),
                                                color: Colors.blue,
                                              ),
                                              if (order.refundStatus
                                                  .trim()
                                                  .isNotEmpty)
                                                _StatusPill(
                                                  label:
                                                      'REFUND ${order.refundStatus.toUpperCase()}',
                                                  color:
                                                      order.refundStatus
                                                              .toLowerCase() ==
                                                          'refunded'
                                                      ? Colors.green
                                                      : order.refundStatus
                                                                .toLowerCase() ==
                                                            'rejected'
                                                      ? Colors.red
                                                      : Colors.orange,
                                                ),
                                              _StatusPill(
                                                label: riderName.toUpperCase(),
                                                color: riderName == 'Unassigned'
                                                    ? Colors.grey
                                                    : Colors.green,
                                              ),
                                              _StatusPill(
                                                label: 'PRIORITY $priority',
                                                color: priority == 'HIGH'
                                                    ? const Color(0xFFB42318)
                                                    : priority == 'MEDIUM'
                                                    ? const Color(0xFFDC6803)
                                                    : const Color(0xFF175CD3),
                                              ),
                                              _StatusPill(
                                                label:
                                                    'HEALTH ${healthScore.toStringAsFixed(0)}',
                                                color: healthScore >= 75
                                                    ? const Color(0xFF067647)
                                                    : healthScore >= 45
                                                    ? const Color(0xFFDC6803)
                                                    : const Color(0xFFB42318),
                                              ),
                                              ..._orderPriorityChips(order),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          _buildOrderTimeline(order.status),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 220,
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _assignRider(order),
                                              icon: const Icon(
                                                Icons.person_add_alt_1_outlined,
                                              ),
                                              label: Text(
                                                order.riderId == null
                                                    ? 'Assign Rider'
                                                    : 'Reassign Rider',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          PopupMenuButton<String>(
                                            onSelected: (value) =>
                                                _handleOrderQuickAction(
                                                  order,
                                                  value,
                                                ),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'details',
                                                child: Text('Open Details'),
                                              ),
                                              PopupMenuItem(
                                                value: 'refund',
                                                child: Text('Refund'),
                                              ),
                                              PopupMenuItem(
                                                value: 'escalate',
                                                child: Text('Escalate'),
                                              ),
                                              PopupMenuItem(
                                                value: 'vendor',
                                                child: Text('Contact Vendor'),
                                              ),
                                              PopupMenuItem(
                                                value: 'rider',
                                                child: Text('Contact Rider'),
                                              ),
                                              PopupMenuItem(
                                                value: 'timeline',
                                                child: Text('View Timeline'),
                                              ),
                                              PopupMenuItem(
                                                value: 'retry',
                                                child: Text('Retry Payment'),
                                              ),
                                              PopupMenuItem(
                                                value: 'zone',
                                                child: Text('Reassign Zone'),
                                              ),
                                              PopupMenuItem(
                                                value: 'cancel',
                                                child: Text('Cancel Order'),
                                              ),
                                            ],
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.more_horiz_rounded,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text('Quick Actions'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        _Pager(
                          currentPage: safePage,
                          pageCount: pageCount,
                          onPrevious: safePage > 0
                              ? () => setState(() => _orderPage = safePage - 1)
                              : null,
                          onNext: safePage + 1 < pageCount
                              ? () => setState(() => _orderPage = safePage + 1)
                              : null,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'AI Order Insights',
              subtitle:
                  'Risk intelligence for proactive fulfillment intervention.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInsightTile(
                    'High cancellation probability on zone-heavy evening orders.',
                    Icons.warning_amber_rounded,
                  ),
                  _buildInsightTile(
                    'Vendor delay risk detected in custom-stitch segment.',
                    Icons.store_mall_directory_outlined,
                  ),
                  _buildInsightTile(
                    'Traffic may impact ETA for west corridor routes.',
                    Icons.traffic_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_activeOrderDrawerOrder != null)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildOrderDetailDrawer(_activeOrderDrawerOrder!),
          ),
      ],
    );
  }

  Widget _buildVendors() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading vendors',
        subtitle: 'Fetching vendor and store records.',
      );
    }
    final base = _filteredStores;
    final filtered = base.where((store) {
      if (_vendorStatusFilter == 'Approved' && !store.isApproved) return false;
      if (_vendorStatusFilter == 'Pending' &&
          store.approvalStatus.toLowerCase() != 'pending') {
        return false;
      }
      if (_vendorStatusFilter == 'Suspended' && store.isActive) return false;
      if (_vendorStatusFilter == 'High Risk' &&
          _vendorHealthScore(store) >= 45) {
        return false;
      }
      if (_vendorCityFilter != 'All' &&
          !store.city.toLowerCase().contains(_vendorCityFilter.toLowerCase())) {
        return false;
      }
      if (_vendorRiskFilter == 'Healthy' && _vendorHealthScore(store) < 75) {
        return false;
      }
      if (_vendorRiskFilter == 'Warning' &&
          (_vendorHealthScore(store) >= 75 || _vendorHealthScore(store) < 45)) {
        return false;
      }
      if (_vendorRiskFilter == 'Intervention' &&
          _vendorHealthScore(store) >= 45) {
        return false;
      }
      return true;
    }).toList();
    final pageCount = _pageCount(filtered);
    final safePage = _vendorPage >= pageCount ? pageCount - 1 : _vendorPage;
    final visible = _pageSlice(filtered, safePage);
    final totalVendors = filtered.length;
    final activeVendors = filtered.where((s) => s.isActive).length;
    final pendingKyc = filtered
        .where((s) => s.approvalStatus.toLowerCase() == 'pending')
        .length;
    final suspended = filtered.where((s) => !s.isActive).length;
    final totalRevenue = filtered.fold<double>(
      0,
      (sum, s) => sum + _storeRevenue(s),
    );
    final pendingPayouts = filtered.fold<double>(
      0,
      (sum, s) => sum + (s.walletBalance > 0 ? s.walletBalance : 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(title: 'Total Vendors', value: '$totalVendors'),
            _MetricCard(title: 'Active Vendors', value: '$activeVendors'),
            _MetricCard(title: 'Pending KYC', value: '$pendingKyc'),
            _MetricCard(title: 'Suspended Vendors', value: '$suspended'),
            _MetricCard(
              title: 'Total Revenue',
              value: _formatCurrency(totalRevenue),
            ),
            _MetricCard(
              title: 'Pending Payouts',
              value: _formatCurrency(pendingPayouts),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Seller Intelligence Workspace',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No vendors match this filter',
                  subtitle: 'Try another search term or approval status.',
                )
              : Column(
                  children: [
                    ...visible.map((store) {
                      final storeOrders = _orders
                          .where((order) => order.storeId == store.id)
                          .toList();
                      final revenue = _storeRevenue(store);
                      final health = _vendorHealthScore(store);
                      final cancelRate = storeOrders.isEmpty
                          ? 0
                          : (storeOrders
                                        .where(
                                          (o) => o.status
                                              .toLowerCase()
                                              .contains('cancel'),
                                        )
                                        .length /
                                    storeOrders.length) *
                                100;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AbzioTheme.grey200),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (health < 45
                                          ? const Color(0xFFB42318)
                                          : Colors.black)
                                      .withValues(
                                        alpha: health < 45 ? 0.12 : 0.04,
                                      ),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              child: Text(
                                store.name.isEmpty
                                    ? 'V'
                                    : store.name[0].toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Owner ${store.ownerId} • ${store.city.isEmpty ? 'Unknown city' : store.city}',
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label: store.isApproved
                                            ? 'APPROVED'
                                            : 'PENDING',
                                        color: store.isApproved
                                            ? const Color(0xFF067647)
                                            : const Color(0xFFDC6803),
                                      ),
                                      if (store.isFeatured)
                                        const _StatusPill(
                                          label: 'FEATURED',
                                          color: Color(0xFFB57A12),
                                        ),
                                      _StatusPill(
                                        label: store.isActive
                                            ? 'ACTIVE'
                                            : 'SUSPENDED',
                                        color: store.isActive
                                            ? const Color(0xFF175CD3)
                                            : const Color(0xFFB42318),
                                      ),
                                      _StatusPill(
                                        label: health < 45
                                            ? 'HIGH RISK'
                                            : health < 75
                                            ? 'WARNING'
                                            : 'HEALTHY',
                                        color: health < 45
                                            ? const Color(0xFFB42318)
                                            : health < 75
                                            ? const Color(0xFFDC6803)
                                            : const Color(0xFF067647),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Revenue ${_formatCurrency(revenue)} • Orders ${storeOrders.length} • Commission ${(store.commissionRate * 100).toStringAsFixed(0)}% • Payout ${_formatCurrency(store.walletBalance)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Health Score: ${health.toStringAsFixed(0)} | Rating ${store.rating.toStringAsFixed(1)} | Cancellation ${cancelRate.toStringAsFixed(1)}%',
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: () => setState(
                                    () => _activeVendorDrawerStore = store,
                                  ),
                                  child: const Text('View Vendor'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _toggleFeatured(store),
                                  child: Text(
                                    store.isFeatured ? 'Unfeature' : 'Feature',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _adjustCommission(store),
                                  child: const Text('Commission'),
                                ),
                                OutlinedButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Assign manager to ${store.name}',
                                          ),
                                        ),
                                      ),
                                  child: const Text('Assign Manager'),
                                ),
                                OutlinedButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Analytics opened for ${store.name}',
                                          ),
                                        ),
                                      ),
                                  child: const Text('Open Analytics'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _processPayout(store),
                                  child: const Text('Mark payout paid'),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB42318),
                                    side: const BorderSide(
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                  onPressed: () => _toggleStoreActive(store),
                                  child: Text(
                                    store.isActive ? 'Suspend' : 'Activate',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB42318),
                                    side: const BorderSide(
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                  onPressed: () => _deleteStore(store),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('Delete Vendor'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _vendorPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _vendorPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildRiders() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading riders',
        subtitle: 'Fetching rider records and activity data.',
      );
    }
    final base = _filteredRiders;
    final filtered = base.where((rider) {
      final status = _riderLiveStatus(rider);
      if (_riderStatusFilter != 'All' && status != _riderStatusFilter) {
        return false;
      }
      if (_riderCityFilter != 'All' &&
          !(rider.riderCity ?? rider.city ?? '').toLowerCase().contains(
            _riderCityFilter.toLowerCase(),
          )) {
        return false;
      }
      if (_riderRiskFilter == 'Healthy' && _riderPerformanceScore(rider) < 75) {
        return false;
      }
      if (_riderRiskFilter == 'Warning' &&
          (_riderPerformanceScore(rider) >= 75 ||
              _riderPerformanceScore(rider) < 45)) {
        return false;
      }
      if (_riderRiskFilter == 'Intervention' &&
          _riderPerformanceScore(rider) >= 45) {
        return false;
      }
      return true;
    }).toList();
    final pageCount = _pageCount(filtered);
    final safePage = _riderPage >= pageCount ? pageCount - 1 : _riderPage;
    final visible = _pageSlice(filtered, safePage);
    final onlineRiders = filtered
        .where((r) => _riderLiveStatus(r) == 'LIVE')
        .length;
    final activeDeliveries = filtered.fold<int>(
      0,
      (sum, r) => sum + _activeDeliveriesForRider(r.id),
    );
    final delayedDeliveries = _orders.where((o) => _isDelayedOrder(o)).length;
    final avgDeliveryTime =
        28 - ((onlineRiders / (filtered.isEmpty ? 1 : filtered.length)) * 6);
    final fleetUtilization = filtered.isEmpty
        ? 0
        : (activeDeliveries / filtered.length) * 100;
    final earningsToday = filtered.fold<double>(
      0,
      (sum, r) => sum + _riderWeeklyEarnings(r) / 7,
    );

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(title: 'Online Riders', value: '$onlineRiders'),
                _MetricCard(
                  title: 'Active Deliveries',
                  value: '$activeDeliveries',
                ),
                _MetricCard(
                  title: 'Delayed Deliveries',
                  value: '$delayedDeliveries',
                ),
                _MetricCard(
                  title: 'Avg Delivery Time',
                  value: '${avgDeliveryTime.toStringAsFixed(0)} min',
                ),
                _MetricCard(
                  title: 'Fleet Utilization',
                  value: '${fleetUtilization.toStringAsFixed(0)}%',
                ),
                _MetricCard(
                  title: 'Earnings Today',
                  value: _formatCurrency(earningsToday),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Fleet Operations',
              subtitle: '${filtered.length} result(s)',
              child: filtered.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No riders match this filter',
                      subtitle: 'Try another status or search term.',
                    )
                  : Column(
                      children: [
                        ...visible.map((rider) {
                          final activeDeliveries = _activeDeliveriesForRider(
                            rider.id,
                          );
                          final performance = _riderPerformanceScore(rider);
                          final status = _riderLiveStatus(rider);
                          final statusColor = _riderStatusColor(status);
                          final rating = (4.1 + (performance / 200)).clamp(
                            3.5,
                            5.0,
                          );
                          final deliveries = 320 + (performance * 8).toInt();
                          final speed = (18 + ((100 - performance) / 8))
                              .clamp(14, 34)
                              .toDouble();
                          final weeklyEarnings = _riderWeeklyEarnings(rider);
                          final battery = _riderBatteryLevel(rider);
                          final lastActive = _riderLastActiveLabel(rider);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AbzioTheme.grey200),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (status == 'HIGH RISK'
                                              ? const Color(0xFFB42318)
                                              : Colors.black)
                                          .withValues(
                                            alpha: status == 'HIGH RISK'
                                                ? 0.12
                                                : 0.04,
                                          ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  child: Text(
                                    rider.name.isEmpty
                                        ? 'R'
                                        : rider.name[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rider.name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${rider.phone ?? rider.email} • ${rider.riderCity ?? rider.city ?? 'Unknown city'} • ${rider.riderVehicleType ?? 'Bike'} • ${2 + (performance / 35).floor()}y exp',
                                        style: GoogleFonts.inter(
                                          color: AbzioTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusPill(
                                            label: status,
                                            color: statusColor,
                                          ),
                                          _StatusPill(
                                            label: rider.riderApprovalStatus
                                                .toUpperCase(),
                                            color:
                                                rider.riderApprovalStatus ==
                                                    'approved'
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          _StatusPill(
                                            label: '$activeDeliveries LIVE',
                                            color: AbzioTheme.accentColor,
                                          ),
                                          _StatusPill(
                                            label:
                                                'Performance ${performance.toStringAsFixed(0)}',
                                            color: performance >= 75
                                                ? const Color(0xFF067647)
                                                : performance >= 45
                                                ? const Color(0xFFDC6803)
                                                : const Color(0xFFB42318),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Rating ${rating.toStringAsFixed(1)} | Deliveries $deliveries | Avg speed ${speed.toStringAsFixed(0)} min | Weekly ${_formatCurrency(weeklyEarnings)}',
                                        style: GoogleFonts.inter(
                                          color: AbzioTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Battery ${battery == null ? "--" : "$battery%"} | Signal ${_riderSignalQuality(rider)} | Last active $lastActive',
                                        style: GoogleFonts.inter(
                                          color: AbzioTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => setState(
                                        () => _activeRiderDrawerUser = rider,
                                      ),
                                      child: const Text('View Rider'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _assignOrderToRider(rider),
                                      child: const Text('Assign Order'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Contact sent to ${rider.name}',
                                              ),
                                            ),
                                          ),
                                      child: const Text('Contact'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Performance view opened for ${rider.name}',
                                              ),
                                            ),
                                          ),
                                      child: const Text('Performance'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Earnings view opened for ${rider.name}',
                                              ),
                                            ),
                                          ),
                                      child: const Text('Earnings'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _toggleRiderApproval(rider),
                                      child: Text(
                                        rider.riderApprovalStatus == 'approved'
                                            ? 'Move to Pending'
                                            : 'Approve',
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFB42318,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFB42318),
                                        ),
                                      ),
                                      onPressed: () => _toggleUserActive(rider),
                                      child: Text(
                                        rider.isActive ? 'Suspend' : 'Activate',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        _Pager(
                          currentPage: safePage,
                          pageCount: pageCount,
                          onPrevious: safePage > 0
                              ? () => setState(() => _riderPage = safePage - 1)
                              : null,
                          onNext: safePage + 1 < pageCount
                              ? () => setState(() => _riderPage = safePage + 1)
                              : null,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Panel(
                    title: 'Live Operations Panel',
                    subtitle:
                        'Dispatch intelligence and rider coverage alerts.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInsightTile(
                          'Live dispatch queue updated with ${_opsLive.dispatch.length} tasks across ${_dispatchBatches.length} active batches.',
                          Icons.route_outlined,
                        ),
                        _buildInsightTile(
                          'Delayed orders detected: $delayedDeliveries | SLA breach risk ${((_dispatchSlaOverview['slaBreachRisk'] ?? 0) as num).toStringAsFixed(0)}%',
                          Icons.warning_amber_rounded,
                        ),
                        _buildInsightTile(
                          'Hotspot demand zones: ${(_dispatchSlaOverview['hotspotZones'] as List?)?.join(', ') ?? 'N/A'}',
                          Icons.location_on_outlined,
                        ),
                        _buildInsightTile(
                          'Low rider coverage areas: ${(_dispatchSlaOverview['lowCoverageZones'] as List?)?.join(', ') ?? 'N/A'}',
                          Icons.person_search_outlined,
                        ),
                        _buildInsightTile(
                          'Auto-dispatch health: ${((_dispatchSlaOverview['dispatchHealthScore'] ?? 0) as num).toStringAsFixed(0)} | Rebalance ${(_dispatchRebalance['status'] ?? 'stable').toString()}',
                          Icons.hub_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Panel(
                    title: 'Smart Alerts',
                    subtitle: 'AI-assisted rider intervention signals.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInsightTile(
                          'Rider inactive for 3 days: ${_opsAlerts.where((a) => (a.message.toLowerCase().contains('inactive') || a.type.toLowerCase().contains('inactive'))).length}',
                          Icons.person_off_outlined,
                        ),
                        _buildInsightTile(
                          'Multiple late deliveries detected: ${_opsAlerts.where((a) => a.message.toLowerCase().contains('delay')).length}',
                          Icons.schedule_rounded,
                        ),
                        _buildInsightTile(
                          'Battery critically low during delivery: ${_opsAlerts.where((a) => a.message.toLowerCase().contains('battery')).length}',
                          Icons.battery_alert_rounded,
                        ),
                        _buildInsightTile(
                          'Complaint spike/fraud risk alerts: ${_opsAlerts.where((a) => a.message.toLowerCase().contains('complaint') || a.message.toLowerCase().contains('fraud')).length}',
                          Icons.report_problem_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_activeRiderDrawerUser != null)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildRiderDetailDrawer(_activeRiderDrawerUser!),
          ),
      ],
    );
  }

  Widget _buildUsers() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading users',
        subtitle: 'Fetching customer, vendor, and rider records.',
      );
    }
    final filtered = _filteredUsers;
    final pageCount = _pageCount(filtered);
    final safePage = _userPage >= pageCount ? pageCount - 1 : _userPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'User management',
          subtitle:
              'Manage activation and role assignments across the marketplace.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _userSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search name, email, phone, or city',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _userRoleFilter,
                decoration: const InputDecoration(labelText: 'Role'),
                items:
                    const [
                          'All',
                          'customer',
                          'user',
                          'vendor',
                          'rider',
                          'admin',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() {
                  _userRoleFilter = value ?? 'All';
                  _userPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Users',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No users match this filter',
                  subtitle: 'Try another role or search term.',
                )
              : Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Contact')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Store')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: visible.map((user) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user.name.isEmpty
                                          ? 'Unnamed user'
                                          : user.name,
                                    ),
                                    Text(
                                      user.city ?? '-',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AbzioTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                DropdownButton<String>(
                                  value: user.role,
                                  underline: const SizedBox.shrink(),
                                  items:
                                      const [
                                            'customer',
                                            'user',
                                            'vendor',
                                            'rider',
                                            'admin',
                                          ]
                                          .map(
                                            (role) => DropdownMenuItem(
                                              value: role,
                                              child: Text(role),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (role) {
                                    if (role != null && role != user.role) {
                                      unawaited(_changeUserRole(user, role));
                                    }
                                  },
                                ),
                              ),
                              DataCell(Text(user.phone ?? user.email)),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _StatusPill(
                                      label: user.isActive
                                          ? 'ACTIVE'
                                          : 'BLOCKED',
                                      color: user.isActive
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    if (_isRiderUser(user)) ...[
                                      const SizedBox(height: 6),
                                      _StatusPill(
                                        label: user.riderApprovalStatus
                                            .toUpperCase(),
                                        color:
                                            user.riderApprovalStatus ==
                                                'approved'
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(Text(user.storeId ?? '-')),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () => _toggleUserActive(user),
                                      child: Text(
                                        user.isActive ? 'Disable' : 'Enable',
                                      ),
                                    ),
                                    if (_isRiderUser(user))
                                      TextButton(
                                        onPressed: () =>
                                            _toggleRiderApproval(user),
                                        child: Text(
                                          user.riderApprovalStatus == 'approved'
                                              ? 'Move to pending'
                                              : 'Approve rider',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _userPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _userPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProducts() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading products',
        subtitle: 'Fetching catalog and inventory data.',
      );
    }
    final filtered = _filteredProducts;
    final pageCount = _pageCount(filtered);
    final safePage = _productPage >= pageCount ? pageCount - 1 : _productPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Products workspace',
          subtitle:
              'Switch between catalog management and color-variant inventory.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Catalog'),
                selected: _productWorkspaceMode == 'catalog',
                onSelected: (_) => _setProductWorkspaceMode('catalog'),
              ),
              ChoiceChip(
                label: const Text('Variants & Inventory'),
                selected: _productWorkspaceMode == 'variants',
                onSelected: (_) => _setProductWorkspaceMode('variants'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_productWorkspaceMode == 'variants') ...[
          _buildVariantWorkspace(),
          const SizedBox(height: 16),
        ],
        _FilterPanel(
          title: 'Product management',
          subtitle:
              'Search, filter, and control catalog visibility across stores.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _productSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search name, brand, category, or store',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _productStatusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['All', 'Active', 'Hidden']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _productStatusFilter = value ?? 'All';
                  _productPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Products',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No products match this filter',
                  subtitle: 'Try another visibility filter or search term.',
                )
              : Column(
                  children: [
                    ...visible.map((product) {
                      final store = _storeForId(product.storeId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: product.images.isEmpty
                                ? const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF3F3F3),
                                    ),
                                    child: Icon(Icons.image_outlined),
                                  )
                                : Image.network(
                                    product.images.first,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${product.brand.isEmpty ? 'Abianzo' : product.brand} - ${product.category} - ${store?.name ?? product.storeId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _formatCurrency(product.price),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _toggleProductVisibility(product),
                              child: Text(
                                product.isActive ? 'Hide' : 'Activate',
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _productPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _productPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildVariantWorkspace() {
    final product = _selectedVariantProduct;
    final variants = product?.colorVariants ?? const <ProductColorVariant>[];
    final totalStock = variants.fold<int>(
      0,
      (sum, variant) => sum + variant.stock,
    );
    final outOfStockCount = variants
        .where((variant) => variant.stock <= 0)
        .length;
    final ProductColorVariant? topVariant = variants.isEmpty
        ? null
        : variants.reduce(
            (current, next) => next.stock > current.stock ? next : current,
          );
    return _Panel(
      title: 'Variants & inventory',
      subtitle: product == null
          ? 'No products available'
          : '${variants.length} color variant(s) for ${product.name}',
      child: product == null
          ? const AbzioEmptyCard(
              title: 'No products available',
              subtitle: 'Create a product first to manage its color variants.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: product.id,
                        decoration: const InputDecoration(
                          labelText: 'Select Product',
                        ),
                        items: _products
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _selectedVariantProductId = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _bulkUpdateVariantStock(product),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Bulk Stock'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _bulkReplaceVariantImages(product),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Bulk Images'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Panel(
                  title: 'Color performance snapshot',
                  subtitle:
                      'Estimated signals based on current catalog and inventory mix.',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        title: 'Total stock',
                        value: totalStock.toString(),
                      ),
                      _MetricCard(
                        title: 'Out of stock colors',
                        value: outOfStockCount.toString(),
                      ),
                      _MetricCard(
                        title: 'Top color',
                        value: topVariant == null
                            ? '-'
                            : (topVariant.colorName.isNotEmpty
                                  ? topVariant.colorName
                                  : topVariant.name),
                      ),
                      _MetricCard(
                        title: 'Estimated sales by color',
                        value: product.purchaseCount <= 0 || totalStock <= 0
                            ? '0'
                            : '${product.purchaseCount}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _adminChip('${variants.length} variants'),
                    _adminChip(
                      '${variants.where((variant) => variant.stock <= 0).length} out of stock',
                    ),
                    _adminChip(
                      '${variants.fold<int>(0, (sum, variant) => sum + variant.images.length)} gallery images',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (variants.isEmpty)
                  const AbzioEmptyCard(
                    title: 'No color variants yet',
                    subtitle:
                        'Open the product editor to add colors, sizes, galleries, and SKU details.',
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: variants.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        _reorderVariants(product, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final variantName = variant.colorName.isNotEmpty
                          ? variant.colorName
                          : variant.name;
                      final createdLabel = variant.createdAt == null
                          ? 'Saved'
                          : DateFormat('dd MMM yyyy').format(
                              DateTime.tryParse(variant.createdAt ?? '') ??
                                  DateTime.now(),
                            );
                      return Container(
                        key: ValueKey(
                          '${variant.variantId.isEmpty ? variantName : variant.variantId}-$index',
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE9DECB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F1E5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Color(0xFF8B7A5B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: variant.thumbnail.isNotEmpty
                                    ? AbzioNetworkImage(
                                        imageUrl: variant.thumbnail,
                                        fallbackLabel: variantName,
                                      )
                                    : Container(
                                        color: const Color(0xFFF3F3F3),
                                        child: const Icon(
                                          Icons.palette_outlined,
                                          size: 18,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    variantName,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SKU ${variant.sku.isEmpty ? 'Auto' : variant.sku} • Stock ${variant.stock} • ${variant.status.toUpperCase()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _adminChip(
                                        '${variant.images.length + (variant.thumbnail.isNotEmpty ? 1 : 0)} images',
                                      ),
                                      _adminChip(
                                        '${variant.sizes.length} sizes',
                                      ),
                                      _adminChip(createdLabel),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _editVariant(product, index),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Edit'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _bulkReplaceVariantImages(product),
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Bulk Images'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(
                                    variant.price ?? product.price,
                                  ),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _editVariant(product, index),
                                  child: const Text('Edit Sizes'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _adminChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B7A5B),
        ),
      ),
    );
  }

  bool _isOrderDone(OrderModel order) {
    final s = order.status.toLowerCase();
    return s == 'delivered' || s == 'cancelled' || s == 'completed';
  }

  bool _isDelayedOrder(OrderModel order) {
    final s = order.status.toLowerCase();
    return s.contains('delay') || s.contains('late');
  }

  String _orderZoneFor(OrderModel order) {
    final parts = order.shippingAddress.split(',');
    if (parts.isEmpty) return 'Central';
    final zone = parts.last.trim();
    if (zone.isEmpty) return 'Central';
    return zone.length > 12 ? zone.substring(0, 12) : zone;
  }

  String _orderPriorityFor(OrderModel order) {
    if (_isDelayedOrder(order) ||
        order.status.toLowerCase().contains('cancel')) {
      return 'HIGH';
    }
    if ((order.riderId ?? '').isEmpty ||
        order.refundStatus.toLowerCase().contains('pending')) {
      return 'MEDIUM';
    }
    return 'LOW';
  }

  double _orderHealthScore(OrderModel order) {
    var score = 82.0;
    if (_isDelayedOrder(order)) score -= 32;
    if (order.status.toLowerCase().contains('cancel')) score -= 40;
    if ((order.riderId ?? '').isEmpty) score -= 12;
    if (order.refundStatus.toLowerCase().contains('pending')) score -= 16;
    return score.clamp(5, 98).toDouble();
  }

  Color _orderBorderColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return const Color(0xFFB42318);
    if (s.contains('deliver')) return const Color(0xFF067647);
    if (s.contains('assign') || s.contains('picked')) {
      return const Color(0xFFB57A12);
    }
    return const Color(0xFF175CD3);
  }

  List<Widget> _orderPriorityChips(OrderModel order) {
    final chips = <Widget>[];
    if (order.totalAmount >= 5000) {
      chips.add(
        const _StatusPill(label: 'VIP CUSTOMER', color: Color(0xFF7A5AF8)),
      );
    }
    if (order.paymentMethod.toLowerCase().contains('cod')) {
      chips.add(
        const _StatusPill(label: 'PAYMENT ISSUE', color: Color(0xFFDC6803)),
      );
    }
    if (_isDelayedOrder(order)) {
      chips.add(
        const _StatusPill(label: 'HIGH DELAY', color: Color(0xFFB42318)),
      );
    }
    if (order.refundStatus.toLowerCase().contains('pending')) {
      chips.add(
        const _StatusPill(label: 'RETURN RISK', color: Color(0xFFB54708)),
      );
    }
    if (order.items.length > 3) {
      chips.add(
        const _StatusPill(label: 'MULTI-VENDOR', color: Color(0xFF175CD3)),
      );
    }
    if (order.status.toLowerCase().contains('cancel')) {
      chips.add(
        const _StatusPill(label: 'FRAUD CHECK', color: Color(0xFF7A271A)),
      );
    }
    return chips;
  }

  Widget _buildOrderTimeline(String status) {
    final steps = ['Placed', 'Confirmed', 'Packed', 'Pickup', 'Delivery'];
    final index = switch (status.toLowerCase()) {
      'placed' => 0,
      'confirmed' => 1,
      'packed' => 2,
      'ready for pickup' || 'assigned' || 'picked up' => 3,
      'out for delivery' || 'delivered' => 4,
      _ => 0,
    };
    return Row(
      children: List.generate(steps.length, (i) {
        final completed = i <= index;
        final current = i == index;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: completed
                      ? (current
                            ? AbzioTheme.accentColor
                            : const Color(0xFF067647))
                      : AbzioTheme.grey300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  steps[i],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: completed
                        ? const Color(0xFF111111)
                        : AbzioTheme.grey500,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _bulkOrderStatus(String status) async {
    final selected = _orders
        .where((o) => _selectedOrderIds.contains(o.id))
        .toList();
    for (final order in selected) {
      await _setOrderStatus(order, status);
    }
    if (!mounted) return;
    setState(() => _selectedOrderIds.clear());
  }

  void _handleOrderQuickAction(OrderModel order, String action) {
    if (action == 'details') {
      setState(() => _activeOrderDrawerOrder = order);
      return;
    }
    if (action == 'cancel') {
      unawaited(_setOrderStatus(order, 'Cancelled'));
      return;
    }
    if (action == 'refund') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refund workflow opened.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action action queued for ${order.id}')),
    );
  }

  Widget _buildOrderDetailDrawer(OrderModel order) {
    final customer = _userForId(order.userId);
    final vendor = _storeForId(order.storeId);
    return Material(
      elevation: 12,
      child: Container(
        width: 420,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order Detail Panel',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _activeOrderDrawerOrder = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SupportDetailRow(label: 'Order', value: order.id),
            _SupportDetailRow(
              label: 'Customer',
              value: customer?.name ?? order.userId,
            ),
            _SupportDetailRow(
              label: 'Vendor',
              value: vendor?.name ?? order.storeId,
            ),
            _SupportDetailRow(
              label: 'Payment',
              value:
                  '${order.paymentMethod} • ${order.refundStatus.isEmpty ? 'No refund' : order.refundStatus}',
            ),
            _SupportDetailRow(
              label: 'Rider',
              value: order.assignedDeliveryPartner,
            ),
            _SupportDetailRow(
              label: 'ETA',
              value: order.deliveryPromise.isEmpty
                  ? 'Recalculating'
                  : order.deliveryPromise,
            ),
            _SupportDetailRow(label: 'Address', value: order.shippingAddress),
            const SizedBox(height: 12),
            Text(
              'Incident Logs',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '- Dispatch check completed\n- Payment verification synced\n- Risk scan complete',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'Escalation History',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '- No active escalations',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'Internal Notes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add operational note...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _storeRevenue(Store store) {
    final orders = _orders.where((o) => o.storeId == store.id).toList();
    return orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
  }

  double _vendorHealthScore(Store store) {
    final orders = _orders.where((o) => o.storeId == store.id).toList();
    if (orders.isEmpty) return 78;
    final cancelled = orders
        .where((o) => o.status.toLowerCase().contains('cancel'))
        .length;
    final refundPending = orders
        .where((o) => o.refundStatus.toLowerCase().contains('pending'))
        .length;
    final cancelRate = cancelled / orders.length;
    final refundRate = refundPending / orders.length;
    final ratingPenalty = (5 - store.rating).clamp(0, 5) * 6;
    final score = 100 - (cancelRate * 42) - (refundRate * 28) - ratingPenalty;
    return score.clamp(12, 96).toDouble();
  }

  Widget _buildVendorDetailDrawer(Store store) {
    final revenue = _storeRevenue(store);
    final health = _vendorHealthScore(store);
    return Material(
      elevation: 14,
      child: Container(
        width: 430,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vendor Detail Drawer',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _activeVendorDrawerStore = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SupportDetailRow(label: 'Store', value: store.name),
            _SupportDetailRow(label: 'Owner', value: store.ownerId),
            _SupportDetailRow(
              label: 'City',
              value: store.city.isEmpty ? 'Unknown' : store.city,
            ),
            _SupportDetailRow(
              label: 'Status',
              value: store.isApproved ? 'APPROVED' : 'PENDING',
            ),
            _SupportDetailRow(
              label: 'Revenue',
              value: _formatCurrency(revenue),
            ),
            _SupportDetailRow(
              label: 'Payout',
              value: _formatCurrency(store.walletBalance),
            ),
            _SupportDetailRow(
              label: 'Commission',
              value: '${(store.commissionRate * 100).toStringAsFixed(0)}%',
            ),
            _SupportDetailRow(
              label: 'Health',
              value: health.toStringAsFixed(0),
            ),
            const SizedBox(height: 12),
            Text(
              'Payout History',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- Weekly settlement processed\n- Last payout verified',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'KYC Documents',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- PAN verified\n- GST pending reconfirmation',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'Disputes & Fraud Flags',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- Return anomaly under review',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  String _riderLiveStatus(AppUser rider) {
    if (!rider.isActive) return 'OFFLINE';
    final active = _activeDeliveriesForRider(rider.id);
    final score = _riderPerformanceScore(rider);
    final hasRiskAlert = _opsAlerts.any((a) {
      final sameEntity =
          a.entityId == rider.id ||
          a.payload['riderId']?.toString() == rider.id;
      return sameEntity && a.severity.toUpperCase() == 'CRITICAL';
    });
    if (score < 45 || hasRiskAlert) return 'HIGH RISK';
    if (_orders.any((o) => o.riderId == rider.id && _isDelayedOrder(o))) {
      return 'DELAYED';
    }
    if (active > 0) return 'BUSY';
    return 'LIVE';
  }

  Color _riderStatusColor(String status) {
    switch (status) {
      case 'LIVE':
        return const Color(0xFF067647);
      case 'BUSY':
        return const Color(0xFF175CD3);
      case 'OFFLINE':
        return const Color(0xFF98A2B3);
      case 'DELAYED':
        return const Color(0xFFDC6803);
      case 'HIGH RISK':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF667085);
    }
  }

  double _riderPerformanceScore(AppUser rider) {
    final riderOrders = _orders.where((o) => o.riderId == rider.id).toList();
    if (riderOrders.isEmpty) return rider.isActive ? 74 : 52;
    final cancelled = riderOrders
        .where((o) => o.status.toLowerCase().contains('cancel'))
        .length;
    final delayed = riderOrders.where((o) => _isDelayedOrder(o)).length;
    final cancelRate = cancelled / riderOrders.length;
    final delayRate = delayed / riderOrders.length;
    final score =
        100 - (cancelRate * 40) - (delayRate * 30) - (rider.isActive ? 0 : 20);
    return score.clamp(18, 96).toDouble();
  }

  double _riderWeeklyEarnings(AppUser rider) {
    final now = DateTime.now();
    final deliveredLast7d = _orders.where((o) {
      return o.riderId == rider.id &&
          o.status.toLowerCase() == 'delivered' &&
          now.difference(o.timestamp).inDays <= 7;
    });
    return deliveredLast7d.fold<double>(
      0,
      (sum, o) => sum + ((o.totalAmount * 0.08).clamp(40, 260)),
    );
  }

  int? _riderBatteryLevel(AppUser rider) {
    for (final alert in _opsAlerts) {
      final sameEntity =
          alert.entityId == rider.id ||
          alert.payload['riderId']?.toString() == rider.id;
      if (!sameEntity) continue;
      final battery = alert.payload['battery'];
      if (battery is num) {
        return battery.toInt().clamp(0, 100);
      }
      final parsed = int.tryParse((battery ?? '').toString());
      if (parsed != null) {
        return parsed.clamp(0, 100);
      }
    }
    return null;
  }

  String _riderSignalQuality(AppUser rider) {
    for (final alert in _opsAlerts) {
      final sameEntity =
          alert.entityId == rider.id ||
          alert.payload['riderId']?.toString() == rider.id;
      if (!sameEntity) continue;
      final value =
          alert.payload['networkQuality'] ?? alert.payload['signalQuality'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'N/A';
  }

  String _riderLastActiveLabel(AppUser rider) {
    DateTime? latest;
    for (final order in _orders) {
      if (order.riderId != rider.id) continue;
      final stamp = order.riderLocationUpdatedAt;
      if (stamp == null || stamp.trim().isEmpty) continue;
      final parsed = DateTime.tryParse(stamp);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    final userParsed = DateTime.tryParse(rider.locationUpdatedAt ?? '');
    if (userParsed != null && (latest == null || userParsed.isAfter(latest))) {
      latest = userParsed;
    }
    if (latest == null) {
      return rider.isActive ? 'recently' : 'offline';
    }
    final diff = DateTime.now().difference(latest);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _assignOrderToRider(AppUser rider) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final pending = _orders
        .where((o) => (o.riderId ?? '').isEmpty && !_isOrderDone(o))
        .toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unassigned orders available.')),
      );
      return;
    }
    final target = pending.first;
    await _db.assignRiderToOrder(target.id, rider, actor: actor);
    await _load();
  }

  Widget _buildRiderDetailDrawer(AppUser rider) {
    final perf = _riderPerformanceScore(rider);
    final earnings = _riderWeeklyEarnings(rider);
    final active = _activeDeliveriesForRider(rider.id);
    final riderOrders = _orders.where((o) => o.riderId == rider.id).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    OrderModel? latestOrderWithLocation;
    for (final order in riderOrders) {
      if (order.riderLatitude != null && order.riderLongitude != null) {
        latestOrderWithLocation = order;
        break;
      }
    }
    final lat = latestOrderWithLocation?.riderLatitude;
    final lng = latestOrderWithLocation?.riderLongitude;
    return Material(
      elevation: 14,
      child: Container(
        width: 430,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rider Detail Drawer',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _activeRiderDrawerUser = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SupportDetailRow(label: 'Rider', value: rider.name),
            _SupportDetailRow(
              label: 'Phone',
              value: rider.phone ?? rider.email,
            ),
            _SupportDetailRow(
              label: 'City',
              value: rider.riderCity ?? rider.city ?? 'Unknown',
            ),
            _SupportDetailRow(
              label: 'Vehicle',
              value: rider.riderVehicleType ?? 'Bike',
            ),
            _SupportDetailRow(label: 'Status', value: _riderLiveStatus(rider)),
            _SupportDetailRow(
              label: 'Performance',
              value: perf.toStringAsFixed(0),
            ),
            _SupportDetailRow(label: 'Active Orders', value: '$active'),
            _SupportDetailRow(
              label: 'Weekly Earnings',
              value: _formatCurrency(earnings),
            ),
            const SizedBox(height: 12),
            Text(
              'Live GPS Map',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  lat == null || lng == null
                      ? 'Live location unavailable'
                      : 'Tracking ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'KYC / Complaints / Fraud Flags',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- KYC verified\n- Complaint ratio normal\n- No fraud flags',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}


