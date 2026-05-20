# 2. Frontend Architecture

## Shared Frontend Foundation

### Architecture Overview

- Core shell is `lib/app_shell.dart` for customer/vendor/unified app modes.
- Rider has dedicated app composition in `lib/rider_app.dart` + `lib/routes/rider_router.dart`.
- Runtime mode behavior is controlled through `AbzioAppMode` and route-access logic in `lib/utils/app_mode_routes.dart`.

### Folder Structure

- `lib/screens/user|vendor|rider|admin`: role-specific presentation layers.
- `lib/services`: API clients, auth, payments, storage, chat, notifications, AR orchestration.
- `lib/providers`: state and session orchestration (primarily Provider, plus Riverpod usage in rider flow).
- `lib/core`: rider-focused service/theme utilities.

### State Management

Implemented patterns:
- `provider` (`ChangeNotifier`, `MultiProvider`, `ChangeNotifierProxyProvider`) for auth/cart/product/wishlist/theme and shared app state.
- `flutter_riverpod` is used in rider onboarding/provider slices.
- Auth state hydration and live updates are centralized in `AuthProvider`.

### Routing / Navigation

- Customer/vendor/unified flows use `Navigator`-based named routes in app shell.
- Rider flow uses GoRouter route declarations (`lib/routes/rider_routes.dart`, `lib/routes/rider_router.dart`) plus imperative navigation in some screens.
- Mode and role gating is enforced at route decision points (`routeForUserInMode`, restriction messaging).

## Customer App

### Authentication Flow

- OTP and Google sign-in are exposed through `AuthProvider` + `AuthService`.
- Session token refresh is proactive; repeated unauthorized responses trigger recovery and eventual forced logout.
- Customer mode allows shop-first route behavior (`/shop`) with soft-auth gates for protected actions.

### API Integrations

- Primary HTTP abstraction: `BackendApiClient`.
- Notable behavior: DNS/transient fallback to alternate Render origin, retry/backoff, structured error normalization, unauthorized callback integration.
- Data domains include auth/profile, products, stores, orders, wishlist, cards, trial-home, support/chat.

### Payment Flows

- `PaymentService` integrates `razorpay_flutter` checkout.
- Checkout flow:
  1. Create backend order (`/orders/create-razorpay-order`) when backend order id exists.
  2. Launch Razorpay checkout.
  3. Verify signature via backend (`/orders/verify-payment`) for non-wallet success path.
- Card vaulting flow exists with setup/finalize endpoints from environment config.

### Realtime Updates / Websocket Usage

- Customer realtime tracking path is backend websocket (`/tracking/ws`) via backend events.
- Additional app-local realtime sources use Firebase Realtime Database listeners in data services/providers.

### Push Notification Flow

- FCM setup in `NotificationService`.
- Token sync is persisted to database and refreshed on token rotation.
- Role-derived topic subscriptions are implemented (admin/store/rider topic patterns).

### Environment Configuration

- Compile-time config in `AppConfig` (`String.fromEnvironment`) for backend URL, Razorpay, Firebase emulator toggles, Cloudinary, maps, TTS/avatar endpoints.

### Responsive / Mobile Handling

- Flutter responsive behavior is screen/widget-driven; no separate web-only customer frontend stack is implemented.

### Security Protections

- Sensitive token values are intentionally not printed in logs.
- Unauthorized session handling in `BackendApiClient` + `AuthProvider` avoids stale token loops.

### Error Handling Strategy

- Backend request parsing explicitly validates JSON response shape.
- Typed `BackendApiException` with status-aware behaviors.
- Offline/backend availability notifier for UX fallback signaling.

### Performance Optimizations

- Retry + exponential backoff for transient network failures.
- Preferred-base-url caching after successful DNS fallback.
- Local cache usage and incremental provider updates for session/UI responsiveness.

## Vendor App

### Architecture Overview

- Vendor entrypoint: `main_vendor.dart` -> `bootstrapAndRun(AbzioAppMode.vendor)`.
- Vendor UX implemented in `lib/screens/vendor/*` with onboarding, product management, order handling, pricing, store settings.

### Auth and Access

- Vendor mode access validated via `hasVendorOperationsAccess` (role map and/or store association).
- Non-authorized users are restricted with explicit mode-specific messages.

### API / Payment / Realtime

- Uses shared `BackendApiClient` and auth token pipeline.
- Vendor payout/finance and order-state interactions are backend-driven.
- Realtime order/tracking events are via tracking websocket gateway and backend update channels.

## Rider App

### Architecture Overview

- Rider entrypoint: `main_rider.dart` (Firebase init + ProviderScope + dedicated rider app).
- Rider features are segmented in `lib/features/*` with dedicated dashboard, orders, live tracking, earnings, onboarding.

### State and Routing

- Mixed Provider + Riverpod usage.
- GoRouter used for rider route graph.

### Websocket Usage

- `RiderSocketService` uses `web_socket_channel`.
- Auth is bearer token based (header for IO channel; token query for web channel compatibility path).
- Supports reconnect loop and emits order/status/location events.

### API Integrations

- `RiderApiService` (`dio`) targets rider delivery endpoints and ETA/location/status APIs.

### Realtime / Push

- Combined websocket + API sync for delivery operations.
- Role-topic subscription for rider notifications in `NotificationService`.

## Admin Web Panel

### Architecture Overview

- Admin entrypoint: `main_admin.dart` with initial route `/admin-login`.
- Admin panel UI is implemented in Flutter (`lib/screens/admin/*`) and runs on web deployment target.

### Backend Integration

- Admin operations route through secured `/admin/*` APIs.
- Includes dashboard, finance/payout, pricing config, KYC, disputes, notifications, trial-home, and outbox dead-letter replay actions.

### Security Posture

- Admin API access requires authenticated admin role server-side.
- Ingress layer adds source-range constraints for admin host in K8s manifests.

## Requested Items With No Clear Frontend Implementation in Current Code

- Dedicated standalone React/Next admin frontend was not found; admin panel is Flutter-based.
- A separate frontend-specific websocket client for pricing admin stream was not clearly surfaced in scanned files, though backend `/ws/pricing` gateway is implemented.
