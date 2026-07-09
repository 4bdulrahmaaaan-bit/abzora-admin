const fs = require('fs');

// Helper to remove BOM
function stripBOM(content) {
  if (content.charCodeAt(0) === 0xFEFF) {
    return content.slice(1);
  }
  return content;
}

try {
  // Fix checkout_screen.dart
  let checkout = fs.readFileSync('lib/screens/user/checkout_screen.dart', 'utf8');
  checkout = stripBOM(checkout);
  
  const importStmt = "import 'package:abzio/services/app_config.dart';";
  const regex = new RegExp(importStmt.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
  
  let matchCount = (checkout.match(regex) || []).length;
  
  if (matchCount > 1) {
    // Keep first, replace others
    let firstIdx = checkout.indexOf(importStmt);
    let before = checkout.slice(0, firstIdx + importStmt.length);
    let after = checkout.slice(firstIdx + importStmt.length);
    after = after.replace(regex, '');
    
    fs.writeFileSync('lib/screens/user/checkout_screen.dart', before + after);
    console.log('Fixed checkout_screen.dart duplicate import');
  }

  // Fix product_detail_screen.dart
  let pds = fs.readFileSync('lib/screens/user/product_detail_screen.dart', 'utf8');
  pds = stripBOM(pds);

  // If there's an illegal character on line 2, let's just strip all ZERO WIDTH NO-BREAK SPACE characters everywhere
  pds = pds.replace(/\uFEFF/g, '');

  if (pds.startsWith('mport ')) {
    pds = 'i' + pds;
  }
  
  if (!pds.includes(importStmt)) {
    const parts = pds.split('\n');
    let importIndex = 0;
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].startsWith('import ')) {
        importIndex = i + 1;
      } else if (parts[i].trim() === '') {
        continue;
      } else if (importIndex > 0) {
        break;
      }
    }
    parts.splice(importIndex, 0, importStmt);
    pds = parts.join('\n');
    console.log('Added import to product_detail_screen.dart');
  }
  
  fs.writeFileSync('lib/screens/user/product_detail_screen.dart', pds);
  console.log('Cleaned product_detail_screen.dart');

} catch(e) {
  console.log(e);
}
