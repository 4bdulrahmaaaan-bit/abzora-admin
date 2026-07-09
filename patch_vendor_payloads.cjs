const fs = require('fs');

try {
  let controller = fs.readFileSync('lib/screens/vendor/product_form/product_form_controller.dart', 'utf8');
  if (!controller.includes("import '../../../services/app_config.dart';")) {
    controller = "import '../../../services/app_config.dart';\n" + controller;
  }
  controller = controller.replace(
    /meta\['sameDayDelivery'\] = sameDayDelivery;/,
    "meta['sameDayDelivery'] = AppConfig.enableLocalRiderDelivery ? sameDayDelivery : false;"
  );
  controller = controller.replace(
    /meta\['tryBeforeYouBuy'\] = tryBeforeYouBuy;/,
    "meta['tryBeforeYouBuy'] = AppConfig.enableLocalRiderDelivery ? tryBeforeYouBuy : false;"
  );
  fs.writeFileSync('lib/screens/vendor/product_form/product_form_controller.dart', controller);
  console.log('Patched product_form_controller.dart');
} catch (e) {
  console.log(e);
}

try {
  let addScreen = fs.readFileSync('lib/screens/vendor/add_product_screen.dart', 'utf8');
  if (!addScreen.includes("import '../../services/app_config.dart';")) {
    addScreen = "import '../../services/app_config.dart';\n" + addScreen;
  }
  
  // Replace the deliveryInfo construction in add_product_screen.dart
  addScreen = addScreen.replace(
    /deliveryInfo:\s*\{[\s\S]*?\},/,
    `deliveryInfo: {
          'sameDayEligible': AppConfig.enableLocalRiderDelivery ? controller.sameDayDelivery : false,
          'supportsInstantDelivery': AppConfig.enableLocalRiderDelivery ? controller.sameDayDelivery : false,
          'codEligible': controller.cashOnDelivery,
          'cashOnDelivery': controller.cashOnDelivery,
          'freeReturns': controller.freeReturns,
          'tryBeforeYouBuy': AppConfig.enableLocalRiderDelivery ? controller.tryBeforeYouBuy : false,
          'tryAtHomeEligible': AppConfig.enableLocalRiderDelivery ? controller.tryBeforeYouBuy : false,
          'tryAtHomeAvailable': AppConfig.enableLocalRiderDelivery ? controller.tryBeforeYouBuy : false,
          'supportsTryAtHome': AppConfig.enableLocalRiderDelivery ? controller.tryBeforeYouBuy : false,
          'expressDelivery': controller.expressDelivery,
          'etaLabel': controller.etaDropdown,
        },`
  );
  fs.writeFileSync('lib/screens/vendor/add_product_screen.dart', addScreen);
  console.log('Patched add_product_screen.dart');
} catch (e) {
  console.log(e);
}
