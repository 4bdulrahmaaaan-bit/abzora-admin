# System Overview

## Platform Architecture

ABZORA is implemented as a multi-surface commerce platform composed of:
- Flutter clients for customer, vendor, rider, and admin-facing experiences (`lib/main_customer.dart`, `lib/main_vendor.dart`, `lib/main_rider.dart`, `lib/main_admin.dart`)
- A Node.js/Express backend (`backend/server.js`) exposing REST APIs and websocket gateways
- Redis-backed runtime subsystems for rate limiting, queueing, caching, locks, and websocket fanout
- MongoDB (via Mongoose models) as primary persistence
- Kubernetes workload topology in `deploy/k8s/base` with environment overlays

## App Ecosystem

- Customer app: marketplace, cart, checkout, payments, orders, profile, trial-home, AR surfaces
- Vendor app: onboarding, store/product management, order management, pricing/finance operations
- Rider app: onboarding, dashboard, orders, live location and delivery-state operations
- Admin web panel: admin dashboards and control functions built in Flutter web target

## Service Interactions

- Firebase Auth token issuance + backend verification for authenticated operations
- Backend role enforcement for admin/vendor/rider/customer paths
- Razorpay payment lifecycle with API verify + webhook ingest + durable outbox replay
- Websocket channels for tracking (`/tracking/ws`) and pricing admin stream (`/ws/pricing`)

## Deployment Topology

- `Deployment/abianzo-api`
- `Deployment/abianzo-websocket`
- `Deployment/abianzo-worker`
- `StatefulSet/redis`
- Dedicated ingress objects for API, websocket, admin, and webhook traffic

## Startup/Shutdown Characteristics

- Redis subsystem warmup is asynchronous after HTTP bind; readiness endpoint gates traffic.
- Graceful shutdown drains listeners and terminates workers/schedulers before process exit.
