# ABZORA RTDB Emulator Validation

Use this playbook to validate Firebase Realtime Database rules and role isolation before deploying [database.rules.json](/C:/Users/AAA/Documents/abzio/database.rules.json).

## 1. Start the emulators

Install the rules test dependencies once:

```powershell
npm install
```

Run in one shell:

```powershell
firebase emulators:start --only auth,database
```

## 2. Launch the app against emulators

Run in a second shell:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099 --dart-define=FIREBASE_DATABASE_EMULATOR_PORT=9000
```

You can also print the same local flow with:

```powershell
.\scripts\run_local_validation.ps1 -UseEmulators -ShowRtdbChecks
```

To run the automated RTDB permission suite:

```powershell
npm run test:rtdb-rules:emulator
```

## 3. Seed or prepare role accounts

Create four accounts in the emulator:

- customer
- vendor
- rider
- admin

Ensure the corresponding records exist under `users/{uid}` with:

- `role`
- `storeId` for vendor users
- `isActive`

## 4. Customer rule checks

- Login as customer.
- Save an address and confirm it writes only to `users/{uid}/addresses/{addressId}`.
- Save a wishlist item and confirm it writes only to `wishlist/{uid}/{productId}`.
- Save a measurement profile and confirm it writes only to `measurements/{uid}/{profileId}`.
- Place an order and confirm:
  - `orders/{orderId}.userId == auth.uid`
  - the order appears in the customer order list
  - another customer cannot read it
- Cancel the order from the tracking flow and confirm:
  - `status = Cancelled`
  - `deliveryStatus = Cancelled`
  - `storeId`, `items`, `totalAmount`, `vendorEarnings`, `payoutStatus`, and `riderId` do not change
- Confirm customer notifications show only:
  - `userId == auth.uid`
  - `audienceRole = user`
  - `audienceRole = customer`
  - `audienceRole = all`

## 5. Vendor rule checks

- Login as vendor.
- Complete onboarding and confirm the store is written with:
  - `approvalStatus = pending`
  - `isApproved = false`
  - `isActive = false`
- Add a product and confirm the write succeeds only when:
  - `storeId == users/{vendorUid}.storeId`
  - or legacy `store_id == users/{vendorUid}.storeId`
- Try editing another vendor's product and confirm it is denied.
- Confirm vendor dashboards load only:
  - their own store
  - their own store products
  - their own store orders
  - their own store payouts
  - their own store notifications

## 6. Rider rule checks

- Login as rider.
- Assign the rider to an order from admin/vendor flow.
- Confirm rider dashboard shows only assigned deliveries where `riderId == auth.uid`.
- Update delivery status and confirm unassigned orders cannot be modified by the rider.
- Confirm rider notifications show only documents where:
  - `audienceRole = rider`
  - `userId == auth.uid`

## 7. Admin rule checks

- Login as admin.
- Confirm admin can:
  - read and update users
  - approve/reject vendors
  - activate/deactivate or feature stores
  - update order state
  - process payouts
  - view disputes
  - view activity logs
- Confirm admin notifications show:
  - `audienceRole = admin`
  - `audienceRole = all`

## 8. Query and index checks

Validate these app queries while the emulator is running:

- `orders.orderByChild('userId').equalTo(customerUid)`
- `orders.orderByChild('storeId').equalTo(vendorStoreId)`
- `orders.orderByChild('riderId').equalTo(riderUid)`
- `notifications.orderByChild('userId').equalTo(customerUid or riderUid)`
- `notifications.orderByChild('storeId').equalTo(vendorStoreId)`
- `notifications.orderByChild('audienceRole').equalTo('all')`
- `payouts.orderByChild('storeId').equalTo(vendorStoreId)`

Expected result:

- no `permission_denied`
- no missing-index warnings
- role-scoped data only

## 9. Release gate

Before production deploy, rerun:

```powershell
flutter analyze
flutter test
firebase deploy --only database --project abzio-d99f9
```
