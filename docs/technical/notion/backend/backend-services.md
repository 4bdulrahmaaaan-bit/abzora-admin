# Backend Services Architecture

## API Layer

- Runtime: Node.js + Express (`backend/server.js`)
- Route modules under `backend/routes/*`
- Controllers under `backend/controllers/*`
- Domain services under `backend/services/*`
- Persistence models under `backend/models/*`

## Auth and Role Enforcement

- Firebase token verification middleware
- Role middleware for `admin`, `super_admin`, `vendor`, `rider`
- Protected domains include admin, ops, finance, payout, and role-bound operations

## Payment Lifecycle

1. Payment order creation endpoints (`/orders/create-razorpay-order`, `/payment/create-order`)
2. Signature verification endpoints (`/orders/verify-payment`, `/payment/verify`)
3. Webhook ingest endpoints (`/webhooks/razorpay`, `/webhooks/razorpayx`)
4. Durable side effects via outbox worker and ingest worker

## Order Lifecycle

- Order create, quote, quick-checkout, cancellation
- Delivery lifecycle state updates
- Refund and return request lifecycle endpoints
- Invoice and custom alteration/fit paths

## Redis Subsystem Architecture

Used for:
- rate limiter backing store
- queueing and retry queues
- lock service
- cache service
- websocket event fanout

Readiness dependency checks include redis-health gating in production-required mode.

## Queue Architecture

- Severity-tiered queues with retry zsets and promotion ticks
- Admission control to protect critical payment/order job classes
- Saturation, lag, and retry backlog telemetry emitted for operations

## Outbox Replay System

- Lease-based event claim, heartbeat renewal, retry scheduling, dead-letter transitions
- Side effect replay includes finance audits, notifications, analytics and related pathways
- Admin dead-letter replay endpoint exists for controlled manual remediation

## Webhook Ingest Pipeline

- Persist webhook ingest event
- claim/process with lease + heartbeat
- configurable concurrency
- retry backoff + dead-letter after max attempts
- retention cleanup for processed events

## Websocket Architecture

### Tracking Gateway (`/tracking/ws`)

- Bearer-header auth only
- Room ACL enforcement by entity ownership + role
- Redis pub/sub fanout with optional local fallback behavior

### Pricing Gateway (`/ws/pricing`)

- Admin-only connection acceptance
- Pricing config snapshot + broadcast updates

## OTEL and Structured Logging

- OpenTelemetry bootstrap via env controls
- Instrumentations: HTTP, Express, MongoDB, Redis
- OTLP exporter (HTTP/gRPC) with console path for non-prod fallback
- Structured logger with context correlation and sensitive-field redaction

## Metrics and Health Endpoints

- `/health`, `/health/live`, `/health/ready`
- `/health/outbox-worker`, `/metrics/outbox`
- `/health/webhook-ingest`, `/metrics/webhook-ingest`
- `/metrics/telemetry`

## Worker and Scheduler Systems

- payment outbox worker
- payment webhook ingest worker
- dispatch scheduler
- finance cron service
- ops runtime service

## Retry / Dead-letter Behavior

Both outbox and ingest workers implement:
- bounded attempts
- exponential backoff with jitter
- dead-lettering after exhaustion
- lock-loss handling and retry safety

## Graceful Shutdown

Signal handling performs:
- ingress drain
- worker and scheduler stop
- redis subsystem close
- telemetry shutdown
- DB close
- hard timeout fail-safe

## Scaling Strategy

- Horizontal scaling through K8s HPA and role-separated deployments
- Websocket scaling without sticky sessions by using auth + Redis fanout
- Worker concurrency tunable by env
