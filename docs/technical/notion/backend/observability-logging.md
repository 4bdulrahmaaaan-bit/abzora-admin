# Observability and Logging

Tracing:
- OpenTelemetry startup gated by env configuration
- Instrumentations: HTTP, Express, MongoDB, Redis
- OTLP exporters (HTTP/gRPC) with non-prod console fallback

Metrics endpoints:
- `/metrics/telemetry`
- `/metrics/outbox`
- `/metrics/webhook-ingest`

Structured logging:
- JSON logs with request/trace/span correlation fields
- Sensitive-field redaction (`authorization`, `token`, `password`, `secret`, `signature`, etc.)
- Truncation and depth/key caps to prevent log overload
