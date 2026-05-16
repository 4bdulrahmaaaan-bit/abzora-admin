# ABZORA Kubernetes Manifests

## Structure

- `base/`: production-safe baseline manifests.
- `overlays/staging`: lower-scale staging overlay.
- `overlays/prod`: production overlay.

## Components

- API deployment (`abzora-api`)
- Worker deployment (`abzora-worker`)
- Websocket deployment (`abzora-websocket`)
- Redis statefulset (`redis`)
- Ingress + services
- HPA + PDB + anti-affinity/topology spread

## Apply

```bash
kustomize build deploy/k8s/overlays/staging | kubectl apply -f -
kustomize build deploy/k8s/overlays/prod | kubectl apply -f -
```

## Secrets

Populate `base/secret-template.yaml` through your secret manager or sealed-secrets workflow.
Do not commit real secret values.
