# ABZORA Production Ops System

This backend now includes a production-hardened operations subsystem for same-day logistics reliability.

## Implemented Capabilities

- Failure handling + timeouts for vendor accept, rider accept, pickup, delivery
- Dead order/task detection with stuck marking
- Identity consistency checks (`orderId <-> taskId <-> batchId <-> riderId`)
- Duplicate task prevention + orphan task cancellation
- Alert detection/scoring/severity
- Priority queue (`CRITICAL > HIGH > MEDIUM > LOW`) using Redis queue + fallback
- Redis-compatible worker execution with retries and exponential backoff
- Entity locking during action execution
- Auto-escalation for unresolved alerts
- Auto-actions (self-healing) with detect -> act -> verify -> resolve/retry
- Admin ops control APIs for manual overrides and force actions
- Tracking hardening (movement threshold, speed validation, throttling)
- WebSocket JWT auth + role-based room access restrictions
- Ops metrics snapshots (hourly + daily)
- Simulation mode endpoint
- Alert/action audit logging

## New Models

- `models/OpsAlert.js`
- `models/OpsActionLog.js`
- `models/OpsMetricsSnapshot.js`

## New Routes

Mounted under `/ops`:

- `GET /ops/alerts`
- `POST /ops/detect`
- `POST /ops/alerts/:alertId/action`
- `POST /ops/orders/:orderId/reassign`
- `POST /ops/orders/:orderId/cancel`
- `POST /ops/dispatch/:orderId/force`
- `POST /ops/payments/:orderId/retry`
- `GET /ops/live`
- `GET /ops/metrics`
- `GET /ops/logs`
- `POST /ops/simulate`

## Runtime Services

- `services/opsRuntimeService.js`
- `services/opsWorkerService.js`
- `services/opsDetectionService.js`
- `services/opsActionService.js`
- `services/opsConsistencyService.js`
- `services/opsQueueService.js`
- `services/opsLockService.js`
- `services/opsMetricsService.js`

`startOpsRuntime()` is started from `server.js`.

## Environment Variables

- `OPS_RUNTIME_ENABLED=true|false`
- `OPS_DETECTION_INTERVAL_MS` (default 30000)
- `OPS_ESCALATION_INTERVAL_MS` (default 120000)
- `OPS_ESCALATION_THRESHOLD_MIN` (default 20)
- `OPS_DEAD_THRESHOLD_MIN` (default 35)
- `OPS_WORKER_CONCURRENCY` (default 4)
- `OPS_ACTION_MAX_RETRIES` (default 3)
- `OPS_TIMEOUT_VENDOR_ACCEPT_MIN` (default 8)
- `OPS_TIMEOUT_RIDER_ACCEPT_MIN` (default 7)
- `OPS_TIMEOUT_PICKUP_MIN` (default 25)
- `OPS_TIMEOUT_DELIVERY_MIN` (default 90)
- `TRACKING_MOVEMENT_THRESHOLD_METERS` (default 12)
- `TRACKING_MAX_SPEED_KMPH` (default 120)
- `TRACKING_THROTTLE_SECONDS` (default 4)
- `TRACKING_SNAP_TO_ROAD=true|false` (placeholder hook)

## Notes

- Redis is used when `REDIS_URL` is configured and not disabled.
- A memory fallback queue/lock path is included for resilience in local/dev.
- WebSocket clients now require Firebase bearer token via query `token` or `Authorization: Bearer <token>`.
