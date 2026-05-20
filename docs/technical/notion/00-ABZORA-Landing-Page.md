# ABZORA Production Technical Documentation

## Executive Summary

ABZORA is a multi-application commerce platform built with Flutter clients, a Node.js/Express backend, Redis-assisted realtime and queue subsystems, MongoDB persistence, and Kubernetes deployment topology.

This documentation set is organized for production operations, architecture review, security audits, and incident readiness. All content is derived from implemented repository behavior.

## Documentation Objectives

- Provide architecture-level clarity across customer, vendor, rider, admin, backend, and infrastructure surfaces.
- Capture operationally significant behaviors including health/readiness, retries, dead-letter handling, and graceful shutdown.
- Document implemented security controls and known boundaries.
- Provide import-friendly structure for Notion with clear page hierarchy.

## Primary Navigation

### 1) System
- `system/system-overview.md`

### 2) Frontend
- `frontend/customer/customer-app.md`
- `frontend/vendor/vendor-app.md`
- `frontend/rider/rider-app.md`
- `frontend/admin/admin-web-panel.md`

### 3) Backend
- `backend/README.md`
- `backend/backend-overview.md`
- `backend/api-auth.md`
- `backend/orders-lifecycle.md`
- `backend/payments-lifecycle.md`
- `backend/redis-queue-architecture.md`
- `backend/outbox-replay.md`
- `backend/webhook-ingest.md`
- `backend/websocket-architecture.md`
- `backend/observability-logging.md`
- `backend/runtime-lifecycle.md`

### 4) Infrastructure
- `infrastructure/infrastructure-deployment.md`

### 5) Security
- `security/security-architecture.md`

### 6) Operations
- `operations/operations-runbook.md`

### 7) API and Realtime
- `api/api-websocket-reference.md`

### 8) Architecture Diagrams
- `diagrams/architecture-diagrams.md`

## Suggested Reading Paths

### Executive / Leadership Path
1. `system/system-overview.md`
2. `infrastructure/infrastructure-deployment.md`
3. `operations/operations-runbook.md`
4. `security/security-architecture.md`

### Engineering Onboarding Path
1. `system/system-overview.md`
2. Frontend app page for your domain
3. `backend/backend-overview.md`
4. `api/api-websocket-reference.md`
5. `diagrams/architecture-diagrams.md`

### Production Incident Path
1. `operations/operations-runbook.md`
2. `backend/runtime-lifecycle.md`
3. `backend/webhook-ingest.md`
4. `backend/outbox-replay.md`
5. `backend/observability-logging.md`

## Scope and Accuracy Notes

- Documentation reflects code/manifests currently present in this repository.
- Where requested capability is not clearly implemented, it is marked accordingly.
- This set should be updated after major infra/backend/frontend topology changes.
