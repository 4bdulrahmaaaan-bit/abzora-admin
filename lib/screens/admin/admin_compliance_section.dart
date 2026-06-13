import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class AdminComplianceSection extends StatefulWidget {
  const AdminComplianceSection({super.key});

  @override
  State<AdminComplianceSection> createState() => _AdminComplianceSectionState();
}

class _AdminComplianceSectionState extends State<AdminComplianceSection> {
  bool _isExporting = false;

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

  Future<void> _exportAsCsv(String moduleId) async {
    // Mock Data Fetching (Replace with actual backend call)
    final data = [
      ['ID', 'Status', 'Date'],
      ['1001', 'Completed', '2026-06-12'],
      ['1002', 'Pending', '2026-06-12'],
    ];

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
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Headers
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Status'),
      TextCellValue('Date'),
    ]);
    // Data
    sheet.appendRow([
      TextCellValue('1001'),
      TextCellValue('Completed'),
      TextCellValue('2026-06-12'),
    ]);
    sheet.appendRow([
      TextCellValue('1002'),
      TextCellValue('Pending'),
      TextCellValue('2026-06-12'),
    ]);

    final bytes = excel.encode()!;
    await _saveAndShareFile(
      '$moduleId.xlsx',
      bytes,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _exportAsPdf(String moduleId) async {
    final pdf = pw.Document();

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
              pw.TableHelper.fromTextArray(
                context: context,
                data: const <List<String>>[
                  <String>['ID', 'Status', 'Date'],
                  <String>['1001', 'Completed', '2026-06-12'],
                  <String>['1002', 'Pending', '2026-06-12'],
                ],
              ),
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
