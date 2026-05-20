# Redis and Queue Architecture

Redis-backed subsystems:
- Rate limiter store
- Ops queue store
- Ops lock store
- Cache store
- Tracking websocket pub/sub fanout

Queue architecture:
- Priority/severity queues
- Retry queues with delayed promotion
- Admission control and saturation protection
- Metrics for depth, lag, retry backlog, dropped/rejected workloads

Readiness behavior:
- Production readiness can fail when Redis-required mode is enabled and redis subsystems are unhealthy.
