# Operations Documentation

## Deployment Process

1. Build/release artifacts via repository release scripts.
2. Apply desired overlay with kustomize.
3. Verify readiness and health endpoints before traffic cutover.

## Rollback Procedure

- Reapply prior stable image tags/manifests.
- Confirm readiness recovers and queue/dead-letter signals stabilize.

## Restore Drills

Use backend runbooks and ops templates for periodic restore validation, including:
- payment data integrity checks
- outbox replay validation
- webhook ingest replay validation

## Alerting Strategy

- Ingress alert rules (5xx rate, latency, websocket churn)
- Queue health saturation/retry/lag indicators
- Readiness and subsystem health surfaces

## Observability Stack

- OpenTelemetry traces
- Structured JSON logs
- Internal telemetry and worker metrics endpoints
- Ingress ServiceMonitor + PrometheusRule manifests

## Health Endpoints

- `/health`
- `/health/live`
- `/health/ready`
- `/health/outbox-worker`
- `/health/webhook-ingest`

## Metrics Endpoints

- `/metrics/telemetry`
- `/metrics/outbox`
- `/metrics/webhook-ingest`

## Incident Runbooks

- `backend/docs/INCIDENT_RUNBOOKS.md`
- `backend/docs/BACKUP_RESTORE_RUNBOOK.md`
- `backend/docs/RESTORE_DRILL_RUNBOOK.md`
- `backend/docs/DR_POLICY.md`

## Operational Notes

- Redis warmup is async; readiness gating is the admission guard.
- Worker/websocket behavior differs by deployment role through env toggles.
- Graceful shutdown is explicitly time-bounded.
