# 1. System Overview

## Platform Architecture

ABZORA is implemented as a multi-surface commerce platform with:
- Flutter clients for customer, vendor, rider, and admin-facing experiences (`lib/main_customer.dart`, `lib/main_vendor.dart`, `lib/main_rider.dart`, `lib/main_admin.dart`)
- A Node.js/Express backend (`backend/server.js`) that exposes domain APIs and hosts websocket gateways
- Redis-backed runtime subsystems for rate limiting, queueing, cache, locks, and websocket fanout
- MongoDB as primary persistence via Mongoose models
- Kubernetes manifests for API, websocket, and worker process topology (`deploy/k8s/base`)

## App Ecosystem

- Customer app: unified marketplace and checkout flows, profile, cart, orders, trial-home, wishlist, AR surfaces.
- Vendor app: vendor dashboard, onboarding, catalog/product and order management, pricing and payout workflows.
- Rider app: dedicated routing/dashboard stack with rider API + websocket live tracking.
- Admin web panel: admin routes and screens are implemented in Flutter (web target), backed by `/admin/*` APIs.

## Service Interactions

- Authentication source-of-truth is Firebase Auth token issuance and verification.
- Flutter clients attach Firebase ID tokens to backend authenticated calls.
- Backend verifies tokens in `authMiddleware`, enforces role checks in authorization middleware.
- Payment lifecycle is Razorpay-driven with:
  - order creation and signature verification endpoints
  - webhook ingestion
  - durable outbox replay side effects
- Realtime channeling:
  - `/tracking/ws` for role-bound tracking rooms
  - `/ws/pricing` for admin-only pricing config stream

## Deployment Topology

Base Kubernetes layout:
- `abianzo-api` deployment: synchronous API traffic
- `abianzo-websocket` deployment: websocket handling (outbox/webhook workers disabled)
- `abianzo-worker` deployment: worker execution (outbox/webhook workers enabled)
- `redis` statefulset: single-replica Redis with AOF enabled
- Ingress split by concern: API, websocket, admin, webhook
- HPA, PDB, anti-affinity, and topology spread constraints for pod resilience

Operationally significant startup/shutdown behavior:
- Server binds HTTP and warms Redis subsystems asynchronously; readiness gating protects traffic admission.
- Graceful shutdown drains HTTP, stops workers/schedulers, closes redis clients and telemetry, then closes DB.
