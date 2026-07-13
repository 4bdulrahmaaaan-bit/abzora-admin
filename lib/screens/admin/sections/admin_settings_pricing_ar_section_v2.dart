// ignore_for_file: invalid_use_of_protected_member

part of '../admin_web_panel.dart';

extension _AdminSettingsPricingArSectionV2 on _AdminWebPanelState {
  Widget _buildArModeration() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading AR moderation',
        subtitle: 'Fetching catalog data for moderation review.',
      );
    }
    return AdminArModerationSection(
      products: _products,
      onApprove: _approveArAsset,
      onReject: _rejectArAsset,
      onRegenerate: _regenerateArAsset,
      onSaveAlignment: _saveArAlignment,
      onBulkApprove: _bulkApproveArAssets,
      onBulkRegenerate: _bulkRegenerateArAssets,
    );
  }

  Widget _buildSettings() {
    if (!_settingsLoaded) {
      return const AbzioLoadingView(
        title: 'Loading platform settings',
        subtitle: 'Fetching settings and pricing configuration.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Platform features',
          subtitle: 'Enable or pause key marketplace experiences.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeatureSwitchCard(
                label: 'Custom clothing',
                value: _settings.customTailoringEnabled,
                onChanged: (value) => _toggleFeature('custom', value),
              ),
              _FeatureSwitchCard(
                label: 'Offers',
                value: _settings.offersEnabled,
                onChanged: (value) => _toggleFeature('offers', value),
              ),
              _FeatureSwitchCard(
                label: 'Reels',
                value: _settings.reelsEnabled,
                onChanged: (value) => _toggleFeature('reels', value),
              ),
              _FeatureSwitchCard(
                label: 'Checkout',
                value: _settings.checkoutEnabled,
                onChanged: (value) => _toggleFeature('checkout', value),
              ),
              _FeatureSwitchCard(
                label: 'Marketplace',
                value: _settings.marketplaceEnabled,
                onChanged: (value) => _toggleFeature('marketplace', value),
              ),
              _FeatureSwitchCard(
                label: 'Rider dispatch',
                value: _settings.riderDispatchEnabled,
                onChanged: (value) => _toggleFeature('dispatch', value),
              ),
              _FeatureSwitchCard(
                label: 'AI assistant',
                value: _settings.aiAssistantEnabled,
                onChanged: (value) => _toggleFeature('ai', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'City availability',
          subtitle: 'Control where the marketplace is currently active.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _settings.cities.entries.map((entry) {
              return FilterChip(
                label: Text(entry.key),
                selected: entry.value,
                onSelected: (value) => _toggleCity(entry.key, value),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'AI cost controls',
          subtitle:
              'Control the hard daily AI budget and automatic 80% warning threshold.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _aiCostThresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Daily AI budget limit',
                    prefixText: '\$',
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saveAiCostThreshold,
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Save threshold'),
              ),
              Text(
                'Warning starts at ${_formatAiCost(_settings.aiDailyCostLimit * 0.8)} · hard cap ${_formatAiCost(_settings.aiDailyCostLimit)}',
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Open disputes',
          subtitle: 'Customer and vendor escalations requiring review.',
          child: _disputes.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No disputes',
                  subtitle:
                      'Escalations will appear here when they are raised.',
                )
              : Column(
                  children: _disputes.take(8).map((dispute) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.report_problem_outlined),
                      title: Text(
                        dispute.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${dispute.type} - ${dispute.status} - ${_formatCurrency(dispute.amount)}',
                      ),
                      trailing: Text(
                        _formatDate(dispute.createdAt),
                        style: GoogleFonts.inter(
                          color: AbzioTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  double _pricingValue(
    Map<String, dynamic> section,
    String key,
    double fallback,
  ) {
    final value = section[key];
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  bool _pricingToggle(Map<String, dynamic> section, String key, bool fallback) {
    final value = section[key];
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  Future<void> _editPricingNumber({
    required String title,
    required String endpoint,
    required String fieldKey,
    required double currentValue,
    required double min,
    required double max,
    bool percent = false,
  }) async {
    final controller = TextEditingController(
      text: percent
          ? (currentValue * 100).toStringAsFixed(0)
          : currentValue.toStringAsFixed(
              currentValue.truncateToDouble() == currentValue ? 0 : 2,
            ),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: percent ? 'Percent value' : 'Numeric value',
              prefixText: percent ? '' : '₹ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      final parsed = double.tryParse(controller.text.trim());
      if (parsed == null) {
        return;
      }
      final normalized = percent ? parsed / 100 : parsed;
      final clamped = normalized.clamp(min, max).toDouble();
      await _updatePricingScope(
        endpoint: endpoint,
        body: {fieldKey: clamped},
        successMessage: '$title updated.',
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _pricingMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onEdit,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
    );
  }

  Widget _buildPricingControlPanel() {
    final commission = _pricingConfig.commission;
    final delivery = _pricingConfig.deliveryFees;
    final trial = _pricingConfig.trialPricing;
    final discounts = _pricingConfig.discounts;
    final rider = _pricingConfig.riderPayouts;
    final rules = _pricingConfig.dynamicRules;
    final taxConfig = _pricingConfig.taxConfig;
    final simulationOutputs = Map<String, dynamic>.from(
      _lastPricingSimulation['outputs'] as Map? ?? const {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Pricing control center',
          subtitle:
              'Live controls for revenue, fees, commissions, and rider payouts.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusBadge(
                label: _pricingConfig.updatedBy.isEmpty
                    ? 'Awaiting first pricing update'
                    : 'Updated by ${_pricingConfig.updatedBy}',
                color: AbzioTheme.accentColor,
              ),
              _StatusBadge(
                label: _pricingConfig.updatedAt == null
                    ? 'No timestamp yet'
                    : 'Last change ${DateFormat('dd MMM, hh:mm a').format(_pricingConfig.updatedAt!.toLocal())}',
                color: Colors.white,
                foreground: AbzioTheme.textPrimary,
                borderColor: AbzioTheme.grey300,
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
                title: 'Commission control',
                subtitle: 'Ready-made, custom, and SLA incentives.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: 'Ready-made default',
                      value:
                          '${(_pricingValue(commission, 'defaultCommissionReadyMade', 0.18) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Applied to standard marketplace orders.',
                      onEdit: () => _editPricingNumber(
                        title: 'Ready-made commission',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'defaultCommissionReadyMade',
                        currentValue: _pricingValue(
                          commission,
                          'defaultCommissionReadyMade',
                          0.18,
                        ),
                        min: 0.15,
                        max: 0.20,
                        percent: true,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Custom default',
                      value:
                          '${(_pricingValue(commission, 'defaultCommissionCustom', 0.24) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Applied to tailoring and custom orders.',
                      onEdit: () => _editPricingNumber(
                        title: 'Custom commission',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'defaultCommissionCustom',
                        currentValue: _pricingValue(
                          commission,
                          'defaultCommissionCustom',
                          0.24,
                        ),
                        min: 0.20,
                        max: 0.30,
                        percent: true,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'High-performer adjustment',
                      value:
                          '${(_pricingValue(commission, 'highPerformerAdjustment', -0.03) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Reward strong vendors with a lower take rate.',
                      onEdit: () => _editPricingNumber(
                        title: 'High performer adjustment',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'highPerformerAdjustment',
                        currentValue: _pricingValue(
                          commission,
                          'highPerformerAdjustment',
                          -0.03,
                        ),
                        min: -0.05,
                        max: 0,
                        percent: true,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Low SLA adjustment',
                      value:
                          '${(_pricingValue(commission, 'lowSlaAdjustment', 0.05) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Penalty uplift for weak on-time performance.',
                      onEdit: () => _editPricingNumber(
                        title: 'Low SLA adjustment',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'lowSlaAdjustment',
                        currentValue: _pricingValue(
                          commission,
                          'lowSlaAdjustment',
                          0.05,
                        ),
                        min: 0,
                        max: 0.05,
                        percent: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Delivery pricing',
                subtitle: 'Same-day fees, surge, and peak-hour adjustments.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: '0-2 km fee',
                      value:
                          '₹${_pricingValue(delivery, 'slabUpTo2Km', 49).toStringAsFixed(0)}',
                      subtitle: 'Short radius same-day delivery.',
                      onEdit: () => _editPricingNumber(
                        title: '0-2 km delivery fee',
                        endpoint: '/admin/pricing/delivery',
                        fieldKey: 'slabUpTo2Km',
                        currentValue: _pricingValue(
                          delivery,
                          'slabUpTo2Km',
                          49,
                        ),
                        min: 39,
                        max: 500,
                      ),
                    ),
                    _pricingMetricTile(
                      title: '2-5 km fee',
                      value:
                          '₹${_pricingValue(delivery, 'slab2To5Km', 69).toStringAsFixed(0)}',
                      subtitle: 'Mid-range same-day delivery.',
                      onEdit: () => _editPricingNumber(
                        title: '2-5 km delivery fee',
                        endpoint: '/admin/pricing/delivery',
                        fieldKey: 'slab2To5Km',
                        currentValue: _pricingValue(delivery, 'slab2To5Km', 69),
                        min: 39,
                        max: 500,
                      ),
                    ),
                    _pricingMetricTile(
                      title: '5+ km fee',
                      value:
                          '₹${_pricingValue(delivery, 'slabAbove5Km', 79).toStringAsFixed(0)}',
                      subtitle: 'Long-radius same-day delivery.',
                      onEdit: () => _editPricingNumber(
                        title: '5+ km delivery fee',
                        endpoint: '/admin/pricing/delivery',
                        fieldKey: 'slabAbove5Km',
                        currentValue: _pricingValue(
                          delivery,
                          'slabAbove5Km',
                          79,
                        ),
                        min: 39,
                        max: 500,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(delivery, 'surgeEnabled', true),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing/delivery',
                        body: {'surgeEnabled': value},
                        successMessage: 'Surge pricing updated.',
                      ),
                      title: const Text('Enable surge pricing'),
                      subtitle: const Text(
                        'Apply demand-based fee surcharges live.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Discount control',
                subtitle: 'Customer offer levers.',
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _pricingToggle(
                        discounts,
                        'discountsEnabled',
                        true,
                      ),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing/discount',
                        body: {'discountsEnabled': value},
                        successMessage: 'Discount toggle updated.',
                      ),
                      title: const Text('Enable discounts'),
                    ),
                    _pricingMetricTile(
                      title: 'First-order discount',
                      value:
                          '₹${_pricingValue(discounts, 'firstOrderDiscount', 100).toStringAsFixed(0)}',
                      subtitle: 'Applied to first-time eligible customers.',
                      onEdit: () => _editPricingNumber(
                        title: 'First-order discount',
                        endpoint: '/admin/pricing/discount',
                        fieldKey: 'firstOrderDiscount',
                        currentValue: _pricingValue(
                          discounts,
                          'firstOrderDiscount',
                          100,
                        ),
                        min: 0,
                        max: 10000,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Max discount percent',
                      value:
                          '${(_pricingValue(discounts, 'maxDiscountPercent', 0.10) * 100).toStringAsFixed(0)}%',
                      subtitle: 'System-wide cap for discounting.',
                      onEdit: () => _editPricingNumber(
                        title: 'Max discount percent',
                        endpoint: '/admin/pricing/discount',
                        fieldKey: 'maxDiscountPercent',
                        currentValue: _pricingValue(
                          discounts,
                          'maxDiscountPercent',
                          0.10,
                        ),
                        min: 0.10,
                        max: 0.15,
                        percent: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Tax configuration',
                subtitle: 'Manage GST rates and inclusive tax settings.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: 'Default GST Rate',
                      value:
                          '${_pricingValue(taxConfig, 'defaultGstRate', 5).toStringAsFixed(1)}%',
                      subtitle: 'Base tax rate applied to all taxable items.',
                      onEdit: () => _editPricingNumber(
                        title: 'Default GST Rate',
                        endpoint: '/admin/pricing/tax',
                        fieldKey: 'defaultGstRate',
                        currentValue: _pricingValue(
                          taxConfig,
                          'defaultGstRate',
                          5,
                        ),
                        min: 0,
                        max: 100,
                        percent: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Pricing simulation',
          subtitle:
              'Preview commission, fees, payout, and profit before shipping changes.',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _pricingOrderValueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Order value',
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _pricingDistanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Distance',
                        suffixText: 'km',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _pricingUserType,
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New user')),
                        DropdownMenuItem(
                          value: 'repeat',
                          child: Text('Repeat user'),
                        ),
                        DropdownMenuItem(
                          value: 'low_conversion',
                          child: Text('Low conversion'),
                        ),
                        DropdownMenuItem(
                          value: 'high_return',
                          child: Text('High return'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _pricingUserType = value);
                      },
                      decoration: const InputDecoration(labelText: 'User type'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _pricingDemandLevel,
                      items: const [
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal demand'),
                        ),
                        DropdownMenuItem(
                          value: 'elevated',
                          child: Text('Elevated demand'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High demand'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _pricingDemandLevel = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Demand level',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _runPricingSimulation(
                      orderValue:
                          double.tryParse(
                            _pricingOrderValueController.text.trim(),
                          ) ??
                          1200,
                      distanceKm:
                          double.tryParse(
                            _pricingDistanceController.text.trim(),
                          ) ??
                          4,
                      userType: _pricingUserType,
                      demandLevel: _pricingDemandLevel,
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Run simulation'),
                  ),
                ],
              ),
              if (simulationOutputs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: 'Commission',
                      value:
                          '${(((simulationOutputs['commissionPercent'] ?? 0) as num).toDouble() * 100).toStringAsFixed(1)}%',
                    ),
                    _MetricCard(
                      title: 'Delivery fee',
                      value: _formatCurrency(
                        ((simulationOutputs['deliveryFee'] ?? 0) as num)
                            .toDouble(),
                      ),
                    ),
                    _MetricCard(
                      title: 'Rider payout',
                      value: _formatCurrency(
                        ((simulationOutputs['riderEarnings'] ?? 0) as num)
                            .toDouble(),
                      ),
                    ),
                    _MetricCard(
                      title: 'Profit',
                      value: _formatCurrency(
                        ((simulationOutputs['platformProfit'] ?? 0) as num)
                            .toDouble(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Pricing audit log',
          subtitle: 'Every pricing change with old and new values.',
          child: _pricingConfig.auditLogs.isEmpty
              ? const Text('No pricing changes logged yet.')
              : Column(
                  children: _pricingConfig.auditLogs.take(8).map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        '${entry.scope} · ${entry.action}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${entry.adminEmail.isEmpty ? entry.adminId : entry.adminEmail} · ${entry.changedFields.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        DateFormat(
                          'dd MMM, hh:mm a',
                        ).format(entry.timestamp.toLocal()),
                        style: GoogleFonts.inter(
                          color: AbzioTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
