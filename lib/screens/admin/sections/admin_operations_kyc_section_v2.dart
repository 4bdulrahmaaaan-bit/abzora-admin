// ignore_for_file: invalid_use_of_protected_member

part of '../admin_web_panel.dart';

extension _AdminOperationsKycSectionV2 on _AdminWebPanelState {
  Widget _buildOperationsStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFF12B76A), size: 10),
          const SizedBox(width: 8),
          Text(
            'LIVE',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _runOpsAction(
              action: () => _db.triggerOpsDetection(actor: _actor!),
              successMessage: 'Ops detection cycle triggered.',
            ),
            icon: const Icon(Icons.radar_rounded, size: 16),
            label: const Text('Run Detection'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openOpsSimulationDialog,
            icon: const Icon(Icons.science_outlined, size: 16),
            label: const Text('Simulation'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _selectTab(AdminWebSection.operations),
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: const Text('AI Assist'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOpsSimulationDialog() async {
    final ordersController = TextEditingController(text: '300');
    final ridersController = TextEditingController(text: '60');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Run Ops Simulation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ordersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Orders (N)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ridersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Riders (M)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final orders = int.tryParse(ordersController.text.trim()) ?? 300;
    final riders = int.tryParse(ridersController.text.trim()) ?? 60;
    await _runOpsAction(
      action: () async {
        final output = await _db.runOpsSimulation(
          actor: _actor!,
          orders: orders,
          riders: riders,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Simulation complete: delay ${output.delayPercent.toStringAsFixed(1)}%, dispatch ${output.dispatchSuccessPercent.toStringAsFixed(1)}%',
            ),
          ),
        );
      },
      successMessage: 'Simulation complete.',
    );
  }

  Widget _buildOperations() {
    if (!_opsLoaded) {
      return const AbzioLoadingView(
        title: 'Loading operations',
        subtitle: 'Fetching live alerts, metrics, and dispatch data.',
      );
    }
    final alerts = _opsAlerts;
    final logs = _opsLogs;
    final metrics = _opsMetrics.toList()
      ..sort((a, b) => a.bucketStartAt.compareTo(b.bucketStartAt));
    final live = _opsLive;
    final criticalCount = live.alertCounts['CRITICAL'] ?? 0;
    final highCount = live.alertCounts['HIGH'] ?? 0;
    final mediumCount = live.alertCounts['MEDIUM'] ?? 0;
    final lowCount = live.alertCounts['LOW'] ?? 0;
    final delayedDispatches = live.dispatch
        .where(
          (task) => (task['status']?.toString().toLowerCase() ?? '').contains(
            'delay',
          ),
        )
        .length;
    final failedPayments = alerts
        .where((a) => a.type.toLowerCase().contains('payment'))
        .length;
    final metricPoints = metrics
        .take(12)
        .map(
          (entry) => AnalyticsPoint(
            label: DateFormat('HH:mm').format(entry.bucketStartAt),
            value: entry.delayPercent,
          ),
        )
        .toList();
    final retrySpikes = logs
        .where((entry) => entry.status.toLowerCase().contains('retry'))
        .length;
    final vendorFailures = alerts
        .where((entry) => entry.entityType.toLowerCase().contains('vendor'))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(title: 'Critical Alerts', value: '$criticalCount'),
            _MetricCard(title: 'High Alerts', value: '$highCount'),
            _MetricCard(
              title: 'Live Orders',
              value: '${live.liveOrders.length}',
            ),
            _MetricCard(
              title: 'Delayed Dispatches',
              value: '$delayedDispatches',
            ),
            _MetricCard(title: 'Failed Payments', value: '$failedPayments'),
            _MetricCard(title: 'Active Riders', value: '${live.riders.length}'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _Panel(
                title: 'Priority Alert Queue',
                subtitle:
                    'Critical incidents with run actions, reassignment, and payment recovery.',
                child: alerts.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No alerts right now',
                        subtitle: 'Dispatch queue operating normally.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _selectedOpsAlertIds.isEmpty
                                    ? null
                                    : () async {
                                        for (final alertId
                                            in _selectedOpsAlertIds) {
                                          await _runOpsAction(
                                            action: () => _db.runOpsAlertAction(
                                              actor: _actor!,
                                              alertId: alertId,
                                            ),
                                            successMessage:
                                                'Bulk action executed.',
                                          );
                                        }
                                      },
                                child: const Text('Bulk Run Action'),
                              ),
                              OutlinedButton(
                                onPressed: _selectedOpsAlertIds.isEmpty
                                    ? null
                                    : () => setState(
                                        () => _selectedOpsAlertIds.clear(),
                                      ),
                                child: const Text('Clear Selection'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...alerts.take(12).map((alert) {
                            final isCritical =
                                alert.severity.toUpperCase() == 'CRITICAL';
                            final color = _opsSeverityColor(alert.severity);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  left: BorderSide(
                                    color: isCritical
                                        ? const Color(0xFFD92D20)
                                        : AbzioTheme.grey200,
                                    width: isCritical ? 4 : 1,
                                  ),
                                  top: BorderSide(color: AbzioTheme.grey200),
                                  right: BorderSide(color: AbzioTheme.grey200),
                                  bottom: BorderSide(color: AbzioTheme.grey200),
                                ),
                                boxShadow: isCritical
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFD92D20,
                                          ).withValues(alpha: 0.12),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _selectedOpsAlertIds.contains(
                                          alert.alertId,
                                        ),
                                        onChanged: (value) => setState(() {
                                          if (value == true) {
                                            _selectedOpsAlertIds.add(
                                              alert.alertId,
                                            );
                                          } else {
                                            _selectedOpsAlertIds.remove(
                                              alert.alertId,
                                            );
                                          }
                                        }),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${alert.type} | Order ${alert.orderId.isEmpty ? '-' : alert.orderId}',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _StatusPill(
                                        label:
                                            '${alert.severity} ${alert.score.toStringAsFixed(0)}',
                                        color: color,
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() {
                                          if (_expandedOpsAlertIds.contains(
                                            alert.alertId,
                                          )) {
                                            _expandedOpsAlertIds.remove(
                                              alert.alertId,
                                            );
                                          } else {
                                            _expandedOpsAlertIds.add(
                                              alert.alertId,
                                            );
                                          }
                                        }),
                                        icon: Icon(
                                          _expandedOpsAlertIds.contains(
                                                alert.alertId,
                                              )
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    alert.message,
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Time ${DateFormat('dd MMM HH:mm').format(alert.createdAt)} | Assigned ${alert.payload['assignedOperator'] ?? 'Ops Desk'} | Retry ${alert.retryCount}/${alert.maxRetries}',
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_expandedOpsAlertIds.contains(
                                    alert.alertId,
                                  )) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Entity ${alert.entityType}:${alert.entityId} | Action ${alert.action} | Status ${alert.actionStatus}',
                                      style: GoogleFonts.inter(
                                        color: AbzioTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () => _runOpsAction(
                                          action: () => _db.runOpsAlertAction(
                                            actor: _actor!,
                                            alertId: alert.alertId,
                                          ),
                                          successMessage:
                                              'Run action triggered.',
                                        ),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                        label: const Text('Run Action'),
                                      ),
                                      if (alert.orderId.trim().isNotEmpty) ...[
                                        OutlinedButton(
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsReassignOrder(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage: 'Order reassigned.',
                                          ),
                                          child: const Text('Reassign'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsRetryPayment(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage:
                                                'Retry payment queued.',
                                          ),
                                          child: const Text('Retry Payment'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsForceDispatch(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage:
                                                'Force dispatch triggered.',
                                          ),
                                          child: const Text('Force Dispatch'),
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
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsCancelOrder(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage: 'Order cancelled.',
                                          ),
                                          child: const Text('Cancel Order'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _Panel(
                    title: 'Live Dispatch Snapshot',
                    subtitle: 'Realtime incident health by severity band.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusPill(
                              label: 'Critical $criticalCount',
                              color: _opsSeverityColor('CRITICAL'),
                            ),
                            _StatusPill(
                              label: 'High $highCount',
                              color: _opsSeverityColor('HIGH'),
                            ),
                            _StatusPill(
                              label: 'Medium $mediumCount',
                              color: _opsSeverityColor('MEDIUM'),
                            ),
                            _StatusPill(
                              label: 'Low $lowCount',
                              color: _opsSeverityColor('LOW'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (live.dispatch.isEmpty)
                          const Text(
                            'Dispatch queue operating normally.',
                            style: TextStyle(color: AbzioTheme.grey600),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'Delay Trend Analytics',
                    subtitle:
                        'Hourly delay percent, retry spikes, and vendor response failures.',
                    child: metricPoints.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No delay trend yet',
                            subtitle: 'Platform running smoothly',
                          )
                        : Column(
                            children: [
                              _MiniBarChart(
                                points: metricPoints,
                                barColor: const Color(0xFFDC6803),
                                valueFormatter: (v) =>
                                    '${v.toStringAsFixed(0)}%',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StatusPill(
                                    label: 'Retry spikes $retrySpikes',
                                    color: const Color(0xFFB42318),
                                  ),
                                  _StatusPill(
                                    label: 'Vendor failures $vendorFailures',
                                    color: const Color(0xFFDC6803),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'Ops Audit Log',
                    subtitle:
                        'Started, retried, failed, resolved, and escalated actions.',
                    child: logs.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No operation logs',
                            subtitle: 'Platform running smoothly',
                          )
                        : SizedBox(
                            height: 280,
                            child: ListView(
                              controller: _opsAuditScrollController,
                              children: logs.take(18).map((entry) {
                                final s = entry.status.toLowerCase();
                                final icon = s.contains('fail')
                                    ? Icons.error_outline
                                    : s.contains('retry')
                                    ? Icons.refresh_rounded
                                    : s.contains('resolve')
                                    ? Icons.check_circle_outline
                                    : s.contains('escalat')
                                    ? Icons.priority_high_rounded
                                    : Icons.play_arrow_rounded;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(icon),
                                  title: Text(
                                    '${entry.action} | ${entry.status}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${entry.entityType}:${entry.entityId} | attempt ${entry.attempt}',
                                  ),
                                  trailing: Text(
                                    DateFormat(
                                      'dd MMM HH:mm',
                                    ).format(entry.createdAt),
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
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'AI Operational Insights',
                    subtitle:
                        'Intelligence recommendations for live operations.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInsightTile(
                          'Vendor response latency spike detected in Chennai.',
                          Icons.store_mall_directory_outlined,
                        ),
                        _buildInsightTile(
                          'Retry success probability low for payment queue.',
                          Icons.payments_outlined,
                        ),
                        _buildInsightTile(
                          'Rider shortage predicted in Zone B.',
                          Icons.delivery_dining_outlined,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => _runOpsAction(
                                action: () =>
                                    _db.triggerOpsDetection(actor: _actor!),
                                successMessage: 'Auto resolve initiated.',
                              ),
                              child: const Text('Auto Resolve'),
                            ),
                            OutlinedButton(
                              onPressed: () => setState(
                                () => _selectTab(AdminWebSection.support),
                              ),
                              child: const Text('Escalate'),
                            ),
                            OutlinedButton(
                              onPressed: () => setState(
                                () => _selectTab(AdminWebSection.operations),
                              ),
                              child: const Text('Open Incident'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ignore: unused_element

  // ignore: unused_element
  Widget _buildKycHub(BuildContext context) {
    if (!_kycLoaded) {
      return const AbzioLoadingView(
        title: 'Loading KYC queue',
        subtitle: 'Fetching vendor and rider review requests.',
      );
    }
    final allRequests = <_KycQueueItem>[
      ..._vendorRequests.map(
        (request) => _KycQueueItem(
          id: request.id,
          name: request.ownerName,
          role: 'Vendor',
          city: request.city,
          status: request.status,
          submittedAt: request.createdAt,
          phone: request.phone,
          autoReviewStatus: request.verification.autoReviewStatus,
          confidenceScore: request.verification.confidenceScore,
          flags: request.verification.flags,
          riskScore: request.verification.riskScore,
          riskDecision: request.verification.riskDecision,
          riskReasons: request.verification.riskReasons,
        ),
      ),
      ..._riderRequests.map((request) {
        final verification = Map<String, dynamic>.from(
          (request.metadata['verification'] as Map?) ??
              const <String, dynamic>{},
        );
        final status = (verification['status'] ?? '').toString();
        final confidence =
            (verification['confidenceScore'] as num?)?.toDouble() ?? 0;
        final matchScore = (verification['matchScore'] as num?)?.toInt() ?? 0;
        final flags = List<String>.from(
          (verification['flags'] as List?) ?? const [],
        );
        return _KycQueueItem(
          id: request.id,
          name: request.name,
          role: 'Rider',
          city: request.city,
          status: request.status,
          submittedAt: request.createdAt,
          phone: request.phone,
          autoReviewStatus: status == 'auto_verified'
              ? 'auto_verified'
              : 'pending_review',
          confidenceScore: confidence,
          flags: flags,
          riskScore: matchScore,
          riskDecision: status == 'auto_verified' ? 'approve' : 'review',
          riskReasons: flags,
        );
      }),
    ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final pending = allRequests
        .where((item) => item.status == 'pending')
        .toList();
    final approved = allRequests
        .where((item) => item.status == 'approved')
        .length;
    final rejected = allRequests
        .where((item) => item.status == 'rejected')
        .length;
    final flagged = allRequests
        .where((item) => item.autoReviewStatus == 'fraud_flagged')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(title: 'Pending KYC', value: '${pending.length}'),
            _MetricCard(title: 'Approved', value: '$approved'),
            _MetricCard(title: 'Rejected', value: '$rejected'),
            _MetricCard(title: 'Flagged by AI', value: '$flagged'),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'KYC queue',
          subtitle: 'Fast review access for vendor and rider verification.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/admin-kyc'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open full KYC review'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _selectTab(AdminWebSection.dashboard),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Back to dashboard'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              pending.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No pending requests',
                      subtitle:
                          'New partner applications will appear here automatically.',
                    )
                  : Column(
                      children: pending.take(8).map((item) {
                        final reviewColor = switch (item.autoReviewStatus) {
                          'auto_verified' => Colors.green,
                          'fraud_flagged' => Colors.red,
                          _ => const Color(0xFFB76E00),
                        };
                        final riskColor = item.riskScore >= 85
                            ? Colors.green
                            : item.riskScore >= 60
                            ? Colors.orange
                            : Colors.red;
                        final reviewLabel = switch (item.autoReviewStatus) {
                          'auto_verified' => 'AI VERIFIED',
                          'fraud_flagged' => 'FLAGGED',
                          _ => 'REVIEW',
                        };
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: Text(
                            item.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${item.role} - ${item.city.isEmpty ? 'Unknown city' : item.city} - ${item.phone}'
                            '${item.confidenceScore > 0 ? ' - ${item.confidenceScore.toStringAsFixed(0)}% OCR confidence' : ''}'
                            '${item.riskScore > 0 ? '\nRisk ${item.riskScore} (${item.riskDecision.toUpperCase()})' : ''}'
                            '${item.flags.isNotEmpty
                                ? '\n${item.flags.take(2).join(' • ')}'
                                : item.riskReasons.isNotEmpty
                                ? '\n${item.riskReasons.take(2).join(' • ')}'
                                : ''}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusPill(
                                label: item.status.toUpperCase(),
                                color: const Color(0xFFB76E00),
                              ),
                              const SizedBox(height: 6),
                              _StatusPill(
                                label: reviewLabel,
                                color: reviewColor,
                              ),
                              if (item.riskScore > 0) ...[
                                const SizedBox(height: 6),
                                _StatusPill(
                                  label: 'RISK ${item.riskScore}',
                                  color: riskColor,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

