const fs = require('fs');

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
