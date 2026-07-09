const fs = require('fs');

try {
  let checkout = fs.readFileSync('lib/screens/user/checkout_screen.dart', 'utf8');
  const importStmt = "import 'package:abzio/services/app_config.dart';";
  
  // Find all occurrences of the import
  let firstIdx = checkout.indexOf(importStmt);
  if (firstIdx !== -1) {
    let nextIdx = checkout.indexOf(importStmt, firstIdx + importStmt.length);
    if (nextIdx !== -1) {
      // It appears multiple times, let's just keep the first one and replace others
      let firstPart = checkout.slice(0, firstIdx + importStmt.length);
      let secondPart = checkout.slice(firstIdx + importStmt.length);
      // Remove all subsequent occurrences
      secondPart = secondPart.split(importStmt).join('');
      fs.writeFileSync('lib/screens/user/checkout_screen.dart', firstPart + secondPart);
      console.log('Fixed checkout_screen.dart duplicate import');
    }
  }
} catch(e) {
  console.log('Error in checkout:', e.message);
}

try {
  let pds = fs.readFileSync('lib/screens/user/product_detail_screen.dart', 'utf8');
  // Remove BOM if present
  if (pds.charCodeAt(0) === 0xFEFF) {
    pds = pds.slice(1);
    fs.writeFileSync('lib/screens/user/product_detail_screen.dart', pds);
    console.log('Removed BOM from product_detail_screen.dart');
  }
} catch(e) {
  console.log('Error in pds:', e.message);
}
