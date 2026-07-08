const fs = require('fs');

let content = fs.readFileSync('lib/screens/user/product_detail_screen.dart', 'utf8');

// Patch _bottomLeftCtaLabel
content = content.replace(
  /String _bottomLeftCtaLabel\(\) \{[\s\S]*?return 'Notify Me';\n  \}/m,
  `String _bottomLeftCtaLabel() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.loading) {
      return '';
    }
    if (state == _DeliveryAvailabilityState.error) {
      return 'Retry';
    }
    if (state == _DeliveryAvailabilityState.noAddress) {
      return 'Change Delivery Address';
    }
    if (_isProductInStock) {
      if (AppConfig.enableLocalRiderDelivery && _canTryAtHome) {
        return 'Try At Home';
      }
      return 'Add to Cart';
    }
    return 'Notify Me';
  }`
);

// Patch _bottomRightCtaLabel
content = content.replace(
  /String _bottomRightCtaLabel\(\) \{[\s\S]*?return 'Change Delivery Address';\n  \}/m,
  `String _bottomRightCtaLabel() {
    final state = _deliveryAvailabilityState;
    if (state == _DeliveryAvailabilityState.loading) {
      return '';
    }
    if (state == _DeliveryAvailabilityState.error) {
      return 'Change Delivery Address';
    }
    if (state == _DeliveryAvailabilityState.noAddress) {
      return 'Notify Me';
    }
    if (_isProductInStock) {
      if (AppConfig.enableLocalRiderDelivery && _canTryAtHome) {
        return 'Get It Today';
      }
      return 'Buy Now';
    }
    return 'Check Other Locations';
  }`
);

// Patch _bottomLeftCtaAction
content = content.replace(
  /VoidCallback\? _bottomLeftCtaAction\(Product product\) \{[\s\S]*?_handleNotifyMeTap\(product\);\n    \};\n  \}/m,
  `VoidCallback? _bottomLeftCtaAction(Product product) {
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.loading) {
      return null;
    }
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.error) {
      return () {
        HapticFeedback.lightImpact();
        unawaited(_refreshServiceability(force: true));
      };
    }
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.noAddress) {
      return () {
        HapticFeedback.lightImpact();
        _openDeliveryAddressSheet();
      };
    }
    if (_isProductInStock) {
      if (AppConfig.enableLocalRiderDelivery && _canTryAtHome) {
        return () {
          HapticFeedback.lightImpact();
          _handleTryHomeTap(product);
        };
      }
      return () {
        HapticFeedback.lightImpact();
        _handleAddToCartTap(product);
      };
    }
    return () {
      HapticFeedback.lightImpact();
      _handleNotifyMeTap(product);
    };
  }`
);

// Patch _bottomRightCtaAction
content = content.replace(
  /VoidCallback\? _bottomRightCtaAction\(Product product\) \{[\s\S]*?_openDeliveryAddressSheet\(\);\n    \};\n  \}/m,
  `VoidCallback? _bottomRightCtaAction(Product product) {
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.loading) {
      return null;
    }
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.error) {
      return () {
        HapticFeedback.lightImpact();
        _openDeliveryAddressSheet();
      };
    }
    if (_deliveryAvailabilityState == _DeliveryAvailabilityState.noAddress) {
      return () {
        HapticFeedback.lightImpact();
        _handleNotifyMeTap(product);
      };
    }
    if (_isProductInStock) {
      return () {
        HapticFeedback.lightImpact();
        _handleBuyNowTap(product);
      };
    }
    return () {
      HapticFeedback.lightImpact();
      _openDeliveryAddressSheet();
    };
  }`
);

fs.writeFileSync('lib/screens/user/product_detail_screen.dart', content);
console.log('Patched product_detail_screen.dart');
