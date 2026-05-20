# Payments Lifecycle

Gateway:
- Razorpay integration for order creation and signature verification.

Core endpoints:
- `POST /orders/create-razorpay-order`
- `POST /orders/verify-payment`
- `POST /payment/create-order`
- `POST /payment/verify`

Async settlement surfaces:
- `POST /webhooks/razorpay`
- `POST /webhooks/razorpayx`

Hardening:
- Payment route-specific rate limiting
- Post-checkout signature verification and webhook reconciliation
- Durable async processing via ingest/outbox workers
