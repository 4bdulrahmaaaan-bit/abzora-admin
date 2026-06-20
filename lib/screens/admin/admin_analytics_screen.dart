import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/backend_commerce_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final BackendCommerceService _backend = BackendCommerceService();
  int _days = 14;
  bool _loading = false;
  String _error = '';
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final payload = await _backend.getArEnterpriseSummary(days: _days);
      if (!mounted) return;
      setState(
        () => _summary = payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : Map<String, dynamic>.from(payload['data'] as Map? ?? const {}),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createFitRun() async {
    await _backend.createArFitRun(
      name: 'nightly-fit-run-${DateTime.now().millisecondsSinceEpoch}',
      datasetVersion: 'dataset-v2',
      trainingConfig: const {
        'trainer': 'xgboost',
        'folds': 5,
        'features': ['bodyMetrics', 'garmentMeta', 'sessionTelemetry'],
      },
    );
    await _refresh();
  }

  Future<void> _runGarmentCertification() async {
    await _backend.createArGarmentCertificationJob(mode: 'incremental');
    await _refresh();
  }

  Future<void> _runDeviceLab() async {
    await _backend.createArDeviceLabRun(
      name: 'nightly-soak-${DateTime.now().millisecondsSinceEpoch}',
      scenario: 'soak_45m',
      deviceMatrix: const [
        {
          'model': 'Pixel 7',
          'tier': 'FLAGSHIP',
          'targetFps': 55,
          'thermalLoad': 0.52,
          'sessionMinutes': 45,
        },
        {
          'model': 'Galaxy A34',
          'tier': 'MID',
          'targetFps': 36,
          'thermalLoad': 0.68,
          'sessionMinutes': 45,
        },
        {
          'model': 'iPhone 15 Pro',
          'tier': 'PREMIUM_LIDAR',
          'targetFps': 60,
          'thermalLoad': 0.47,
          'sessionMinutes': 45,
        },
      ],
    );
    await _refresh();
  }

  String _percent(num value) => '${(value * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Admin access only',
              subtitle:
                  'Analytics is restricted to platform administrators.',
            ),
          ),
        ),
      );
    }
    final arSessions = Map<String, dynamic>.from(
      _summary['arSessions'] as Map? ?? const {},
    );
    final fitOps = Map<String, dynamic>.from(
      _summary['fitOps'] as Map? ?? const {},
    );
    final garmentOps = Map<String, dynamic>.from(
      _summary['garmentOps'] as Map? ?? const {},
    );
    final deviceLab = Map<String, dynamic>.from(
      _summary['deviceLab'] as Map? ?? const {},
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise AR Analytics'),
        actions: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 14, label: Text('14d')),
              ButtonSegment(value: 30, label: Text('30d')),
            ],
            selected: {_days},
            onSelectionChanged: (value) {
              setState(() => _days = value.first);
              _refresh();
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionCard(
                title: 'AI Fit Training',
                cta: 'Start Run',
                onTap: _createFitRun,
              ),
              _ActionCard(
                title: 'Garment Certification',
                cta: 'Run Pipeline',
                onTap: _runGarmentCertification,
              ),
              _ActionCard(
                title: 'Device Lab Soak',
                cta: 'Launch Soak',
                onTap: _runDeviceLab,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error.isNotEmpty)
            Text(
              _error,
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'AR Sessions',
                value: '${arSessions['total'] ?? 0}',
              ),
              _MetricCard(
                title: 'Avg Session Quality',
                value: _percent((arSessions['avgSessionQuality'] ?? 0) as num),
              ),
              _MetricCard(
                title: 'Tracking Risk Rate',
                value: _percent((arSessions['trackingRiskRate'] ?? 0) as num),
              ),
              _MetricCard(
                title: 'Avg FPS',
                value: '${arSessions['avgFps'] ?? 0}',
              ),
              _MetricCard(
                title: 'Fit Model Runs',
                value: '${fitOps['totalRuns'] ?? 0}',
              ),
              _MetricCard(
                title: 'Rollout Runs',
                value: '${fitOps['rolloutRuns'] ?? 0}',
              ),
              _MetricCard(
                title: 'Certified Garments',
                value: '${garmentOps['certified'] ?? 0}',
              ),
              _MetricCard(
                title: 'Rejected Garments',
                value: '${garmentOps['rejected'] ?? 0}',
              ),
              _MetricCard(
                title: 'Tested Devices',
                value: '${deviceLab['testedDevices'] ?? 0}',
              ),
              _MetricCard(
                title: 'Device Failures',
                value: '${deviceLab['totalFailures'] ?? 0}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onTap, child: Text(cta)),
            ],
          ),
        ),
      ),
    );
  }
}
