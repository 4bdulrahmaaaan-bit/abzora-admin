const fs = require('fs');

try {
  let om = fs.readFileSync('lib/screens/vendor/order_management.dart', 'utf8');
  if (om.charCodeAt(0) === 0xFEFF) {
    om = om.slice(1);
  }
  // Remove all zero width no-break spaces just in case
  om = om.replace(/\uFEFF/g, '');
  
  // Fix the missing 'i' if the BOM slice took 'i' from 'import'
  if (om.startsWith('mport ')) {
    om = 'i' + om;
  }

  fs.writeFileSync('lib/screens/vendor/order_management.dart', om);
  console.log('Cleaned order_management.dart');
} catch (e) {
  console.log(e);
}
