# Runtime and Shutdown

Startup sequence:
- Start OTEL
- Connect Mongo
- Initialize Firebase and schedulers
- Start outbox/webhook workers (env-controlled)
- Bind HTTP server
- Warm redis subsystems asynchronously

Health endpoints:
- `/health`
- `/health/live`
- `/health/ready`

Graceful shutdown:
- Stop accepting traffic
- Stop workers/gateways/schedulers
- Close redis clients
- Shutdown telemetry SDK
- Close DB
- Enforce timeout-bound exit (`GRACEFUL_SHUTDOWN_TIMEOUT_MS`)
