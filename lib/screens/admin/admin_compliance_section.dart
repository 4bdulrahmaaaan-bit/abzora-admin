import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

import '../../services/backend_api_client.dart';

class AdminComplianceSection extends StatefulWidget {
  const AdminComplianceSection({super.key});

  @override
  State<AdminComplianceSection> createState() => _AdminComplianceSectionState();
}

class _AdminComplianceSectionState extends State<AdminComplianceSection> {
  bool _isExporting = false;
  final BackendApiClient _api = const BackendApiClient();

  final List<Map<String, String>> _exportModules = [
    {
      'title': 'Financial Settlements',
      'description': 'Export all vendor and rider settlements',
      'id': 'settlements',
    },
    {
      'title': 'Inventory Report',
      'description': 'Export current stock levels and low stock alerts',
      'id': 'inventory',
    },
    {
      'title': 'KYC Compliance Logs',
      'description': 'Export vendor and rider KYC status reports',
      'id': 'kyc',
    },
    {
      'title': 'Rider Intelligence Data',
      'description': 'Export rider performance and location logs',
      'id': 'riders',
    },
    {
      'title': 'Business Analytics',
      'description': 'Export global platform metrics and growth stats',
      'id': 'analytics',
    },
  ];

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    return value is List
        ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<List<String>> _buildRowsForModule(String moduleId, Map<String, dynamic> response) {
    switch (moduleId) {
      case 'settlements':
        final settlements = _asMapList(response['data']);
        return [
          ['Type', 'ID', 'Status', 'Amount', 'Updated At'],
          ...settlements.map(
            (item) => [
              _text(item['settlementType'], 'Settlement'),
              _text(item['_id'] ?? item['id'] ?? item['settlementId']),
              _text(item['status'], 'Pending'),
              _text(item['amount'] ?? item['netAmount'] ?? item['payoutAmount']),
              _text(item['updatedAt'] ?? item['createdAt']),
            ],
          ),
        ];
      case 'inventory':
        final products = _asMapList(response['data']);
        return [
          ['Product', 'Vendor', 'Status', 'Available', 'Reserved', 'Trial Reserved', 'Updated At'],
          ...products.map(
            (item) => [
              _text(item['name']),
              _text(item['vendorId']),
              _text(item['status'], 'Unknown'),
              _text(item['inventory'] is Map ? (item['inventory'] as Map)['available'] : item['available']),
              _text(item['inventory'] is Map ? (item['inventory'] as Map)['reserved'] : item['reserved']),
              _text(item['inventory'] is Map ? (item['inventory'] as Map)['trialReserved'] : item['trialReserved']),
              _text(item['updatedAt']),
            ],
          ),
        ];
      case 'kyc':
        final vendors = _asMapList(response['vendors']);
        final riders = _asMapList(response['riders']);
        return [
          ['Type', 'ID', 'Name / Store', 'Status', 'Submitted At', 'Reason'],
          ...vendors.map(
            (item) => [
              'Vendor',
              _text(item['requestId'] ?? item['_id'] ?? item['id']),
              _text(item['storeName'] ?? item['ownerName']),
              _text(item['status'], 'submitted'),
              _text(item['createdAt']),
              _text(item['rejectionReason']),
            ],
          ),
          ...riders.map(
            (item) => [
              'Rider',
              _text(item['requestId'] ?? item['_id'] ?? item['id']),
              _text(item['name']),
              _text(item['status'], 'submitted'),
              _text(item['createdAt']),
              _text(item['rejectionReason']),
            ],
          ),
        ];
      case 'riders':
        final riders = _asMapList(response['data']);
        return [
          ['Rider', 'Classification', 'Status', 'City', 'Updated At'],
          ...riders.map(
            (item) => [
              _text(item['name'] ?? item['uid']),
              _text(item['classification'] ?? item['segment'] ?? item['riskClass']),
              _text(item['status'] ?? item['isActive']),
              _text(item['city']),
              _text(item['updatedAt'] ?? item['createdAt']),
            ],
          ),
        ];
      case 'analytics':
        final analytics = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
        final rows = <List<String>>[
          ['Metric', 'Value'],
        ];
        void flatten(String prefix, dynamic value) {
          if (value is Map) {
            for (final entry in value.entries) {
              final key = prefix.isEmpty ? entry.key.toString() : '$prefix.${entry.key}';
              flatten(key, entry.value);
            }
            return;
          }
          if (value is List) {
            for (var i = 0; i < value.length; i++) {
              flatten('$prefix[$i]', value[i]);
            }
            return;
          }
          rows.add([prefix, _text(value)]);
        }
        flatten('analytics', analytics);
        return rows;
      default:
        return [
          ['ID', 'Status', 'Date'],
        ];
    }
  }

  Future<Map<String, dynamic>> _fetchModulePayload(String moduleId) async {
    switch (moduleId) {
      case 'settlements':
        return Map<String, dynamic>.from(
          await _api.get('/admin/finance/settlements?page=1&limit=200', authenticated: true) as Map,
        );
      case 'inventory':
        return Map<String, dynamic>.from(
          await _api.get('/admin/inventory/products?page=1&limit=200', authenticated: true) as Map,
        );
      case 'kyc':
        final vendor = await _api.get('/admin/kyc/vendors', authenticated: true);
        final rider = await _api.get('/admin/kyc/riders', authenticated: true);
        return {
          'vendors': (vendor is Map ? vendor['data'] : const []) ?? const [],
          'riders': (rider is Map ? rider['data'] : const []) ?? const [],
        };
      case 'riders':
        return Map<String, dynamic>.from(
          await _api.get('/admin/rider-intelligence/list?page=1&limit=200', authenticated: true) as Map,
        );
      case 'analytics':
        return Map<String, dynamic>.from(
          await _api.get('/admin/business-analytics/v2', authenticated: true) as Map,
        );
      default:
        return {};
    }
  }

  Future<void> _exportAsCsv(String moduleId) async {
    final response = await _fetchModulePayload(moduleId);
    final data = _buildRowsForModule(moduleId, response);

    final csv = data
        .map(
          (row) => row
              .map((cell) {
                final s = cell.toString();
                if (s.contains(',') || s.contains('"') || s.contains('\n')) {
                  return '"${s.replaceAll('"', '""')}"';
                }
                return s;
              })
              .join(','),
        )
        .join('\n');
    await _saveAndShareFile('$moduleId.csv', csv.codeUnits, 'text/csv');
  }

  Future<void> _exportAsExcel(String moduleId) async {
    final response = await _fetchModulePayload(moduleId);
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Headers
    final rows = _buildRowsForModule(moduleId, response);
    for (final row in rows) {
      sheet.appendRow(row.map((e) => TextCellValue(e)).toList());
    }

    final bytes = excel.encode()!;
    await _saveAndShareFile(
      '$moduleId.xlsx',
      bytes,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _exportAsPdf(String moduleId) async {
    final response = await _fetchModulePayload(moduleId);
    final pdf = pw.Document();
    final data = _buildRowsForModule(moduleId, response);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Report: $moduleId',
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
    await _saveAndShareFile('$moduleId.pdf', bytes, 'application/pdf');
  }

  Future<void> _saveAndShareFile(
    String fileName,
    List<int> bytes,
    String mimeType,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path, mimeType: mimeType),
        ], text: 'Exported $fileName');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    }
  }

  void _showExportOptions(String moduleId, String title) {
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
                Text(
                  'Export $title',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export as CSV'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleExport(() => _exportAsCsv(moduleId));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on, color: Colors.blue),
                  title: const Text('Export as Excel (.xlsx)'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleExport(() => _exportAsExcel(moduleId));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export as PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleExport(() => _exportAsPdf(moduleId));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Data Export & Compliance')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compliance Exports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Generate platform data reports in standard formats for regulatory, financial, and internal audit purposes.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exportModules.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final module = _exportModules[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.file_download,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      title: Text(
                        module['title']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(module['description']!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showExportOptions(module['id']!, module['title']!),
                    );
                  },
                ),
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
      ),
    );
  }
}
