# ABZIO Production Deploy Checklist

## 1. Firebase project and environment

- Confirm the production Firebase project matches `lib/firebase_options.dart`.
- Set runtime values for:
  - `RAZORPAY_KEY`
  - `GOOGLE_MAPS_API_KEY`
  - Cloudinary values if production presets differ
- For local integration, enable emulators with:
  - `--dart-define=USE_FIREBASE_EMULATORS=true`
  - `--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1`
  - optional port overrides for auth/db

## 2. Realtime Database rules

- Review and deploy [database.rules.json](/C:/Users/AAA/Documents/abzio/database.rules.json).
- Validate these paths with the Firebase Emulator Suite:
  - `users`
  - `stores`
  - `products`
  - `orders`
  - `measurements`
  - `notifications`
  - `chats`
- Confirm vendor users cannot read/write other stores.
- Confirm riders only see assigned orders.
- Confirm customers only see their own orders and measurements.

### RTDB validation scenarios

- Customer:
  - can read and update only `users/{uid}` and `users/{uid}/addresses/*`
  - can create orders where `orders/{orderId}.userId == auth.uid`
  - cannot edit `storeId`, `items`, `totalAmount`, `payoutStatus`, `riderId`, or `vendorEarnings` after order creation
  - can only cancel their own order by setting `status = Cancelled` and `deliveryStatus = Cancelled`
  - can read/write only `measurements/{uid}/*`
  - can read/write only `wishlist/{uid}/*`
  - can read only their own `notifications` plus `audienceRole = all`
  - can create/delete only their own `reviews`
- Vendor:
  - can read their own `stores/{storeId}` and public store/product data
  - can only write the store linked to `users/{uid}.storeId`
  - can only create/update products whose `storeId` or legacy `store_id` matches their store
  - cannot read or modify payouts for another store
  - can read only orders where `storeId == users/{uid}.storeId`
  - can update fulfillment state for their store orders, but not other stores' orders
  - can read only vendor-scoped notifications for their store
- Rider:
  - can read only orders where `riderId == auth.uid`
  - can update delivery state only on assigned orders
  - can read only rider notifications addressed to `userId == auth.uid`
  - cannot read vendor payouts, store management data, or admin-only notifications
- Admin:
  - can read/write all operational paths: `users`, `stores`, `products`, `orders`, `notifications`, `activityLogs`, `payouts`, `platform`, `disputes`
  - can approve/reject vendors and process payouts
  - can read all notifications, including `audienceRole = admin` and `audienceRole = all`

### Query/index checks

- Verify `orders` queries work with:
  - `orderByChild('userId')`
  - `orderByChild('storeId')`
  - `orderByChild('riderId')`
- Verify `notifications` queries work with:
  - `orderByChild('userId')`
  - `orderByChild('storeId')`
  - `orderByChild('audienceRole')`
- Verify `payouts` queries work with:
  - `orderByChild('storeId')`
- Verify product writes succeed for both shapes during migration:
  - `storeId`
  - `store_id`

## 3. Authentication

- Verify Phone Auth is enabled in Firebase Console.
- Add all production domains to authorized domains for web OTP.
- Test admin login from:
  - allowed device
  - blocked device
  - correct admin PIN
  - incorrect admin PIN

## 4. Marketplace data quality

- Ensure every store has:
  - `store_id`
  - `latitude`
  - `longitude`
  - `address`
- Ensure every product has:
  - `store_id`
  - `price`
  - `stock`
  - at least one valid image
- Seed custom clothing data:
  - `brands`
  - `custom_products`

## 5. Payments and checkout

- Configure live or staging Razorpay credentials before enabling online payments.
- Confirm missing Razorpay keys disable online payment safely instead of auto-succeeding.
- Test:
  - COD checkout
  - Razorpay success
  - Razorpay failure/cancel
  - one-store cart guard

## 6. Notifications

- Confirm notification permission handling on Android/iOS:
  - granted
  - denied
  - provisional where supported
- Verify FCM token updates land in Realtime Database.
- Validate topic subscriptions for:
  - admin
  - vendor
  - rider
- Send staging notifications for order, payout, and rider assignment flows.

## 6.5 Upload security

- Review and deploy [storage.rules](/C:/Users/AAA/Documents/abzio/storage.rules).
- Confirm Firebase Storage writes are owner-scoped by path:
  - `product_images/{uid}/*`
  - `store_logos/{uid}/*`
  - `store_banners/{uid}/*`
- Confirm Storage uploads reject:
  - unauthenticated writes
  - non-image content types
  - files larger than 10 MB
- Confirm Cloudinary is configured explicitly with production values:
  - `CLOUDINARY_CLOUD_NAME`
  - `CLOUDINARY_UPLOAD_PRESET`
- Review the Cloudinary upload preset in the Cloudinary dashboard:
  - restrict to images only
  - set folder restrictions if supported
  - disable broad unsigned upload access if you move to a signed-upload backend later
- Validate vendor uploads reject unsupported file types and images larger than 8 MB in-app.
- For signed-upload migration, use [CLOUDINARY_SIGNED_UPLOAD_SPEC.md](/C:/Users/AAA/Documents/abzio/CLOUDINARY_SIGNED_UPLOAD_SPEC.md).

## 7. Operational smoke tests

- Customer:
  - login
  - GPS/manual location
  - browse nearby stores
  - add to cart
  - checkout
  - custom brand order
- Vendor:
  - onboarding
  - add/edit product
  - view orders
- Rider:
  - see assigned order
  - update delivery status
- Admin:
  - login
  - store approval
  - payout processing
  - user role changes

## 8. Release gate

- Run:
  - `flutter analyze`
  - `flutter test`
- Run a staging smoke test before every production deploy.
- Back up production RTDB before schema or rules changes.
