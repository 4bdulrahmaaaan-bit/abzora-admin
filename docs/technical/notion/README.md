# ABZORA Production Documentation (Notion Import)

## Structure

- `system/`: platform-level overview
- `frontend/customer/`: customer app architecture
- `frontend/vendor/`: vendor app architecture
- `frontend/rider/`: rider app architecture
- `frontend/admin/`: admin web panel architecture
- `backend/`: API/services/workers/realtime architecture
- `infrastructure/`: Kubernetes/deployment topology
- `security/`: security controls and hardening
- `operations/`: deployment/runbooks/incident operations
- `api/`: endpoint and websocket summaries
- `diagrams/`: mermaid architecture diagrams

## Source of Truth

This documentation reflects implemented behavior from repository code and manifests.

Primary source paths:
- `lib/`, `web/`
- `backend/`
- `deploy/k8s/`

## Notes

- Requested features not clearly implemented in current code are explicitly marked as "not found in current code".
- This avoids speculative documentation drift.
