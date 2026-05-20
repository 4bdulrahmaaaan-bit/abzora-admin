# Backend Overview

Runtime stack:
- Node.js + Express (`backend/server.js`)
- Route modules (`backend/routes/*`)
- Controllers (`backend/controllers/*`)
- Services (`backend/services/*`)
- Mongoose models (`backend/models/*`)

Core responsibilities:
- Commerce API
- Role-protected admin/vendor/rider domains
- Payments, webhook processing, outbox replay
- Realtime websocket gateways
- Health, metrics, tracing, and structured logging
