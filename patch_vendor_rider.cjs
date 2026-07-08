const fs = require('fs');

try {
  let om = fs.readFileSync('lib/screens/vendor/order_management.dart', 'utf8');
  if (!om.includes("import '../../services/app_config.dart';")) {
    om = "import '../../services/app_config.dart';\n" + om;
  }
  om = om.replace(
    /'Orders ready for rider pickup appear here.',/,
    `AppConfig.enableLocalRiderDelivery ? 'Orders ready for rider pickup appear here.' : 'Orders ready for courier pickup appear here.',`
  );
  fs.writeFileSync('lib/screens/vendor/order_management.dart', om);
  console.log('Patched order_management.dart');
} catch (e) {
  console.log(e);
}

try {
  let vot = fs.readFileSync('lib/widgets/vendor_orders_tab.dart', 'utf8');
  if (!vot.includes("import '../services/app_config.dart';")) {
    vot = "import '../services/app_config.dart';\n" + vot;
  }
  vot = vot.replace(
    /order\.deliveryType == 'COURIER_DELIVERY'\s*\?\s*'Waiting for courier update'\s*:\s*'Waiting for rider pickup'/,
    `order.deliveryType == 'COURIER_DELIVERY' || !AppConfig.enableLocalRiderDelivery\n                  ? 'Waiting for courier update'\n                  : 'Waiting for rider pickup'`
  );
  fs.writeFileSync('lib/widgets/vendor_orders_tab.dart', vot);
  console.log('Patched vendor_orders_tab.dart');
} catch (e) {
  console.log(e);
}
