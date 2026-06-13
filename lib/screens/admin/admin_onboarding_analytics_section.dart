import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../theme.dart';
import 'api/admin_onboarding_analytics_api.dart';

class AdminOnboardingAnalyticsSection extends StatefulWidget {
  const AdminOnboardingAnalyticsSection({super.key});

  @override
  State<AdminOnboardingAnalyticsSection> createState() =>
      _AdminOnboardingAnalyticsSectionState();
}

class _AdminOnboardingAnalyticsSectionState
    extends State<AdminOnboardingAnalyticsSection> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic> _data = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final res = await AdminOnboardingAnalyticsApi.fetchAnalytics();
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAndShareFile(
    String fileName,
    List<int> bytes,
    String mimeType,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    if (mounted) {
      await Share.shareXFiles([
        XFile(file.path, mimeType: mimeType),
      ], text: 'Exported $fileName');
    }
  }

  List<List<String>> _prepareExportData() {
    final vendorFunnel = (_data['vendorFunnel'] as List?) ?? [];
    final riderFunnel = (_data['riderFunnel'] as List?) ?? [];

    final rows = <List<String>>[
      ['Type', 'Stage', 'Count', 'Conversion %', 'Drop-off %'],
    ];

    for (final item in vendorFunnel) {
      rows.add([
        'Vendor',
        item['stage'].toString(),
        item['count'].toString(),
        item['conversion'].toString(),
        item['dropoff'].toString(),
      ]);
    }
    for (final item in riderFunnel) {
      rows.add([
        'Rider',
        item['stage'].toString(),
        item['count'].toString(),
        item['conversion'].toString(),
        item['dropoff'].toString(),
      ]);
    }

    return rows;
  }

  Future<void> _exportAsCsv() async {
    final data = _prepareExportData();
    final csv = data
        .map(
          (row) => row
              .map((cell) {
                final s = cell;
                if (s.contains(',') || s.contains('"') || s.contains('\n')) {
                  return '"${s.replaceAll('"', '""')}"';
                }
                return s;
              })
              .join(','),
        )
        .join('\n');
    await _saveAndShareFile(
      'onboarding_analytics.csv',
      csv.codeUnits,
      'text/csv',
    );
  }

  Future<void> _exportAsExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    final data = _prepareExportData();
    for (final row in data) {
      sheet.appendRow(row.map((e) => TextCellValue(e)).toList());
    }

    final bytes = excel.encode()!;
    await _saveAndShareFile(
      'onboarding_analytics.xlsx',
      bytes,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _exportAsPdf() async {
    final pdf = pw.Document();
    final data = _prepareExportData();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Onboarding Analytics Funnel',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(context: context, data: data),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await _saveAndShareFile(
      'onboarding_analytics.pdf',
      bytes,
      'application/pdf',
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export Onboarding Data',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export as CSV'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleExport(_exportAsCsv);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on, color: Colors.blue),
                  title: const Text('Export as Excel (.xlsx)'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleExport(_exportAsExcel);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export as PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleExport(_exportAsPdf);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleExport(Future<void> Function() exportFunc) async {
    setState(() => _isExporting = true);
    try {
      await exportFunc();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Text('Error: $_error'));

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Onboarding Analytics',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          color: AbzioTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitor vendor and rider funnel conversions, drop-offs, and approval times.',
                        style: GoogleFonts.inter(
                          color: AbzioTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showExportOptions,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildKpisSection(),
              const SizedBox(height: 32),
              _buildFunnelSection(
                'Vendor Onboarding Funnel',
                _data['vendorFunnel'] as List? ?? [],
              ),
              const SizedBox(height: 32),
              _buildFunnelSection(
                'Rider Onboarding Funnel',
                _data['riderFunnel'] as List? ?? [],
              ),
              const SizedBox(height: 32),
              _buildExecutiveInsights(),
              const SizedBox(height: 48),
            ],
          ),
        ),
        if (_isExporting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating Export...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKpisSection() {
    final vendorKpis = _data['vendorKpis'] ?? {};
    final riderKpis = _data['riderKpis'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildKpiCard(
                'Vendor Applications Today',
                '${vendorKpis['applicationsToday'] ?? 0}',
                Colors.orange.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Vendor Conv. Rate',
                '${vendorKpis['conversionRate'] ?? 0}%',
                Colors.orange.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Vendor Avg Approval',
                '${vendorKpis['avgApprovalTimeHours'] ?? 0} hrs',
                Colors.orange.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Vendor Avg Activation',
                '${vendorKpis['avgActivationTimeDays'] ?? 0} days',
                Colors.orange.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildKpiCard(
                'Rider Applications Today',
                '${riderKpis['applicationsToday'] ?? 0}',
                Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Rider Conv. Rate',
                '${riderKpis['conversionRate'] ?? 0}%',
                Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Rider Avg Approval',
                '${riderKpis['avgApprovalTimeHours'] ?? 0} hrs',
                Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Rider Avg Activation',
                '${riderKpis['avgActivationTimeDays'] ?? 0} days',
                Colors.blue.shade50,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelSection(String title, List<dynamic> funnelData) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AbzioTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (funnelData.isEmpty)
              const Text('No funnel data available.')
            else
              Column(
                children: funnelData.map((stageData) {
                  final conversion = stageData['conversion'] as double;
                  final dropoff = stageData['dropoff'] as double;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            stageData['stage'] ?? '',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${stageData['count']} users',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (dropoff > 0)
                                    Text(
                                      '$dropoff% drop-off',
                                      style: GoogleFonts.inter(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: conversion / 100,
                                backgroundColor: Colors.grey.shade200,
                                color: conversion > 80
                                    ? Colors.green
                                    : (conversion > 50
                                          ? Colors.orange
                                          : Colors.red),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '$conversion%',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveInsights() {
    final insights = _data['executiveInsights'] ?? {};
    final dropoffs = insights['biggestDropoffPoints'] as List? ?? [];
    final fast = insights['fastestStages'] as List? ?? [];
    final slow = insights['slowestStages'] as List? ?? [];
    final alerts = insights['alerts'] as List? ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AbzioTheme.grey200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInsightList(
                    'Biggest Drop-offs',
                    dropoffs,
                    Icons.trending_down,
                    Colors.red,
                  ),
                  const SizedBox(height: 16),
                  _buildInsightList(
                    'Fastest Stages',
                    fast,
                    Icons.speed,
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildInsightList(
                    'Slowest Stages',
                    slow,
                    Icons.hourglass_bottom,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AbzioTheme.grey200),
            ),
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'System Alerts',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (alerts.isEmpty)
                    const Text('No active alerts.')
                  else
                    ...alerts.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'â€¢ $a',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade900,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightList(
    String title,
    List<dynamic> items,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 24),
            child: Text(
              'â€¢ $item',
              style: GoogleFonts.inter(color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}
