const fs = require('fs');

try {
  let content = fs.readFileSync('lib/screens/user/checkout_screen.dart', 'utf8');
  content = content.replace(/AppConfig\.enableLocalRiderDelivery \? buildDeliveryOptions\(\) : const SizedBox\.shrink\(\)/g, 'AppConfig.enableLocalRiderDelivery ? _buildDeliveryOptions() : const SizedBox.shrink()');
  fs.writeFileSync('lib/screens/user/checkout_screen.dart', content);
  console.log('Fixed checkout_screen');
} catch(e) {
  console.log(e);
}

try {
  let content2 = fs.readFileSync('lib/widgets/customer/delivery_mode_selector.dart', 'utf8');
  if (!content2.includes("import 'package:abzio/services/app_config.dart';")) {
    content2 = "import 'package:abzio/services/app_config.dart';\n" + content2;
  }
  fs.writeFileSync('lib/widgets/customer/delivery_mode_selector.dart', content2);
  console.log('Fixed delivery_mode_selector');
} catch(e) {
  console.log(e);
}
