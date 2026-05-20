# ABZORA Documentation Coverage Audit Matrix

Audit date: 2026-05-18 (Asia/Calcutta)

Legend:
- `Covered`: documented with implemented evidence.
- `Partial`: documented, but implementation is distributed or indirect.
- `Not Found`: explicit implementation not identified in scanned repository paths.

## 1) System Overview

| Requested Item | Status | Evidence (Repository References) |
|---|---|---|
| platform architecture | Covered | `backend/server.js`, `lib/main_customer.dart`, `lib/main_vendor.dart`, `lib/main_rider.dart`, `lib/main_admin.dart`, `deploy/k8s/base/kustomization.yaml` |
| app ecosystem | Covered | `lib/screens/user/*`, `lib/screens/vendor/*`, `lib/features/dashboard/*`, `lib/screens/admin/*` |
| service interactions | Covered | `backend/server.js`, `backend/services/paymentWebhookIngestService.js`, `backend/services/paymentOutboxWorker.js`, `backend/services/trackingGateway.js` |
| deployment topology | Covered | `deploy/k8s/base/deployment-api.yaml`, `deployment-websocket.yaml`, `deployment-worker.yaml`, `redis-statefulset.yaml`, `ingress.yaml` |

## 2) Frontend Documentation (per app)

| Requested Item | Customer | Vendor | Rider | Admin Web | Evidence |
|---|---|---|---|---|---|
| architecture overview | Covered | Covered | Covered | Covered | `lib/main_*.dart`, `lib/app_shell.dart`, `lib/rider_app.dart` |
| folder structure | Covered | Covered | Covered | Covered | `lib/screens/*`, `lib/features/*`, `lib/services/*`, `lib/providers/*` |
| state management | Covered | Covered | Covered | Covered | `lib/app_shell.dart`, `lib/providers/*.dart`, `lib/providers/rider_signup_provider.dart` |
| routing/navigation | Covered | Covered | Covered | Covered | `lib/app_shell.dart`, `lib/routes/rider_router.dart`, `lib/utils/app_mode_routes.dart` |
| authentication flow | Covered | Covered | Covered | Covered | `lib/providers/auth_provider.dart`, `lib/services/auth_service.dart` |
| websocket usage | Partial | Partial | Covered | Partial | `lib/core/services/rider_socket_service.dart`, backend socket infra in `backend/services/trackingGateway.js` |
| API integrations | Covered | Covered | Covered | Covered | `lib/services/backend_api_client.dart`, `lib/core/services/rider_api_service.dart` |
| payment flows | Covered | Partial | Partial | Partial | `lib/services/payment_service.dart`, order/payment endpoints in backend |
| realtime updates | Covered | Covered | Covered | Partial | `backend/services/trackingGateway.js`, frontend provider/service subscriptions |
| push notification flow | Covered | Covered | Covered | Covered | `lib/services/notification_service.dart` |
| environment configuration | Covered | Covered | Covered | Covered | `lib/services/app_config.dart` |
| responsive/mobile handling | Partial | Partial | Partial | Partial | Flutter layout-based handling across `lib/screens/*` (no central responsive framework doc file) |
| security protections | Covered | Covered | Covered | Covered | `lib/providers/auth_provider.dart`, `lib/services/backend_api_client.dart` |
| error handling strategy | Covered | Covered | Covered | Covered | `lib/services/backend_api_client.dart`, provider/session recovery logic |
| performance optimizations | Partial | Partial | Partial | Partial | retry/backoff/fallback in `backend_api_client.dart`; feature-specific optimizations are distributed |

## 3) Backend Documentation

| Requested Item | Status | Evidence |
|---|---|---|
| API architecture | Covered | `backend/server.js`, `backend/routes/*`, `backend/controllers/*` |
| auth system | Covered | `backend/middleware/authMiddleware.js`, `authorizationMiddleware.js`, protected route mounts in `backend/server.js` |
| payment lifecycle | Covered | `backend/routes/paymentRoutes.js`, `backend/controllers/paymentController.js`, `backend/routes/webhookRoutes.js` |
| order lifecycle | Covered | `backend/routes/orderRoutes.js`, `backend/controllers/orderController.js` |
| Redis architecture | Covered | `backend/services/redisClientManager.js`, `redisRuntimeConfig.js`, `redisCacheService.js`, queue/lock/tracking services |
| queue architecture | Covered | `backend/services/opsQueueService.js` |
| outbox replay system | Covered | `backend/services/paymentOutboxWorker.js`, `backend/controllers/outboxReplayAdminController.js` |
| webhook ingest pipeline | Covered | `backend/services/paymentWebhookIngestService.js`, `backend/routes/webhookRoutes.js` |
| websocket architecture | Covered | `backend/services/trackingGateway.js`, `backend/services/pricingGateway.js` |
| OTEL observability/tracing | Covered | `backend/services/otelService.js` |
| structured logging | Covered | `backend/services/structuredLogger.js` |
| metrics/health systems | Covered | `backend/server.js` (`/health*`, `/metrics*`) |
| worker systems | Covered | outbox/ingest workers + runtime schedulers in `backend/services/*` |
| retry/dead-letter behavior | Covered | `paymentOutboxWorker.js`, `paymentWebhookIngestService.js`, `opsQueueService.js` |
| graceful shutdown behavior | Covered | `backend/server.js` (`gracefulShutdown`) |
| scaling strategy | Covered | split workloads + HPA + websocket redis fanout (`deploy/k8s/base/hpa.yaml`, tracking gateway) |

## 4) Infrastructure Documentation

| Requested Item | Status | Evidence |
|---|---|---|
| Kubernetes topology | Covered | `deploy/k8s/base/*.yaml` |
| ingress/load balancing | Covered | `deploy/k8s/base/ingress.yaml`, nginx annotations |
| Redis HA setup | Not Found | only single-replica `deploy/k8s/base/redis-statefulset.yaml` |
| Mongo setup | Partial | app config present (`deploy/k8s/base/mongo-config.yaml`, backend config) but no in-repo mongo deployment |
| autoscaling strategy | Covered | `deploy/k8s/base/hpa.yaml`, overlay patches |
| readiness/liveness architecture | Covered | probes in deployment manifests + `/health/ready` logic |
| CI/CD flows | Partial | release scripts exist; complete pipeline workflow definition not fully documented in one source |
| DR/backup systems | Covered | `backend/docs/BACKUP_RESTORE_RUNBOOK.md`, `DR_POLICY.md`, `RESTORE_DRILL_RUNBOOK.md`, ops backup artifacts |
| failover behavior | Partial | app-level and client-level failover behavior present; infra-level HA for redis/mongo not fully in manifests |

## 5) Security Documentation

| Requested Item | Status | Evidence |
|---|---|---|
| auth protections | Covered | middleware/auth flow in backend + client token refresh/expiry handling |
| RBAC | Covered | `backend/middleware/authorizationMiddleware.js`, route mounts |
| payment hardening | Covered | rate limits, verification, webhook+outbox durability |
| Redis fail-closed behavior | Covered | readiness checks in `backend/server.js`, runtime config/queue rejection pathways |
| upload protections | Covered | upload limiter and signed-upload config paths |
| websocket security | Covered | query token blocked + bearer auth + room ACL in tracking/pricing gateways |
| secret handling | Covered | k8s `secretRef`, `secret-template.yaml` |
| tracing/logging redaction protections | Covered | `backend/services/structuredLogger.js` |

## 6) Operations Documentation

| Requested Item | Status | Evidence |
|---|---|---|
| deployment process | Covered | `deploy/k8s/README.md`, release scripts |
| rollback procedure | Partial | operationally documented; no single scripted rollback automation found |
| restore drills | Covered | backend restore drill runbooks/docs |
| alerting strategy | Covered | `deploy/k8s/base/ingress-observability.yaml`, ops metrics/alerts logic |
| observability stack | Covered | OTEL + structured logger + metrics endpoints |
| health endpoints | Covered | `backend/server.js` |
| metrics endpoints | Covered | `backend/server.js` |
| incident runbooks | Covered | `backend/docs/INCIDENT_RUNBOOKS.md` |

## 7) API Documentation

| Requested Item | Status | Evidence |
|---|---|---|
| major endpoints | Covered | `backend/server.js`, `backend/routes/*.js` |
| auth requirements | Covered | route middleware + role guards |
| request/response summaries | Partial | summarized from routes/controllers; no unified OpenAPI spec file found |
| websocket event summaries | Covered | tracking/pricing gateway service implementations |

## 8) Architecture Diagrams

| Requested Diagram | Status | Output File |
|---|---|---|
| system architecture | Covered | `docs/technical/notion/diagrams/architecture-diagrams.md` |
| payment flow | Covered | same |
| webhook ingest flow | Covered | same |
| queue/outbox flow | Covered | same |
| websocket event flow | Covered | same |
| Kubernetes topology | Covered | same |
| OTEL trace flow | Covered | same |

## 9) Output Requirements Compliance

| Requirement | Status | Notes |
|---|---|---|
| organize docs into folders/files | Covered | `docs/technical/notion/*` hierarchy |
| generate markdown only | Covered | all `.md` |
| production-grade terminology | Covered | terminology aligned to runtime/infrastructure controls |
| document only implemented behavior | Covered | with `Partial`/`Not Found` flags where applicable |
| avoid hallucinated features | Covered | explicit gaps called out |
| preserve architectural accuracy | Covered | file-backed references included |
| include operational notes | Covered | operations + runtime lifecycle pages include production notes |

## Gap Summary (Actionable)

1. Redis HA topology is not implemented in current k8s manifests (single-node StatefulSet).
2. Mongo deployment topology is external/not defined in in-repo k8s resources.
3. Unified OpenAPI contract is not present as a single source file.
4. CI/CD rollback automation is partially documented via scripts but not centralized as one workflow document.

## Recommended Next Documentation Additions

1. Add an explicit `infrastructure/high-availability-boundaries.md` page for Redis/Mongo HA scope.
2. Add `api/openapi-gap-map.md` listing key schemas and where they live in validation files.
3. Add `operations/rollback-playbook.md` with command-level rollback runbooks per environment.
