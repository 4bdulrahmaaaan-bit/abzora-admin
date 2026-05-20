# Infrastructure and Deployment

## Kubernetes Topology

Resources in `deploy/k8s/base` define:
- API, websocket, and worker deployments
- Redis statefulset
- Services, ingress, HPA, PDB, configmaps, and secret template

Overlays:
- `deploy/k8s/overlays/staging`
- `deploy/k8s/overlays/prod`

## Ingress and Load Balancing

Ingress objects are split by traffic type:
- API
- websocket
- admin
- webhook

Implemented ingress controls:
- SSL redirect
- rate and burst limits
- connection limits
- body-size and timeout tuning
- least-conn balancing
- websocket upgrade handling

## Redis Setup

- `StatefulSet/redis` with `replicas: 1`
- AOF enabled
- PVC-backed storage
- tcp liveness/readiness probes

## Mongo Setup

- Mongo infrastructure is external to manifests in this repo.
- App-side mongo runtime config is provided via config/env.

## Autoscaling

HPA v2 configured for:
- API
- websocket
- worker

Signals include:
- CPU and memory utilization
- custom pod metrics (`http_request_latency_p95_ms`, `queue_lag_seconds`)

## Readiness / Liveness

Deployments probe:
- readiness: `/health/ready`
- liveness: `/health/live`

Backend readiness checks dependency state (mongo and redis runtime status), not just process reachability.

## CI/CD and Release Flows

Repository includes release scripts for backend/admin and aggregate release orchestration.

## DR / Backup

Operational documents present in `backend/docs/`:
- DR policy
- backup/restore runbook
- restore drill runbook
- incident runbooks

## Failover Behavior

Implemented:
- app-level readiness fail-closed dependency logic
- retry/dead-letter durability in workers
- client-side backend DNS fallback path

Not found in current manifests:
- redis sentinel/cluster high-availability deployment
- in-repo mongo clustered/failover deployment resources
