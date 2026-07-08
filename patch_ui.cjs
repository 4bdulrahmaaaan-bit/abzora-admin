const fs = require('fs');

try {
  let content = fs.readFileSync('lib/services/delivery_service.dart', 'utf8');

  if (!content.includes('package:abzio/services/app_config.dart')) {
    content = "import 'package:abzio/services/app_config.dart';\n" + content;
  }

  content = content.replace(
    /Future<DeliveryMode> determineDeliveryMode\(dynamic order\) async \{/g,
    'Future<DeliveryMode> determineDeliveryMode(dynamic order) async {\n    if (!AppConfig.enableLocalRiderDelivery) return DeliveryMode.courier;'
  );

  fs.writeFileSync('lib/services/delivery_service.dart', content);
  console.log('Patched delivery_service.dart');
} catch (e) {
  console.log('Error delivery_service:', e.message);
}

try {
  let content = fs.readFileSync('lib/widgets/customer/delivery_mode_selector.dart', 'utf8');
  if (!content.includes('package:abzio/services/app_config.dart')) {
    content = "import 'package:abzio/services/app_config.dart';\n" + content;
  }
  content = content.replace(
    /return Column\(/g,
    'if (!AppConfig.enableLocalRiderDelivery) return const SizedBox.shrink();\n    return Column('
  );
  fs.writeFileSync('lib/widgets/customer/delivery_mode_selector.dart', content);
  console.log('Patched delivery_mode_selector.dart');
} catch (e) {
  console.log('Error delivery_mode_selector:', e.message);
}

try {
  let content2 = fs.readFileSync('lib/screens/user/checkout_screen.dart', 'utf8');
  if (!content2.includes('package:abzio/services/app_config.dart')) {
    content2 = "import 'package:abzio/services/app_config.dart';\n" + content2;
  }
  content2 = content2.replace(
    /buildDeliveryOptions\(\)/g,
    'AppConfig.enableLocalRiderDelivery ? buildDeliveryOptions() : const SizedBox.shrink()'
  );
  fs.writeFileSync('lib/screens/user/checkout_screen.dart', content2);
  console.log('Patched checkout_screen.dart');
} catch (e) {
  console.log('Error checkout_screen:', e.message);
}
