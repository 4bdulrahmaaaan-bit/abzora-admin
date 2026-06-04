# 8. Architecture Diagrams

## System Architecture

```mermaid
graph TD
  C[Customer App] --> API[ABZORA API Deployment]
  V[Vendor App] --> API
  R[Rider App] --> API
  A[Admin Web Panel] --> API

  C --> WS[WebSocket Gateway /tracking/ws]
  R --> WS
  A --> PWS[WebSocket Gateway /ws/pricing]

  API --> MDB[(MongoDB)]
  API --> REDIS[(Redis)]
  WS --> REDIS
  W[Worker Deployment] --> MDB
  W --> REDIS

  API --> RP[Razorpay]
  RP --> WH[Webhook Ingest]
  WH --> W
```

## Payment Flow

```mermaid
sequenceDiagram
  participant App as Client App
  participant API as Backend API
  participant RP as Razorpay
  participant WH as Webhook Ingest Worker
  participant OB as Outbox Worker

  App->>API: POST /orders/create-razorpay-order
  API-->>App: Razorpay order payload
  App->>RP: Checkout
  RP-->>App: payment success/failure
  App->>API: POST /orders/verify-payment
  RP->>API: POST /webhooks/razorpay
  API->>WH: Persist ingest event
  WH->>API: Process event (captured/failed/refund)
  API->>OB: Persist outbox side effect events
  OB->>API: Replay side effects + metrics/audit
```

## Webhook Ingest Flow

```mermaid
graph LR
  RP[Razorpay/RazorpayX] --> IG[Ingress webhook host]
  IG --> API[/webhooks/* raw body/]
  API --> EVT[(PaymentWebhookIngestEvent)]
  EVT --> WKR[Webhook Ingest Worker]
  WKR -->|success| PROC[Processed]
  WKR -->|retry backoff| RETRY[Failed + nextAttemptAt]
  WKR -->|max attempts| DLQ[Dead-letter]
```

## Queue / Outbox Flow

```mermaid
graph TD
  APP[Domain Write] --> OUT[(PaymentOutboxEvent)]
  OUT --> CLAIM[Worker Claim + Lease]
  CLAIM --> SIDE[Replay Side Effects]
  SIDE --> OK[Processed]
  SIDE --> ERR[Retry Scheduled]
  ERR --> DLQ[Dead-letter after max attempts]
  CLAIM --> MET[Outbox Metrics Endpoint]
```

## WebSocket Event Flow

```mermaid
graph TD
  U[Authenticated Socket Client] --> TG[/tracking/ws/]
  TG --> AUTH[Firebase token verify]
  AUTH --> ACL[Room ACL check]
  ACL --> ROOMS[order:user:rider:task:zone rooms]
  PUB[Publish tracking event] --> REDIS[(Redis PubSub)]
  REDIS --> TG
  TG --> FANOUT[Fanout to room subscribers]
```

## Kubernetes Topology

```mermaid
graph TD
  IN[Ingress NGINX] --> API[Service abianzo-api]
  IN --> WSSVC[Service abianzo-websocket]
  IN --> ADMSVC[Service abianzo-admin]

  API --> APIPOD[Deployment abianzo-api]
  WSSVC --> WSPOD[Deployment abianzo-websocket]
  ADMSVC --> APIPOD

  APIPOD --> REDIS[(StatefulSet redis)]
  WSPOD --> REDIS
  WRK[Deployment abianzo-worker] --> REDIS

  APIPOD --> MDB[(External MongoDB)]
  WRK --> MDB
```

## OTEL Trace Flow

```mermaid
graph LR
  REQ[HTTP Request] --> MW[requestContext + telemetry middleware]
  MW --> SPAN[OTEL Span Start]
  SPAN --> APP[Controller/Service Execution]
  APP --> DB[Mongo/Redis Instrumentation]
  APP --> LOG[Structured JSON Logging with trace ids]
  SPAN --> EXP[OTLP Exporter HTTP or gRPC]
  EXP --> APM[Tracing Backend]
```
