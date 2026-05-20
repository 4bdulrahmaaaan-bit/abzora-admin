# API Documentation Summary

## Auth Requirements

- Public: health/root plus webhook ingress
- Auth-required: most domain APIs
- Admin-auth-required: `/admin/*` and selected ops/metrics

## Major Endpoints

### Core Health and Service

- `GET /`
- `GET /health`
- `GET /health/live`
- `GET /health/ready`

### Auth Domain

- `/auth/me`, `/auth/profile`, `/auth/sync-profile`
- address/memory/body-profile/measurement/referral/growth-offer paths under `/auth/*`

### Orders and Payments

- `/orders` (create, list, updates)
- `/orders/create-razorpay-order`
- `/orders/verify-payment`
- `/payment/create-order`
- `/payment/verify`
- refund/return lifecycle paths under `/orders/*`

### Admin and Ops

- `/admin/dashboard`
- `/admin/users|stores|products|orders`
- `/admin/finance*`, `/admin/pricing*`
- `/admin/kyc/vendors`, `/admin/kyc/riders`
- `/admin/outbox/dead-letter/:eventId/replay`
- `/ops/*`, `/dispatch/*`, `/tracking/*`, `/fleet/*`

### Webhooks

- `POST /webhooks/razorpay`
- `POST /webhooks/razorpayx`

## Request / Response Pattern

- JSON responses with either top-level payload or `data` field
- Error responses with status + message

## WebSocket Events

### Tracking WebSocket `/tracking/ws`

- bearer-header auth required
- join/leave room commands
- connected, join_denied, and tracking event payloads

### Pricing WebSocket `/ws/pricing`

- admin-only
- emits pricing config snapshot and event bus updates

## Contract Source

Validation contracts are distributed in `backend/validation/schemas/*`.
A single consolidated OpenAPI document was not identified in the scanned repository.
