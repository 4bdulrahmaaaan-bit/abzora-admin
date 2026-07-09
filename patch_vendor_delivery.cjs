const fs = require('fs');
let content = fs.readFileSync('lib/screens/vendor/product_form/product_delivery_section.dart', 'utf8');

if (!content.includes("import '../../../services/app_config.dart';")) {
  content = content.replace(
    /import 'package:provider\/provider\.dart';/,
    "import 'package:provider/provider.dart';\nimport '../../../services/app_config.dart';"
  );
}

content = content.replace(
  /_buildToggleChip\(\s*label:\s*'Same Day',[\s\S]*?\),/,
  `if (AppConfig.enableLocalRiderDelivery)
              _buildToggleChip(
                label: 'Same Day',
                icon: Icons.bolt_rounded,
                isActive: controller.sameDayDelivery,
                onToggle: controller.toggleSameDayDelivery,
              ),`
);

content = content.replace(
  /_buildToggleChip\(\s*label:\s*'Try Before You Buy',[\s\S]*?\),/,
  `if (AppConfig.enableLocalRiderDelivery)
              _buildToggleChip(
                label: 'Try Before You Buy',
                icon: Icons.checkroom_outlined,
                isActive: controller.tryBeforeYouBuy,
                onToggle: controller.toggleTryBeforeYouBuy,
              ),`
);

fs.writeFileSync('lib/screens/vendor/product_form/product_delivery_section.dart', content);
console.log('patched product_delivery_section.dart');
