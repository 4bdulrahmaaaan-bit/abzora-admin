# Abzio Firebase Backend Setup

This app is now Firebase-first, with demo fallback when collections are empty.

## Core Collections

### `users/{uid}`

```json
{
  "id": "firebase-auth-uid",
  "name": "Aarav Sharma",
  "email": "vendor@example.com",
  "phone": "+91...",
  "address": "Mumbai",
  "role": "user",
  "isActive": true,
  "storeId": "store_doc_id",
  "walletBalance": 0,
  "fcmToken": "optional-device-token"
}
```

Roles:
- `super_admin`
- `admin`
- `vendor`
- `rider`
- `user`

### `stores/{storeId}`

```json
{
  "id": "store_doc_id",
  "ownerId": "firebase-auth-uid",
  "name": "Zyla Fashion",
  "description": "Premium boutique",
  "imageUrl": "https://...",
  "rating": 4.8,
  "reviewCount": 124,
  "address": "Bandra, Mumbai",
  "isApproved": false,
  "isActive": false,
  "isFeatured": false,
  "logoUrl": "https://...",
  "bannerImageUrl": "https://...",
  "tagline": "Wedding edits and elevated essentials.",
  "commissionRate": 0.12,
  "walletBalance": 0
}
```

### `products/{productId}`

Every product must include:
- `storeId`
- `name`
- `description`
- `price`
- `images`
- `sizes`
- `stock`
- `category`

Optional tailoring fields:
- `isCustomTailoring`
- `outfitType`
- `fabric`
- `customizations`
- `measurements`
- `addons`
- `measurementProfileLabel`
- `neededBy`
- `tailoringDeliveryMode`
- `tailoringExtraCost`

### `orders/{orderId}`

Every order must include:
- `userId`
- `storeId`
- `items`
- `status`
- `paymentMethod`
- `timestamp`
- `subtotal`
- `taxAmount`
- `platformCommission`
- `vendorEarnings`
- `payoutStatus`
- `trackingId`
- `deliveryStatus`
- `assignedDeliveryPartner`
- `invoiceNumber`
- `orderType`

### Other collections

- `reviews`
- `measurementProfiles`
- `bookings`
- `chats/{chatId}/messages/{messageId}`

## First-Time Firebase Setup Flow

1. Create/sign in a real Firebase Auth account.
2. The app auto-creates `users/{uid}` with role `user`.
3. Sign in as super admin.
4. Open Super Admin -> Users.
5. For a vendor account, either:
   - `CREATE STORE` to make a pending store and link it to that user, or
   - `LINK STORE` to attach an existing store.
6. Approve and activate the store from Super Admin -> Stores.
7. Vendor signs in again and gets isolated access to only that store.

## Firebase OTP Test Numbers

Use Firebase Authentication test phone numbers during development so you can
verify OTP flows without hitting SMS rate limits.

Recommended setup:

1. Open Firebase Console.
2. Go to Authentication.
3. Open the Sign-in method tab.
4. Scroll to Phone numbers for testing.
5. Add phone numbers and fixed OTP codes.

Suggested role test mapping:

- Customer app test number -> Firestore role `user`
- Vendor ops test number -> Firestore role `vendor`
- Rider ops test number -> Firestore role `rider`
- Admin web panel test number -> Firestore role `admin` or `super_admin`

Recommended workflow:

1. Add the test number in Firebase Authentication.
2. Sign in once with OTP.
3. Let the app create the default `users/{uid}` record.
4. Update the Firestore `role` field as needed:
   - `user`
   - `vendor`
   - `rider`
   - `admin`
   - `super_admin`
5. For vendors, also assign `storeId`.
6. Sign out and sign in again to pick up the updated role.

Important:

- Test phone numbers only work in development/test flows.
- Real production users still use live OTP.
- OTP requests on real numbers are rate-limited by Firebase, so repeated rapid tests should use test numbers instead.

## Important Notes

- Firestore rules are defined in `firestore.rules` and should be deployed.
- iOS still needs `ios/GoogleService-Info.plist`.
- Real admin/vendor auth accounts must still be created in Firebase Auth or by users signing up themselves.
