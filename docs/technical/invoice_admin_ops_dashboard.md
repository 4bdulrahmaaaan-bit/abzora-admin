# Invoice Admin Operational Dashboard

## Modules
- Queue health and worker status
- Replay center with confirmation token flow
- DLQ replay trigger
- Queue pause/resume controls
- Replay audit logs
- Email lifecycle logs + resend action
- Suppression list viewer
- Invoice verification lookup
- Freeze/legal-hold update action
- CSV/XLSX export center actions

## API surfaces consumed
- `GET /health/queue`
- `GET /health/storage`
- `GET /health/email`
- `GET /health/invoices`
- `GET /api/invoices/admin/replay-dashboard`
- `GET /api/invoices/admin/replay-audit`
- `GET /api/invoices/admin/email-logs`
- `GET /api/invoices/admin/suppressions`
- `POST /api/invoices/admin/queue/replay-dlq`
- `POST /api/invoices/admin/queue/pause`
- `POST /api/invoices/admin/queue/resume`
- `POST /api/invoices/admin/email-logs/:emailLogId/resend`
- `PATCH /api/invoices/admin/:invoiceId/freeze`
- `GET /api/invoices/verify/invoice/:invoiceId`

## RBAC behavior
- Admin-only screen exposure in invoice hub route.
- Destructive/operational actions require explicit modal confirmation.
- Unauthorized users cannot access admin invoice operational controls.
