# 4. Infrastructure and Deployment

## Kubernetes Topology

Base namespace: `abianzo`.

Workloads:
- `Deployment/abianzo-api`
- `Deployment/abianzo-websocket`
- `Deployment/abianzo-worker`
- `StatefulSet/redis`

Services:
- `Service/abianzo-api`
- `Service/abianzo-websocket`
- `Service/abianzo-admin`
- `Service/redis`

## Ingress and Load Balancing

Ingress split by traffic class:
- API ingress
- Websocket ingress
- Admin ingress
- Webhook ingress

Nginx annotations implement:
- SSL redirect
- request and connection rate limiting
- timeout and body-size controls
- least-connection balancing
- websocket upgrade handling
- hardened headers and timeout tuning for slowloris mitigation

## Redis Setup

- Single-node Redis `StatefulSet` (`replicas: 1`).
- AOF enabled (`--appendonly yes`) with snapshot parameters.
- PVC-backed data volume (`10Gi`, `ReadWriteOnce`).
- Readiness/liveness via TCP probe.

Note: HA Redis (sentinel/cluster/multi-primary failover) is not implemented in current manifests.

## Mongo Setup

- MongoDB is externally referenced through environment/config; no Mongo StatefulSet/Deployment exists in current `deploy/k8s/base`.
- `mongo-config.yaml` provides app-side Mongo runtime config via ConfigMap.

## Autoscaling Strategy

- HPA v2 configured for API, websocket, and worker deployments.
- CPU/memory utilization targets plus pod custom metrics:
  - `http_request_latency_p95_ms` (API)
  - `queue_lag_seconds` (Worker)

## Readiness / Liveness Architecture

- API, websocket, worker pods use HTTP probes:
  - readiness -> `/health/ready`
  - liveness -> `/health/live`
- Backend readiness logic validates dependent subsystem health (Mongo + Redis runtime conditions), not process uptime alone.

## CI/CD Flows

- Repository includes release scripts (`scripts/release_backend.mjs`, `scripts/release_admin_next.mjs`, `scripts/release_all.mjs`) and k8s overlays (`staging`, `prod`).
- Full pipeline orchestrator definition (e.g., GitHub Actions deploy workflow internals) was not fully enumerated in this scan.

## DR / Backup Systems

Implemented artifacts:
- `backend/docs/BACKUP_RESTORE_RUNBOOK.md`
- `backend/docs/DR_POLICY.md`
- `backend/docs/RESTORE_DRILL_RUNBOOK.md`
- backup readiness verification script in backend package scripts

## Failover Behavior

Implemented behavior:
- App-level fail-closed readiness for critical dependency loss.
- Client-side backend DNS fallback for custom-domain resolution issues.
- Worker retry/dead-letter handling for event durability.

Not implemented in manifests:
- Multi-node Redis failover topology.
- Kubernetes-native Mongo failover resources in this repo.
