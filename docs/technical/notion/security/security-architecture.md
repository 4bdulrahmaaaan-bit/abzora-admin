# Security Documentation

## Authentication Protections

- Firebase ID token enforcement on protected backend routes
- Role-based access controls in HTTP and websocket domains
- Client-side session expiry recovery and forced re-auth behavior

## RBAC

- Route-level role guards for admin/vendor/rider
- Websocket room join authorization by role + entity ownership checks

## Payment Hardening

- Payment route rate limits
- Signature verification path
- Durable async event processing (ingest + outbox)

## Redis Fail-Closed Behavior

- Production readiness can fail if required redis subsystems are not healthy
- Queue subsystems can reject protected operations when redis backend is required but unavailable

## Upload Protections

- Upload route-specific throttling
- Signed upload endpoint support and explicit config gating for insecure unsigned fallback

## Websocket Security

- Query token auth is explicitly blocked in gateway code
- Bearer-header token required
- Unauthorized room join attempts are denied

## Secret Handling

- K8s uses `secretRef` for application secret injection
- template secret file exists for secure external population

## Tracing and Logging Redaction

- Structured logger redacts sensitive fields (auth, token, secret, password, signature)
- Logging guards for depth, key count, and payload length

## Additional Hardening Controls

- HTTPS enforcement middleware
- Security headers middleware
- Path/actor-aware rate limiters
- Stricter admin ingress source restrictions and limits
