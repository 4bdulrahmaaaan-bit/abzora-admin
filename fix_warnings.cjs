const fs = require('fs');
const path = require('path');

const applyReplacements = (filePath, replacements) => {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  let originalContent = content;
  
  for (const { search, replace } of replacements) {
    if (typeof search === 'string') {
      content = content.split(search).join(replace);
    } else {
      content = content.replace(search, replace);
    }
  }
  
  if (content !== originalContent) {
    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`Updated ${filePath}`);
  }
};

const baseDir = 'c:/Users/AAA/Documents/abzio/lib/screens/admin';

// 1. admin_automation_section.dart - context warning
applyReplacements(path.join(baseDir, 'admin_automation_section.dart'), [
  { search: 'Navigator.pop(context);\n                    _fetchAutomations();', replace: 'Navigator.pop(context);\n                  }\n                  _fetchAutomations();' },
  { search: 'if (mounted) {\n                    Navigator.pop(context);\n                  }\n                  _fetchAutomations();', replace: 'if (mounted) {\n                    Navigator.pop(context);\n                  }\n                  _fetchAutomations();' },
  // Let's use regex for automation context
  { search: /if \(mounted\) \{\n                    Navigator\.pop\(context\);\n                    _fetchAutomations\(\);\n                  \}/g, replace: 'if (mounted) {\n                    Navigator.pop(context);\n                  }\n                  _fetchAutomations();' },
]);

// 2. admin_backup_section.dart
applyReplacements(path.join(baseDir, 'admin_backup_section.dart'), [
  { search: /if \(mounted\) \{\n                    Navigator\.pop\(context\);\n                    _fetchBackups\(\);\n                  \}/g, replace: 'if (mounted) {\n                    Navigator.pop(context);\n                  }\n                  _fetchBackups();' }
]);

// 3. admin_compliance_section.dart - unused import
applyReplacements(path.join(baseDir, 'admin_compliance_section.dart'), [
  { search: "import 'package:pdf/pdf.dart';\n", replace: '' }
]);

// 4. admin_coupons_section.dart - value -> initialValue
applyReplacements(path.join(baseDir, 'admin_coupons_section.dart'), [
  { search: /value: /g, replace: 'initialValue: ' }, // Need to be careful here, wait! TextField/Dropdown might use `value`.
]);

// Let's refine the value -> initialValue replacements for TextFormField
const fixFormValue = (filePath) => {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  content = content.replace(/(TextFormField\([\s\S]*?)value: /g, '$1initialValue: ');
  fs.writeFileSync(filePath, content, 'utf8');
};

fixFormValue(path.join(baseDir, 'admin_coupons_section.dart'));
fixFormValue(path.join(baseDir, 'admin_disputes_section.dart'));
fixFormValue(path.join(baseDir, 'admin_finance_section.dart'));
fixFormValue(path.join(baseDir, 'admin_kyc_section.dart'));
fixFormValue(path.join(baseDir, 'admin_notifications_section.dart'));
fixFormValue(path.join(baseDir, 'admin_rider_intelligence_section.dart'));

// 5. admin_dashboard_v2_section.dart - withOpacity -> withValues(alpha: X)
applyReplacements(path.join(baseDir, 'admin_dashboard_v2_section.dart'), [
  { search: /\.withOpacity\((.*?)\)/g, replace: '.withValues(alpha: $1)' }
]);

// 6. admin_finance_section.dart - unused import, fields
applyReplacements(path.join(baseDir, 'admin_finance_section.dart'), [
  { search: "import '../../../widgets/state_views.dart';\n", replace: '' },
  { search: "int _settlementsTotalPages = 1;\n", replace: '' },
  { search: "int _refundsTotalPages = 1;\n", replace: '' },
  { search: "int _refundsPage = 1;\n", replace: 'final int _refundsPage = 1;\n' },
  { search: "_settlementsTotalPages = res['meta']['totalPages'] ?? 1;", replace: '' },
  { search: "_refundsTotalPages = res['meta']['totalPages'] ?? 1;", replace: '' }
]);

// 7. admin_kyc_section.dart - context warning
applyReplacements(path.join(baseDir, 'admin_kyc_section.dart'), [
  { search: /if \(mounted\) \{\n                    Navigator\.pop\(context\);\n                    _fetchApps\(\);\n                    _fetchDashboard\(\);\n                  \}/g, replace: 'if (mounted) {\n                    Navigator.pop(context);\n                  }\n                  _fetchApps();\n                  _fetchDashboard();' }
]);

// 8. admin_security_section.dart - context warning
applyReplacements(path.join(baseDir, 'admin_security_section.dart'), [
  { search: /if \(mounted\) \{\n                    Navigator\.pop\(context\);\n                    _fetchSecurityData\(\);\n                  \}/g, replace: 'if (mounted) {\n                    Navigator.pop(context);\n                  }\n                  _fetchSecurityData();' }
]);

// 9. admin_web_panel.dart - remove unused elements
applyReplacements(path.join(baseDir, 'admin_web_panel.dart'), [
  { search: /Widget _buildKycHub\(\) \{[\s\S]*?\}\n/g, replace: '' },
  { search: /Widget _buildRiders\(\) \{[\s\S]*?\}\n/g, replace: '' },
  { search: /Widget _buildAnalytics\(\) \{[\s\S]*?\}\n/g, replace: '' }
]);

console.log('Applied automated fixes');
