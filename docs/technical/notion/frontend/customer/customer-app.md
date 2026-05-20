# Customer App Architecture

## Overview

Entrypoint: `lib/main_customer.dart`.

The customer app runs through shared shell/bootstrap and uses provider-based state orchestration for session, cart, product, wishlist, network, location, and theme.

## Folder Structure (Customer-Relevant)

- `lib/screens/user/*`
- `lib/providers/auth_provider.dart`, `cart_provider.dart`, `product_provider.dart`, `wishlist_provider.dart`
- `lib/services/payment_service.dart`, `backend_api_client.dart`, `notification_service.dart`, `trial_home_api.dart`

## State Management

- `MultiProvider` + `ChangeNotifier`
- Proxy providers for auth-linked cart and wishlist behavior
- Auth session lifecycle and token refresh in `AuthProvider`

## Routing / Navigation

- Named route navigation in `app_shell.dart`
- Customer default route resolution through mode/role helpers in `lib/utils/app_mode_routes.dart`

## Authentication Flow

- OTP and Google sign-in through `AuthService`/`AuthProvider`
- Firebase ID token refresh and backend session sync
- Unauthorized backend callback triggers token refresh and fail-safe logout when needed

## API Integrations

- `BackendApiClient` for authenticated and unauthenticated API calls
- DNS/transient-failure fallback to alternate backend origin
- Retry/backoff behavior for transient network failures

## Payment Flows

- Razorpay checkout in `PaymentService`
- Optional backend order pre-creation
- Post-checkout backend signature verification (`/orders/verify-payment`)
- Card tokenization flow supported when vaulting endpoints are configured

## Realtime Updates

- Tracking updates flow through backend websocket gateway events
- Additional live data sources are Firebase-backed in service/provider layers

## Push Notifications

- FCM permission + token acquisition
- Token persistence and sync per signed-in user
- Topic subscription path based on role/store/rider identity

## Environment Configuration

- Compile-time env via `AppConfig` (`String.fromEnvironment`)
- Includes backend URL, Firebase toggles, Razorpay, Cloudinary, maps, and other service endpoints

## Security Protections

- Session-expiry handling and forced re-auth safeguards
- Sensitive-token logging avoidance in notification pipeline

## Error Handling Strategy

- Typed backend exceptions with status code semantics
- Non-JSON/invalid JSON backend response protections
- Backend availability notifier for degraded UX signaling

## Performance Optimizations

- Request retry with exponential backoff
- Preferred backend origin caching after successful fallback
- Provider-scoped updates to reduce unnecessary redraw churn
