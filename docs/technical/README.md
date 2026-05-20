# ABZORA Technical Documentation

This documentation is generated from implemented code and manifests in:
- `lib/`, `web/` (Flutter apps and web target)
- `backend/` (Express API, workers, websocket gateways)
- `deploy/k8s/` (Kubernetes base and overlays)

## Documentation Map

1. [System Overview](./01-system-overview.md)
2. [Frontend Architecture](./02-frontend-architecture.md)
3. [Backend Architecture](./03-backend-architecture.md)
4. [Infrastructure and Deployment](./04-infrastructure-deployment.md)
5. [Security Architecture](./05-security-architecture.md)
6. [Operations Runbook](./06-operations-runbook.md)
7. [API and WebSocket Reference](./07-api-websocket-reference.md)
8. [Architecture Diagrams](./08-architecture-diagrams.md)

## Scope and Accuracy Rules

- Only implemented behavior is documented.
- Where a requested capability is not explicitly implemented, it is called out as "not found in current repository code".
- Operational notes are included where failure modes or production safety behavior are present.
