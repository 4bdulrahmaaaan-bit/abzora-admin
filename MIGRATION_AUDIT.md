# Migration Audit

Last updated: 2026-03-30

This audit reflects the current codebase state in the Flutter app and backend repos.

## Status Legend

- `Fully backend`: primary production path is the Node/Express backend
- `Mixed`: some flows use backend, but other reads/writes still use Firebase/RTDB/local paths
- `Still RTDB`: feature still depends mainly on Firebase/RTDB paths

## Admin

### Fully backend

- Admin auth/profile bootstrap through `/auth/me`
- Admin users list
- Admin stores/vendors list
- Admin products list
- Admin orders list
- Admin dashboard analytics
- Vendor KYC review
- Rider KYC review
- Support conversations/messages

### Mixed

- Admin web panel
  - backend-safe sections are wired
  - unsupported sections are hidden or softened in backend mode
- Admin settings
- Admin notifications
- Admin payouts
- Admin disputes
- Admin activity logs
  - backend endpoints and service hooks are now added
  - final production state depends on latest frontend and backend commits being pushed and redeployed

### Still RTDB

- None of the major visible admin tabs should remain intentionally RTDB-only after the latest local migration patches
- some older utility/admin mutation paths may still exist in `DatabaseService` and should be treated as legacy until verified in production

## Customer

### Fully backend

- Customer profile bootstrap from backend
- Product catalog
- Store listing
- User orders
- Core commerce/order API access

### Mixed

- User profile sync
- Wishlist/cart/support related app flows
- Some screen-level data loading that still routes through `DatabaseService`
- Chat/history-related flows

### Still RTDB

- User addresses
- User memory storage
- Some chat history persistence/fallback paths

## Vendor

### Fully backend

- Vendor-facing store orders
- Vendor KYC submission/review pipeline support on backend-connected paths

### Mixed

- Store management flows
- Product management flows
- Vendor dashboard/supporting summary data
- Some vendor notifications and operational actions

### Still RTDB

- Any vendor feature still calling legacy `DatabaseService` Firebase collection methods without a backend shortcut

## Rider

### Fully backend

- Available deliveries
- Assigned deliveries
- Rider KYC review/admin pipeline

### Mixed

- Rider dashboard/state aggregation
- Rider support/operational utility flows

### Still RTDB

- Any rider-only utility flow that still depends on legacy `DatabaseService` reads/writes outside delivery APIs

## Known RTDB-Backed Examples Remaining

- `saveUserAddress`
- `deleteUserAddress`
- `getUserAddresses`
- `saveUserMemory`
- RTDB chat/history persistence helpers
- legacy fallback methods in `DatabaseService` when backend coverage is missing

## What Must Be Pushed Before Re-Auditing

### Frontend repo

- `lib/services/database_service.dart`
- `lib/services/backend_commerce_service.dart`
- `lib/screens/admin/admin_web_panel.dart`
- any still-local auth/admin web files already changed in this session

### Backend repo

- `controllers/adminController.js`
- `routes/adminRoutes.js`
- `models/AdminPlatformSettings.js`
- `models/AdminNotification.js`
- `models/AdminPayout.js`
- `models/AdminDispute.js`
- `models/AdminActivityLog.js`

## Recommended Next Migration Order

1. Finish pushing and redeploying the latest admin migration files
2. Move customer addresses off RTDB
3. Move customer memory/chat persistence off RTDB
4. Audit vendor dashboard/settings/notifications flows
5. Audit rider utility flows
6. Remove dead RTDB-only helpers after production verification
