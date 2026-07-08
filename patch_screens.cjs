const fs = require('fs');

try {
  let content = fs.readFileSync('lib/screens/vendor/order_management.dart', 'utf8');

  if (!content.includes('package:abzio/services/app_config.dart')) {
    content = "import 'package:abzio/services/app_config.dart';\n" + content;
  }

  content = content.replace(
    /'Orders ready for rider pickup appear here.'/g,
    'AppConfig.enableLocalRiderDelivery ? \\'Orders ready for rider pickup appear here.\\' : \\'Orders ready for Shiprocket pickup appear here.\\''
  );

  fs.writeFileSync('lib/screens/vendor/order_management.dart', content);
  console.log('Patched order_management.dart');
} catch (e) {
  console.log(e.message);
}

try {
  let content = fs.readFileSync('lib/screens/admin/admin_dashboard_screen.dart', 'utf8');

  if (!content.includes('package:abzio/services/app_config.dart')) {
    content = "import 'package:abzio/services/app_config.dart';\n" + content;
  }

  content = content.replace(
    /return _buildActiveRidersMap\(\);/g,
    'if (!AppConfig.enableLocalRiderDelivery) return const SizedBox.shrink();\n                        return _buildActiveRidersMap();'
  );
  
  content = content.replace(
    /return _buildActiveRidersList\(\);/g,
    'if (!AppConfig.enableLocalRiderDelivery) return const SizedBox.shrink();\n                        return _buildActiveRidersList();'
  );

  fs.writeFileSync('lib/screens/admin/admin_dashboard_screen.dart', content);
  console.log('Patched admin_dashboard_screen.dart');
} catch (e) {
  console.log(e.message);
}
