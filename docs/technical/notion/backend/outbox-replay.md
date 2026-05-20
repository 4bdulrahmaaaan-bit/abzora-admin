# Outbox Replay System

Outbox worker (`paymentOutboxWorker`):
- Lease-based event claim
- Heartbeat lock renewal
- Retry with exponential backoff + jitter
- Dead-letter after max attempts
- Retention cleanup for processed records

Purpose:
- Recover and replay side effects after crashes/restarts
- Preserve cross-service consistency for payment-related side effects

Ops control:
- Admin dead-letter replay endpoint available for manual remediation.
