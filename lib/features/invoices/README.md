# Flutter Invoice Module (Enterprise)

## Architecture
- `data/` remote datasource + repository
- `domain/` entities
- `presentation/` Riverpod providers + screens + widgets
- `services/` download manager + offline cache

## Screens
- `InvoiceHistoryScreen`
- `InvoiceDetailsScreen`
- `InvoicePdfViewerScreen`
- `CreditNoteScreen`
- `RefundTimelineScreen`

## Integrations
- Dio for API calls
- Riverpod for state management
- Syncfusion PDF viewer for document view
- OpenFileX + share_plus for open/share
- flutter_cache_manager + local docs storage for offline

## Router Hooks
- `/invoice/history`
- `/invoice/details`
- `/invoice/pdf`
- `/invoice/credit-note`
- `/invoice/refund-timeline`
