# 5. Security Architecture

## Auth Protections

- Firebase ID token verification on backend authenticated routes.
- Mode-aware frontend access restrictions for customer/vendor/rider/app roles.
- Automatic unauthorized-session recovery and forced re-auth in client state management.

## RBAC

- Server-side role checks using explicit middleware for admin/vendor/rider endpoints.
- Websocket room join authorization validates room/entity ownership and role access before subscription.

## Payment Hardening

- Payment endpoints are rate-limited.
- Gateway callback handling separated from direct checkout path.
- Signature verification endpoint is enforced in frontend verified path.
- Durable event processing (outbox/webhook ingest) reduces lost side effects across crashes.

## Redis Fail-Closed Behavior

- Readiness can fail when Redis-required mode is active and redis subsystems are unhealthy.
- Certain queue operations reject with explicit `redis_required_unavailable` state under required policies.

## Upload Protections

- Upload route is rate-limited.
- Cloudinary signed upload endpoint configuration exists; unsigned fallback is explicit and gated by config.

## Websocket Security

- Query-string token authentication is intentionally blocked in backend websocket gateways.
- Bearer token in Authorization header is the accepted auth channel.
- Role-based room access checks are enforced server-side.

## Secret Handling

- K8s manifests use `secretRef` for app secrets.
- `secret-template.yaml` exists as placeholder and warns not to commit real values.

## Tracing/Logging Redaction

- Structured logger redacts sensitive keys (`authorization`, `token`, `password`, `secret`, `signature`, etc.).
- Push token logging is explicitly avoided in notification service comments and behavior.

## Additional Security Controls Implemented

- HTTP security headers middleware.
- HTTPS enforcement middleware.
- Per-domain/per-path rate limiters with IP and actor-aware keying.
- Admin ingress source-range restriction and stricter ingress throttling.
