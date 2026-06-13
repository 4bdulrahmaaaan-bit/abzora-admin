import 'package:flutter/material.dart';
import 'dart:async';

import '../../models/models.dart';
import '../../services/backend_commerce_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

typedef ProductActionCallback = Future<void> Function(Product product);
typedef ProductAlignmentSaveCallback = Future<void> Function(
  Product product,
  Map<String, dynamic> editorPatch,
);
typedef ProductBulkActionCallback = Future<void> Function(
  List<Product> products,
);

class AdminArModerationSection extends StatefulWidget {
  const AdminArModerationSection({
    super.key,
    required this.products,
    required this.onApprove,
    required this.onReject,
    required this.onRegenerate,
    required this.onSaveAlignment,
    required this.onBulkApprove,
    required this.onBulkRegenerate,
  });

  final List<Product> products;
  final ProductActionCallback onApprove;
  final ProductActionCallback onReject;
  final ProductActionCallback onRegenerate;
  final ProductAlignmentSaveCallback onSaveAlignment;
  final ProductBulkActionCallback onBulkApprove;
  final ProductBulkActionCallback onBulkRegenerate;

  @override
  State<AdminArModerationSection> createState() =>
      _AdminArModerationSectionState();
}

class _AdminArModerationSectionState extends State<AdminArModerationSection> {
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  String _statusFilter = 'pending';
  Product? _active;
  bool _busy = false;
  bool _telemetryLoading = false;
  Map<String, dynamic> _telemetrySummary = const <String, dynamic>{};
  Timer? _telemetryRefreshTimer;
  int _telemetryDays = 7;

  @override
  void initState() {
    super.initState();
    _active = widget.products.isEmpty ? null : widget.products.first;
    _loadTelemetrySummary();
    _startTelemetryAutoRefresh();
  }

  @override
  void didUpdateWidget(covariant AdminArModerationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active == null && widget.products.isNotEmpty) {
      _active = widget.products.first;
    } else if (_active != null) {
      _active = widget.products.cast<Product?>().firstWhere(
        (item) => item?.id == _active!.id,
        orElse: () => widget.products.isNotEmpty ? widget.products.first : null,
      );
    }
  }

  @override
  void dispose() {
    _telemetryRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return widget.products.where((product) {
      final status = _statusOf(product);
      final statusOk = _statusFilter == 'all' || status == _statusFilter;
      final queryOk =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return statusOk && queryOk;
    }).toList();
  }

  String _statusOf(Product product) {
    final raw =
        product.arAsset['status']?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty || raw == 'generated') return 'pending';
    if (raw == 'fallback') return 'failed';
    return raw;
  }

  List<String> _warningsFor(Product product) {
    final warnings = <String>[];
    final ar = product.arAsset;
    final anchors = (ar['anchors'] as Map?) ?? const {};
    final left = anchors['left_shoulder'];
    final right = anchors['right_shoulder'];
    if (left == null || right == null) {
      warnings.add('Missing anchors');
    }
    final confidence =
        ((ar['segmentation'] as Map?)?['confidence'] as num?)?.toDouble() ?? 0;
    if (confidence > 0 && confidence < 0.62) {
      warnings.add('Poor alignment');
    }
    final processed = ar['processedImage']?.toString() ?? '';
    if (processed.contains('w_') && processed.contains('w_320')) {
      warnings.add('Low resolution');
    }
    return warnings;
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'approved' => Colors.green,
      'rejected' => Colors.redAccent,
      'failed' => Colors.deepOrange,
      _ => AbzioTheme.accentColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _runBulk(ProductBulkActionCallback action) async {
    final targets = _filtered
        .where((item) => _selected.contains(item.id))
        .toList();
    if (targets.isEmpty) return;
    setState(() => _busy = true);
    try {
      await action(targets);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadTelemetrySummary() async {
    if (!_backendCommerce.isConfigured) {
      return;
    }
    setState(() => _telemetryLoading = true);
    try {
      final response = await _backendCommerce.getTryOnTelemetrySummary(
        days: _telemetryDays,
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _telemetrySummary = data;
      } else if (data is Map) {
        _telemetrySummary = Map<String, dynamic>.from(data);
      }
    } catch (_) {
      _telemetrySummary = const <String, dynamic>{};
    } finally {
      if (mounted) {
        setState(() => _telemetryLoading = false);
      }
    }
  }

  void _startTelemetryAutoRefresh() {
    _telemetryRefreshTimer?.cancel();
    if (!_backendCommerce.isConfigured) {
      return;
    }
    _telemetryRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) {
        return;
      }
      if (_telemetryLoading) {
        return;
      }
      _loadTelemetrySummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final usageRate = widget.products.isEmpty
        ? 0.0
        : widget.products
                  .where((p) => (p.arAsset['status'] ?? '') != '')
                  .length /
              widget.products.length;
    final successRate = widget.products.isEmpty
        ? 0.0
        : widget.products.where((p) => _statusOf(p) == 'approved').length /
              widget.products.length;
    final telemetryAverages = _telemetrySummary['averages'] as Map? ?? const {};
    final telemetryRates = _telemetrySummary['rates'] as Map? ?? const {};
    final telemetryBands = _telemetrySummary['bands'] as Map? ?? const {};
    final telemetryDeviceTiers =
        _telemetrySummary['deviceTiers'] as Map? ?? const {};
    final telemetryDailyRaw = _telemetrySummary['daily'] as List? ?? const [];
    final telemetryDaily = telemetryDailyRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final avgSessionQuality =
        (telemetryAverages['sessionQuality'] as num?)?.toDouble() ?? 0.0;
    final thermalRiskRate =
        (telemetryRates['thermalRiskRate'] as num?)?.toDouble() ?? 0.0;
    final trackingRiskRate =
        (telemetryRates['trackingRiskRate'] as num?)?.toDouble() ?? 0.0;
    final segmentationRiskRate =
        (telemetryRates['segmentationRiskRate'] as num?)?.toDouble() ?? 0.0;
    final qualityBand = telemetryBands['qualityBand'] as Map? ?? const {};
    final mostUsed = [...widget.products]
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'AR Moderation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search by product/category',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'failed', child: Text('Failed')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) =>
                  setState(() => _statusFilter = value ?? 'all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              'AR usage rate',
              '${(usageRate * 100).toStringAsFixed(1)}%',
            ),
            _metricCard(
              'Try-on success rate',
              '${(successRate * 100).toStringAsFixed(1)}%',
            ),
            _metricCard(
              'Session quality (${_telemetryDays}d)',
              _telemetryLoading
                  ? 'Loading...'
                  : '${(avgSessionQuality * 100).toStringAsFixed(1)}%',
            ),
            _metricCard(
              'Thermal risk rate (${_telemetryDays}d)',
              _telemetryLoading
                  ? 'Loading...'
                  : '${(thermalRiskRate * 100).toStringAsFixed(1)}%',
            ),
            _metricCard(
              'Tracking risk rate (${_telemetryDays}d)',
              _telemetryLoading
                  ? 'Loading...'
                  : '${(trackingRiskRate * 100).toStringAsFixed(1)}%',
            ),
            _metricCard(
              'Segmentation risk rate (${_telemetryDays}d)',
              _telemetryLoading
                  ? 'Loading...'
                  : '${(segmentationRiskRate * 100).toStringAsFixed(1)}%',
            ),
            _metricCard(
              'Most used',
              mostUsed.isEmpty ? '-' : mostUsed.first.name,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Telemetry window',
              style: TextStyle(
                color: AbzioTheme.grey600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 7, label: Text('7d')),
                ButtonSegment<int>(value: 14, label: Text('14d')),
                ButtonSegment<int>(value: 30, label: Text('30d')),
              ],
              selected: <int>{_telemetryDays},
              onSelectionChanged: (selection) {
                final next = selection.isEmpty ? 7 : selection.first;
                if (next == _telemetryDays) {
                  return;
                }
                setState(() => _telemetryDays = next);
                _loadTelemetrySummary();
              },
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _telemetryLoading ? null : _loadTelemetrySummary,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh now'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!_telemetryLoading && qualityBand.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _bandChip('Excellent', qualityBand['excellent']),
              _bandChip('Good', qualityBand['good']),
              _bandChip('Fair', qualityBand['fair']),
              _bandChip('Weak', qualityBand['weak']),
            ],
          ),
        if (!_telemetryLoading && telemetryDeviceTiers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: telemetryDeviceTiers.entries.map((entry) {
              final tier = entry.key.toString();
              final value = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{};
              final sessions = (value['sessions'] as num?)?.toInt() ?? 0;
              final quality =
                  ((value['avgSessionQuality'] as num?)?.toDouble() ?? 0) * 100;
              final thermalRisk =
                  ((value['thermalRiskRate'] as num?)?.toDouble() ?? 0) * 100;
              return _metricCard(
                '${tier.toUpperCase()} ($sessions)',
                'Q ${quality.toStringAsFixed(1)}% | T ${thermalRisk.toStringAsFixed(1)}%',
              );
            }).toList(),
          ),
        ],
        if (!_telemetryLoading && telemetryDaily.isNotEmpty) ...[
          const SizedBox(height: 10),
          _trendStrip(telemetryDaily),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _runBulk(widget.onBulkApprove),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Approve selected'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _runBulk(widget.onBulkRegenerate),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Regenerate selected'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 380,
                child: Card(
                  child: filtered.isEmpty
                      ? const AbzioEmptyCard(
                          title: 'No AR assets found',
                          subtitle: 'Try changing filters or search query.',
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final status = _statusOf(product);
                            final isActive = _active?.id == product.id;
                            final warnings = _warningsFor(product);
                            return ListTile(
                              selected: isActive,
                              onTap: () => setState(() => _active = product),
                              leading: Checkbox(
                                value: _selected.contains(product.id),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(product.id);
                                  } else {
                                    _selected.remove(product.id);
                                  }
                                }),
                              ),
                              title: Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                product.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _statusChip(status),
                                  if (warnings.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      warnings.first,
                                      style: const TextStyle(
                                        color: Colors.deepOrange,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _active == null
                    ? const AbzioEmptyCard(
                        title: 'Select a product',
                        subtitle: 'Pick any row from AR moderation list.',
                      )
                    : _ArModerationDetail(
                        product: _active!,
                        onApprove: widget.onApprove,
                        onReject: widget.onReject,
                        onRegenerate: widget.onRegenerate,
                        onSaveAlignment: widget.onSaveAlignment,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AbzioTheme.grey600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _bandChip(String label, dynamic rawCount) {
    final count = (rawCount as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AbzioTheme.grey600,
        ),
      ),
    );
  }

  Widget _trendStrip(List<Map<String, dynamic>> daily) {
    final points = daily.length <= 7 ? daily : daily.sublist(daily.length - 7);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-Day Session Quality Trend',
            style: TextStyle(
              color: AbzioTheme.grey600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final value =
                  (point['avgSessionQuality'] as num?)?.toDouble() ?? 0.0;
              final height = (18 + (value.clamp(0.0, 1.0) * 58)).toDouble();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8B978),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        point['day']?.toString().substring(5) ?? '--',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AbzioTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ArModerationDetail extends StatefulWidget {
  const _ArModerationDetail({
    required this.product,
    required this.onApprove,
    required this.onReject,
    required this.onRegenerate,
    required this.onSaveAlignment,
  });

  final Product product;
  final ProductActionCallback onApprove;
  final ProductActionCallback onReject;
  final ProductActionCallback onRegenerate;
  final ProductAlignmentSaveCallback onSaveAlignment;

  @override
  State<_ArModerationDetail> createState() => _ArModerationDetailState();
}

class _ArModerationDetailState extends State<_ArModerationDetail> {
  double offsetX = 0;
  double offsetY = 0;
  double scale = 1;
  double rotation = 0;
  double leftX = 0.33;
  double rightX = 0.67;

  @override
  void initState() {
    super.initState();
    final editor = (widget.product.arAsset['editor'] as Map?) ?? const {};
    offsetX = (editor['offsetX'] as num?)?.toDouble() ?? 0;
    offsetY = (editor['offsetY'] as num?)?.toDouble() ?? 0;
    scale = (editor['scale'] as num?)?.toDouble() ?? 1;
    rotation = (editor['rotation'] as num?)?.toDouble() ?? 0;
    final anchors = (widget.product.arAsset['anchors'] as Map?) ?? const {};
    leftX =
        ((anchors['left_shoulder'] as Map?)?['x'] as num?)?.toDouble() ?? 0.33;
    rightX =
        ((anchors['right_shoulder'] as Map?)?['x'] as num?)?.toDouble() ?? 0.67;
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.product.images.isNotEmpty
        ? widget.product.images.first
        : '';
    final processed =
        widget.product.arAsset['processedImage']?.toString() ?? original;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _imagePanel('Original', original)),
                  const SizedBox(width: 12),
                  Expanded(child: _previewPanel(processed)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => widget.onApprove(widget.product),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onReject(widget.product),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onRegenerate(widget.product),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Regenerate AR'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onSaveAlignment(widget.product, {
                    'offsetX': offsetX,
                    'offsetY': offsetY,
                    'scale': scale,
                    'rotation': rotation,
                    'leftShoulderX': leftX,
                    'rightShoulderX': rightX,
                  }),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Save alignment'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _slider(
              'Offset X',
              offsetX,
              -0.25,
              0.25,
              (v) => setState(() => offsetX = v),
            ),
            _slider(
              'Offset Y',
              offsetY,
              -0.25,
              0.25,
              (v) => setState(() => offsetY = v),
            ),
            _slider(
              'Scale',
              scale,
              0.75,
              1.4,
              (v) => setState(() => scale = v),
            ),
            _slider(
              'Rotation',
              rotation,
              -0.5,
              0.5,
              (v) => setState(() => rotation = v),
            ),
            _slider(
              'Left anchor X',
              leftX,
              0.15,
              0.5,
              (v) => setState(() => leftX = v),
            ),
            _slider(
              'Right anchor X',
              rightX,
              0.5,
              0.85,
              (v) => setState(() => rightX = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePanel(String title, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AbzioTheme.grey100),
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isEmpty
                ? const AbzioEmptyCard(
                    title: 'No image',
                    subtitle: 'Missing product image',
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const AbzioEmptyCard(
                          title: 'Image failed',
                          subtitle: 'Unable to load image',
                        ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _previewPanel(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AR alignment preview',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AbzioTheme.grey100),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF6F7FA), Color(0xFFEDEFF5)],
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 130,
                    color: Color(0x33000000),
                  ),
                ),
                if (url.isNotEmpty)
                  Center(
                    child: FractionalTranslation(
                      translation: Offset(offsetX, offsetY),
                      child: Transform.rotate(
                        angle: rotation,
                        child: Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            width: 170,
                            height: 230,
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(value.toStringAsFixed(2), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
