# Orders Lifecycle

Implemented lifecycle surfaces include:
- Order create (`POST /orders`)
- Quote (`POST /orders/quote`)
- Quick checkout (`POST /orders/quick-checkout`)
- Status transitions (`PATCH /orders/:id/status`)
- Delivery workflow updates (`PATCH /orders/:id/delivery-status`, rider updates)
- Cancellation, custom fit feedback, alteration requests
- Refund and return request lifecycle endpoints

Operationally:
- Order flows integrate with payment verification and webhook/outbox compensation paths.
