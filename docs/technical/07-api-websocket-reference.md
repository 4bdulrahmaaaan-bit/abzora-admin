# 7. API and WebSocket Reference

## Auth Requirements Model

- Public: select roots/health and webhook ingress routes.
- Authenticated: most commerce/user/vendor/rider operations.
- Admin-authenticated: `/admin/*`, selected metrics/ops endpoints.

## Major REST Endpoints

### Core

- `GET /health`, `GET /health/live`, `GET /health/ready`
- `GET /` (service index)

### Auth

- `POST /auth/test-user`
- `GET /auth/me`
- `POST /auth/sync-profile`
- Address, memory, profile, measurement, referral, growth-offer endpoints under `/auth/*`

### Commerce / Orders / Payments

- `POST /orders`
- `POST /orders/quick-checkout`
- `POST /orders/quote`
- `POST /orders/create-razorpay-order`
- `POST /orders/verify-payment`
- `POST /payment/create-order`
- `POST /payment/verify`
- Refund/return lifecycle endpoints under `/orders/*refund*` and `/orders/*return*`

### Catalog / Store / User Domains

- `/products`, `/stores`, `/wishlist`, `/cards`, `/user`, `/reviews`, `/bookings`, `/trial-home`, `/wardrobe`

### Operations / Admin

- `/admin/dashboard`
- `/admin/users`, `/admin/stores`, `/admin/products`, `/admin/orders`
- `/admin/finance*`, `/admin/pricing*`
- `/admin/kyc/vendors`, `/admin/kyc/riders`
- `/admin/outbox/dead-letter/:eventId/replay`
- `/ops/*`, `/dispatch/*`, `/tracking/*`, `/fleet/*`

### Webhooks

- `POST /webhooks/razorpay`
- `POST /webhooks/razorpayx`

## Request/Response Summary Pattern

- Success responses generally return JSON with either top-level payload or `data` envelope.
- Failures return JSON error with status and message.
- Some protected metrics/ops endpoints require admin auth and role checks.

## WebSocket Event Summary

### `/tracking/ws`

Auth and session:
- Bearer token required in `Authorization` header.
- Connection ack emits `eventType: connected` with subscribed rooms.

Client commands:
- `{"action":"join","room":"order:<id>"}`
- `{"action":"leave","room":"order:<id>"}`

Server events:
- `connected`
- `join_denied`
- tracking payloads with `namespace`, `eventType`, entity ids, `data`, timestamp, trace metadata

### `/ws/pricing`

- Admin-only.
- Initial event includes `eventType: pricing_config_snapshot`.
- Subsequent pricing updates are pushed from internal pricing event bus.

## Notes on Full OpenAPI Coverage

- Full endpoint schema typing (all request/response fields) is not maintained as a single OpenAPI file in the scanned repository.
- Validation schemas are distributed in `backend/validation/schemas/*` and should be treated as source of truth for payload contracts.
