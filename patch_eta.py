import sys

filepath = 'backend/services/hyperlocalDeliveryService.js'

with open(filepath, 'r') as f:
    content = f.read()

# Add require
if 'shiprocketService' not in content:
    content = content.replace("const { enableLocalRiderDelivery } = require('./deliveryModeService');", 
                              "const { enableLocalRiderDelivery } = require('./deliveryModeService');\nconst shiprocketService = require('./shiprocketService');")

# Insert Shiprocket ETA logic before caching
target = 'await setJson(cacheKey, response, 300);'

insertion = """
  // SHIPROCKET ETA FETCH
  if (response.supportsCourierDelivery && response.deliveryPartner === 'Shiprocket' && (!enableLocalRiderDelivery() || !response.supportsInstantDelivery)) {
    try {
      const srRates = await shiprocketService.getAvailableCouriers({
        pickupPostcode: productStore?.pincode || '110001',
        deliveryPostcode: normalizedPincode,
        weight: product.packageWeight || 0.5,
        cod: false
      });
      
      if (srRates && srRates.data && srRates.data.available_courier_companies) {
        const couriers = srRates.data.available_courier_companies;
        if (couriers.length > 0) {
          const cheapest = couriers.reduce((prev, curr) => (prev.rate < curr.rate) ? prev : curr);
          response.shippingCharge = cheapest.rate || response.shippingCharge;
          
          if (cheapest.etd) {
            response.estimatedDeliveryDate = cheapest.etd;
            response.eta = `Delivery by ${cheapest.etd.split(' ')[0]}`;
          }
        }
      }
    } catch (e) {
      console.error('Shiprocket ETA fetch error in deliveryCheck:', e);
    }
  }

  await setJson(cacheKey, response, 300);
"""

if "SHIPROCKET ETA FETCH" not in content:
    content = content.replace(target, insertion)

with open(filepath, 'w') as f:
    f.write(content)

print("Patched hyperlocalDeliveryService.js")
