const fs = require('fs');

let pds = fs.readFileSync('lib/screens/user/product_detail_screen.dart', 'utf8');

// The file had a BOM and my previous script did slice(1). So the first character got sliced.
// If the very first word was 'import', it became 'mport'. Let's check and fix that too.
if (pds.startsWith('mport ')) {
  pds = 'i' + pds;
}

const importStmt = "import 'package:abzio/services/app_config.dart';";
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
  fs.writeFileSync('lib/screens/user/product_detail_screen.dart', parts.join('\n'));
  console.log('Added import to product_detail_screen.dart');
} else {
  fs.writeFileSync('lib/screens/user/product_detail_screen.dart', pds);
  console.log('Fixed mport issue if any');
}
