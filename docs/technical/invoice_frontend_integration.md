# ABZORA Invoice Frontend Integration

## Route Wiring Summary
- `/invoice/hub`: role-aware invoice entry point
- `/invoice/history`: customer invoice listing
- `/invoice/details`: invoice details view
- `/invoice/pdf`: PDF preview (cached/offline fallback)
- `/invoice/refund-timeline`: refund status timeline
- `/invoice/credit-note`: credit note screen
- Admin operational route modules inside `/invoice/hub`:
  - queue monitoring
  - replay center
  - email lifecycle logs
  - suppressions
  - verification lookup
  - freeze/legal-hold controls
  - export center actions

## Entry Points
- Customer app: `/orders` screen has `Invoices` action.
- Vendor app: dashboard app bar invoice icon.
- Admin app: dashboard `Invoice Operations` action.

## Provider Dependency Graph
- `invoiceDioProvider`
  -> `invoiceRepositoryProvider`
  -> `customerInvoicePagerProvider`
  -> `vendorInvoicePagerProvider`
  -> `adminInvoicePagerProvider`
  -> `invoiceDetailsProvider`
  -> `gstSummaryProvider`
  -> `invoiceEmailLogsProvider`
  -> `invoiceReplayDashboardProvider`

## Offline + Cache Lifecycle
1. Invoice list fetched from API.
2. Successful list saved in `InvoiceOfflineCache`.
3. On failure, cached snapshot shown (degraded mode).
4. PDF access tries cache first, then signed URL download.
5. Downloaded PDFs persisted in app documents for offline open.
6. On signed-url expiration, details/PDF flows request a fresh signed URL.
7. Invoice metadata cache supports degraded read mode during outages.

## Performance Notes
- Infinite scroll pagination pattern used in invoice history.
- Riverpod `autoDispose` providers prevent stale retention.
- Dedupe merge logic avoids duplicate invoice rows between pages.
- PDF viewer uses file rendering when available for faster reopen.
- Admin panels are split into lazy async sections to reduce rebuild pressure.
