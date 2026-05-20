# Webhook Ingest Pipeline

Pipeline stages:
1. Receive webhook on raw-body endpoints
2. Persist ingest event
3. Worker claim with lease and heartbeat
4. Process by event type
5. Mark processed or schedule retry
6. Dead-letter on attempt exhaustion
7. Retention cleanup for processed events

Worker behavior:
- Configurable batch size, concurrency, polling interval, lease duration
- Metrics for processed/retry/dead-letter/lag signals
