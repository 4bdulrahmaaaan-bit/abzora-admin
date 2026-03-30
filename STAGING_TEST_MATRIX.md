# ABZORA Staging UX Sign-Off Sheet

Use this sheet for the final staging release pass. Mark each item with `PASS`, `FAIL`, or `BLOCKED`, assign an owner, and capture notes before sign-off.

## Sign-off summary

| Area | Owner | Status | Notes |
|---|---|---|---|
| Customer journey |  |  |  |
| Vendor journey |  |  |  |
| Rider journey |  |  |  |
| Admin journey |  |  |  |
| Payments |  |  |  |
| Notifications |  |  |  |
| Visual QA |  |  |  |
| Final release gate |  |  |  |

## 0. Preflight

| Check | Owner | Status | Notes |
|---|---|---|---|
| Staging has `RAZORPAY_KEY` |  |  |  |
| Staging has `GOOGLE_MAPS_API_KEY` |  |  |  |
| Staging has Cloudinary config or signed upload endpoint |  |  |  |
| RTDB rules deployed to staging |  |  |  |
| Storage rules deployed to staging |  |  |  |
| Test accounts exist for customer, vendor, rider, admin |  |  |  |
| Seed data exists for stores, products, brands, and custom products |  |  |  |

## 1. Customer Journey

### 1.1 Auth and launch

| Check | Owner | Status | Notes |
|---|---|---|---|
| Customer phone OTP login succeeds |  |  |  |
| Customer lands in shop flow, not ops/admin |  |  |  |
| No blank splash or route loop after login |  |  |  |
| Profile shows customer identity correctly |  |  |  |

### 1.2 Home and location

| Check | Owner | Status | Notes |
|---|---|---|---|
| GPS location flow works from location selector |  |  |  |
| Denied permission falls back cleanly |  |  |  |
| Manual city selection works |  |  |  |
| Radius changes update nearby-store results |  |  |  |
| Delivery text shows real user/city instead of guest fallback |  |  |  |
| Empty nearby state suggests changing location or radius |  |  |  |

### 1.3 Search, browse, wishlist

| Check | Owner | Status | Notes |
|---|---|---|---|
| Header search opens dedicated search screen |  |  |  |
| Search works for product, brand, and store keywords |  |  |  |
| Wishlist toggle works from home card |  |  |  |
| Wishlist toggle works from product detail |  |  |  |
| Wishlist screen shows only current user's saved items |  |  |  |

### 1.4 Product and cart

| Check | Owner | Status | Notes |
|---|---|---|---|
| Product detail image gallery loads |  |  |  |
| Price formatting uses proper rupee display |  |  |  |
| Discount/original price display is consistent |  |  |  |
| Same-store add to cart works |  |  |  |
| Cross-store add is blocked with clear messaging |  |  |  |
| Quantity update and remove actions work |  |  |  |

### 1.5 Address and checkout

| Check | Owner | Status | Notes |
|---|---|---|---|
| Address add/edit works manually |  |  |  |
| Address autofill from current location works |  |  |  |
| Checkout stepper flows through Address > Summary > Payment |  |  |  |
| Empty cart checkout is blocked |  |  |  |
| Missing address is blocked |  |  |  |
| COD order places successfully |  |  |  |
| Razorpay success places order only after payment |  |  |  |
| Razorpay cancel/failure returns safe error state |  |  |  |
| Missing Razorpay key disables online payment safely |  |  |  |

### 1.6 Post-order experience

| Check | Owner | Status | Notes |
|---|---|---|---|
| Order success screen shows order id and ETA |  |  |  |
| Order tracking timeline animates correctly |  |  |  |
| Customer sees only own orders |  |  |  |
| Cancel order works only before shipment |  |  |  |

### 1.7 Custom clothing

| Check | Owner | Status | Notes |
|---|---|---|---|
| Brand selection loads |  |  |  |
| Brand products load |  |  |  |
| Customizations save through review step |  |  |  |
| Measurement selection returns correctly |  |  |  |
| Measurement profile save/reuse works |  |  |  |
| Custom clothing order places successfully |  |  |  |

### 1.8 Notifications and chat

| Check | Owner | Status | Notes |
|---|---|---|---|
| Customer-visible notifications load correctly |  |  |  |
| Mark-all-read works |  |  |  |
| Chat list shows only participant chats |  |  |  |
| Chat detail loads messages with timestamps |  |  |  |

## 2. Vendor Journey

### 2.1 Vendor onboarding

| Check | Owner | Status | Notes |
|---|---|---|---|
| Vendor login works |  |  |  |
| Vendor onboarding saves a geocoded store |  |  |  |
| New store is marked `pending` |  |  |  |
| Vendor cannot manage another store |  |  |  |

### 2.2 Store management

| Check | Owner | Status | Notes |
|---|---|---|---|
| Store name/address updates save correctly |  |  |  |
| Logo upload works |  |  |  |
| Banner upload works |  |  |  |
| Unsupported upload types are blocked |  |  |  |
| Uploaded URLs are valid and render |  |  |  |

### 2.3 Product management

| Check | Owner | Status | Notes |
|---|---|---|---|
| Vendor can add a product with brand, price, original price, category, images |  |  |  |
| Vendor can edit own product |  |  |  |
| Vendor can hide and re-enable product |  |  |  |
| Vendor cannot create/update products for another store |  |  |  |

### 2.4 Vendor orders and payouts

| Check | Owner | Status | Notes |
|---|---|---|---|
| Vendor sees only own store orders |  |  |  |
| Vendor status updates reflect for customer/admin |  |  |  |
| Vendor payout visibility is limited to own store |  |  |  |

## 3. Rider Journey

| Check | Owner | Status | Notes |
|---|---|---|---|
| Rider login works |  |  |  |
| Rider sees only assigned deliveries |  |  |  |
| Rider cannot access unrelated orders |  |  |  |
| Delivery status updates persist correctly |  |  |  |
| Customer tracking reflects rider updates |  |  |  |
| Rider receives only rider-targeted notifications |  |  |  |

## 4. Admin Journey

### 4.1 Admin access

| Check | Owner | Status | Notes |
|---|---|---|---|
| Allowed device + correct PIN login works |  |  |  |
| Blocked device is denied |  |  |  |
| Wrong PIN is denied |  |  |  |

### 4.2 Vendor approval and store control

| Check | Owner | Status | Notes |
|---|---|---|---|
| Approve pending store works |  |  |  |
| Reject pending store works |  |  |  |
| Active toggle works |  |  |  |
| Featured toggle works |  |  |  |
| Vendor-facing state reflects approval outcome |  |  |  |

### 4.3 Order and payout oversight

| Check | Owner | Status | Notes |
|---|---|---|---|
| Admin can view all orders |  |  |  |
| Admin order status updates work |  |  |  |
| Payout processing creates payout records |  |  |  |
| Paid orders move to paid payout state |  |  |  |
| Vendor wallet/payout totals remain consistent |  |  |  |

### 4.4 Admin monitoring

| Check | Owner | Status | Notes |
|---|---|---|---|
| Admin can view disputes |  |  |  |
| Admin can view users |  |  |  |
| Admin can view products |  |  |  |
| Admin can view activity logs |  |  |  |
| Moderation actions work correctly |  |  |  |

## 5. Notifications and Permissions

| Check | Owner | Status | Notes |
|---|---|---|---|
| Push permission granted flow works |  |  |  |
| Push permission denied flow works safely |  |  |  |
| Provisional permission flow works where supported |  |  |  |
| FCM token is saved to user record |  |  |  |
| Admin topic subscription works |  |  |  |
| Vendor topic subscription works |  |  |  |
| Rider topic subscription works |  |  |  |
| No false-ready notification state appears when permission is denied |  |  |  |

## 6. Visual QA

| Check | Owner | Status | Notes |
|---|---|---|---|
| No overflow errors on phone layout |  |  |  |
| No clipped CTA buttons |  |  |  |
| No blank screens |  |  |  |
| Loading/shimmer states appear where expected |  |  |  |
| Premium and light-theme sections feel visually consistent |  |  |  |
| Admin layout works on wider screens |  |  |  |

## 7. Release Gate

| Check | Owner | Status | Notes |
|---|---|---|---|
| `flutter analyze` passes |  |  |  |
| `flutter test` passes |  |  |  |
| `npm run test:rtdb-rules:emulator` passes |  |  |  |
| Customer journey signed off |  |  |  |
| Vendor journey signed off |  |  |  |
| Rider journey signed off |  |  |  |
| Admin journey signed off |  |  |  |
| Payments signed off |  |  |  |
| Notifications signed off |  |  |  |
| No blocker UX regressions remain |  |  |  |
