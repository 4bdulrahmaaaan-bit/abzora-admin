const fs = require('fs');

try {
  let pds = fs.readFileSync('lib/screens/user/product_detail_screen.dart', 'utf8');
  if (!pds.includes("import 'package:abzio/services/app_config.dart';")) {
    pds = "import 'package:abzio/services/app_config.dart';\n" + pds;
    fs.writeFileSync('lib/screens/user/product_detail_screen.dart', pds);
    console.log('Fixed product_detail_screen.dart missing import');
  }
} catch(e) {
  console.log(e);
}

try {
  let checkout = fs.readFileSync('lib/screens/user/checkout_screen.dart', 'utf8');
  let importStmt = "import 'package:abzio/services/app_config.dart';\n";
  let firstIndex = checkout.indexOf(importStmt);
  if (firstIndex !== -1) {
    let nextIndex = checkout.indexOf(importStmt, firstIndex + importStmt.length);
    if (nextIndex !== -1) {
      // Remove duplicate
      checkout = checkout.slice(0, nextIndex) + checkout.slice(nextIndex + importStmt.length);
      fs.writeFileSync('lib/screens/user/checkout_screen.dart', checkout);
      console.log('Fixed checkout_screen.dart duplicate import');
    }
  }
} catch(e) {
  console.log(e);
}

try {
  let ds = fs.readFileSync('lib/services/delivery_service.dart', 'utf8');
  let dsImport = "import 'package:abzio/services/app_config.dart';\n";
  if (ds.includes(dsImport) && !ds.includes('AppConfig')) {
    ds = ds.replace(dsImport, '');
    fs.writeFileSync('lib/services/delivery_service.dart', ds);
    console.log('Fixed delivery_service.dart unused import');
  }
} catch(e) {
  console.log(e);
}
