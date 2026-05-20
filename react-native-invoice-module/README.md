# ABZORA React Native Invoice Module

## Included
- `src/api/invoiceApi.ts` API client for invoice endpoints
- `src/screens/InvoiceHistoryScreen.tsx` customer invoice history
- `src/screens/InvoiceDetailsScreen.tsx` invoice details + download/share/email
- `src/components/InvoiceCard.tsx` premium invoice list card
- `src/hooks/useInvoices.ts` data hook

## Integration
1. Set auth token using `setAuthToken(firebaseToken)`.
2. Mount `InvoiceHistoryScreen` in account/orders area.
3. Navigate to `InvoiceDetailsScreen` with selected invoice id.
4. Use backend endpoints at `/api/invoices/*`.

## Notes
- Download uses signed URL flow (`/download-link/:invoiceId` then `/download/:invoiceId?token=...`).
- Works with ABZORA backend invoice queue + immutable snapshots.
