# 3. Backend Architecture

## API Architecture

- Runtime: Node.js >=20, Express 4.
- Entry point: `backend/server.js`.
- Layering:
  - `routes/*` for API surface
  - `controllers/*` for request orchestration
  - `services/*` for domain logic, integrations, queueing, telemetry
  - `models/*` for Mongo persistence
  - `middleware/*` for auth, authorization, security/rate limiting

## Auth System

- Auth middleware verifies Firebase ID tokens.
- Authorization middleware enforces role-based access (`admin`, `super_admin`, `vendor`, `rider`).
- Route protection is explicit per route group (`/admin`, `/vendor`, `/rider`, `/ops`, etc.).

## Payment Lifecycle

Implemented payment flow:
1. Client requests Razorpay order creation (`/orders/create-razorpay-order` or `/payment/create-order`).
2. Client completes gateway checkout.
3. Backend verifies payment signature (`/orders/verify-payment` and `/payment/verify`).
4. Webhook path ingests async gateway events (`/webhooks/razorpay`, `/webhooks/razorpayx`).
5. Durable side effects are replayed through outbox worker and webhook ingest worker.

## Order Lifecycle

- Order creation, quoting, status transitions, cancellation, delivery acceptance, rider updates, invoice download, refund and return requests are implemented in `orderRoutes` and `orderController`.
- Rider and vendor order views are role-scoped endpoints.

## Redis Architecture

Redis usage domains:
- Distributed rate limiter backend
- Ops queue backend
- Ops lock backend
- Cache backend
- Tracking websocket pub/sub fanout

Runtime behavior:
- In production, readiness can fail-closed if Redis is required and unhealthy.
- Some paths support memory fallback based on redis runtime config policy; security-critical paths can reject when Redis unavailable.

## Queue Architecture

- Ops queue service implements severity-prioritized queues, retry queues, backlog telemetry, and saturation controls.
- Admission control preserves critical payment/order job classes under overload.
- Retry scheduling with jitter/backoff and promotion loops are implemented.

## Outbox Replay System

- `paymentOutboxWorker` claims events with leases, heartbeats, retry scheduling, dead-lettering, cleanup, and metrics.
- Side effects include transaction/audit/analytics/admin-notification pathways with duplicate guards.
- Admin dead-letter replay endpoint exists: `/admin/outbox/dead-letter/:eventId/replay`.

## Webhook Ingest Pipeline

- Raw-body webhook ingress is configured for Razorpay/RazorpayX endpoints.
- `paymentWebhookIngestService` persists events, claims with lease, processes with configurable concurrency, retries with backoff, dead-letters on exhaustion, and cleans processed events after retention.

## Websocket Architecture

### Tracking Gateway (`/tracking/ws`)

- Auth: bearer token only (query token intentionally rejected).
- Room model: `order:*`, `rider:*`, `user:*`, `task:*`, `zone:*`.
- Access checks map room joins to authenticated role/entity ownership.
- Event publish path supports Redis pub/sub fanout; optional local fallback.

### Pricing Gateway (`/ws/pricing`)

- Admin-only websocket stream.
- Emits pricing config snapshot and pricing event bus updates.

## OTEL Observability and Tracing

- OTEL bootstrap is optional via env (`OTEL_ENABLED`).
- Instrumentations include HTTP, Express, MongoDB, Redis.
- Exporters: OTLP HTTP or gRPC; console fallback in non-production.
- Sampling: parent-based with trace-id ratio sampler.
- Health is exposed through `/metrics/telemetry` and `/health/ready` telemetry block.

## Structured Logging

- JSON logger with context propagation fields (`requestId`, `traceId`, `spanId`, `workerId`, `operation`).
- Sensitive key redaction includes authorization/token/password/secret/signature families.
- Truncation and max depth/key guards prevent unbounded payload logging.

## Metrics and Health Systems

Implemented health endpoints:
- `/health`
- `/health/live`
- `/health/ready`
- `/health/outbox-worker` (admin-auth)
- `/health/webhook-ingest` (admin-auth)

Implemented metric endpoints:
- `/metrics/outbox`
- `/metrics/webhook-ingest`
- `/metrics/telemetry`

## Worker Systems

- Payment outbox worker
- Payment webhook ingest worker
- Dispatch scheduler service
- Finance cron service
- Ops runtime loops

## Retry / Dead-letter Behavior

- Outbox and webhook ingest workers implement:
  - attempt counting
  - lease/heartbeat lock management
  - exponential backoff with jitter
  - dead-letter transition after max attempts
  - periodic cleanup retention jobs

## Graceful Shutdown Behavior

On SIGTERM/SIGINT:
- Mark shutdown state for readiness failure.
- Close HTTP server.
- Stop outbox/webhook workers and websocket gateways.
- Stop schedulers/crons/runtime loops.
- Close redis subsystems and telemetry SDK.
- Close Mongo connection.
- Force-exit timeout default: 30s (`GRACEFUL_SHUTDOWN_TIMEOUT_MS`).

## Scaling Strategy

- Horizontal scaling is handled by K8s HPA and split deployment responsibilities.
- Websocket fanout continuity is decoupled from sticky sessions via Redis pub/sub + token-based authorization.
- Queue and worker concurrency are configurable by environment.
