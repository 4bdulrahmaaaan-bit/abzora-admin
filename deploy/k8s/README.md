# ABZORA Kubernetes Manifests

## Structure

- `base/`: production-safe baseline manifests.
- `overlays/staging`: lower-scale staging overlay.
- `overlays/prod`: production overlay.

## Components

- API deployment (`abianzo-api`)
- Worker deployment (`abianzo-worker`)
- Websocket deployment (`abianzo-websocket`)
- Redis statefulset (`redis`)
- Ingress + services
- HPA + PDB + anti-affinity/topology spread
- Ingress controller config + observability (ServiceMonitor/PrometheusRule)

## Ingress Architecture

- `abianzo-api-ingress`: general API traffic
- `abianzo-websocket-ingress`: websocket upgrade paths (`/tracking/ws`, `/ws/pricing`)
- `abianzo-admin-ingress`: admin panel traffic with stricter source-range and connection limits
- `abianzo-webhook-ingress`: webhook ingestion endpoints with tighter body and timeout tuning

Sticky-session strategy:
- Websocket ingress uses `affinity: none` intentionally.
- Session continuity is handled by token auth + Redis-backed pub/sub fanout.
- This avoids pod affinity hotspots during autoscaling.

## Apply

```bash
kustomize build deploy/k8s/overlays/staging | kubectl apply -f -
kustomize build deploy/k8s/overlays/prod | kubectl apply -f -
```

## Secrets

Populate `base/secret-template.yaml` through your secret manager or sealed-secrets workflow.
Do not commit real secret values.

## Traffic Protections Enabled

- TLS enforced with HTTP->HTTPS redirect
- ingress-level rate limiting / burst controls
- ingress connection limits / IP throttling hooks
- least-connections upstream balancing
- slowloris mitigation timeouts
- readiness-aware routing + rolling deployment compatibility
