const fs = require('fs');
const path = require('path');

const filePaths = [
  'c:/Users/AAA/Documents/abzio/lib/screens/admin/admin_finance_section.dart',
  'c:/Users/AAA/Documents/abzio/lib/screens/admin/admin_inventory_section.dart',
  'c:/Users/AAA/Documents/abzio/lib/screens/admin/admin_kyc_section.dart',
  'c:/Users/AAA/Documents/abzio/lib/screens/admin/admin_rider_intelligence_section.dart',
];

const exportFunc = "Future<void> _exportCSV(String filename, List<String> headers, List<List<dynamic>> rows) async {\n" +
"    String csv = headers.join(',') + '\\n';\n" +
"    for (final row in rows) {\n" +
"      csv += row.map((e) => '\"${e.toString().replaceAll(\\'\"\\', \\'\"\"\\')}\"').join(',') + '\\n';\n" +
"    }\n" +
"\n" +
"    final bytes = utf8.encode(csv);\n" +
"    try {\n" +
"      final dir = await getApplicationDocumentsDirectory();\n" +
"      final file = File('${dir.path}/$filename.csv');\n" +
"      await file.writeAsBytes(bytes);\n" +
"      if (mounted) {\n" +
"        await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Exported $filename.csv');\n" +
"      }\n" +
"    } catch (e) {\n" +
"      if (mounted) {\n" +
"        ScaffoldMessenger.of(context).showSnackBar(\n" +
"          SnackBar(content: Text('Failed to save file: $e')),\n" +
"        );\n" +
"      }\n" +
"    }\n" +
"  }";

for (const fp of filePaths) {
  if (!fs.existsSync(fp)) continue;
  let content = fs.readFileSync(fp, 'utf8');
  
  // Replace imports
  content = content.replace(/import 'dart:html' as html;/g, 
    'import \'dart:io\';\nimport \'package:path_provider/path_provider.dart\';\nimport \'package:share_plus/share_plus.dart\';');
  
  // Replace _exportCSV function body
  content = content.replace(/void _exportCSV\(String filename, List<String> headers, List<List<dynamic>> rows\) \{([\s\S]*?)html\.Url\.revokeObjectUrl\(url\);\n\s*\}/g, exportFunc);
  
  fs.writeFileSync(fp, content, 'utf8');
}
console.log('Fixed dart:html imports and _exportCSV');
