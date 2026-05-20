# WebSocket Architecture

Tracking gateway (`/tracking/ws`):
- Header bearer-token auth only (query token blocked)
- Room model: order, rider, user, task, zone
- ACL checks on join requests based on role/entity ownership
- Redis pub/sub fanout for horizontal delivery

Pricing gateway (`/ws/pricing`):
- Admin-only websocket stream
- Emits pricing config snapshot and broadcast updates
