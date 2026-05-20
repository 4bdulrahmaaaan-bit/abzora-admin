# 6. Operations Runbook

## Deployment Process

1. Build and publish backend/admin artifacts (release scripts present in `scripts/`).
2. Apply K8s overlay:
   - staging: `kustomize build deploy/k8s/overlays/staging | kubectl apply -f -`
   - prod: `kustomize build deploy/k8s/overlays/prod | kubectl apply -f -`
3. Observe readiness probes and health endpoints before opening traffic.

## Rollback Procedure

- Roll back by applying previous known-good image tags and/or previous kustomize state.
- Ensure `/health/ready` returns healthy dependency checks after rollback.
- Validate worker queue/dead-letter growth is not regressing post-rollback.

## Restore Drills

- Use backend runbooks and drill templates in `backend/docs/` and `backend/ops/backup`.
- Validate:
  - payment integrity checks
  - outbox replay validation
  - webhook ingest replay validation

## Alerting Strategy

Implemented alert sources:
- Ingress observability rules (`deploy/k8s/base/ingress-observability.yaml`) for 5xx rate, p95 latency, websocket churn.
- Queue saturation/retry/lag warnings exposed by ops queue health service.
- Health endpoints provide dependency-specific degradation signals.

## Observability Stack

- OpenTelemetry (optional by env) + exporter selection.
- Structured JSON logs with trace correlation fields.
- Internal telemetry metrics endpoint (`/metrics/telemetry`).
- Ingress ServiceMonitor + PrometheusRule manifests.

## Health Endpoints

- `/health`
- `/health/live`
- `/health/ready`
- `/health/outbox-worker` (admin auth required)
- `/health/webhook-ingest` (admin auth required)

## Metrics Endpoints

- `/metrics/telemetry`
- `/metrics/outbox`
- `/metrics/webhook-ingest`

## Incident Runbooks

Repository includes:
- `backend/docs/INCIDENT_RUNBOOKS.md`
- `backend/docs/BACKUP_RESTORE_RUNBOOK.md`
- `backend/docs/RESTORE_DRILL_RUNBOOK.md`
- `backend/docs/DR_POLICY.md`

## Operational Notes

- Redis warm-up is asynchronous; readiness is the traffic gate.
- Websocket and worker behavior differ by deployment role (`abzora-api` vs `abzora-websocket` vs `abzora-worker`) through env toggles.
- Graceful shutdown is explicit and time-bounded to prevent hanging pod terminations.
