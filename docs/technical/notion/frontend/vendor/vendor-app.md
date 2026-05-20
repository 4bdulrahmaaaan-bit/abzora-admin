# Vendor App Architecture

## Overview

Entrypoint: `lib/main_vendor.dart`.

Vendor mode is built on shared shell with vendor-specific screens and role-gated access behavior.

## Folder Structure (Vendor-Relevant)

- `lib/screens/vendor/*`
- `lib/features/onboarding/vendor_onboarding_flow_screen.dart`
- Shared providers/services from `lib/providers/*` and `lib/services/*`

## State Management

- Provider-based state, shared auth/session model via `AuthProvider`

## Routing / Navigation

- Named route model from shared app shell
- Vendor access checks via `hasVendorOperationsAccess` and route resolution helpers

## Authentication and Access Flow

- Firebase-authenticated session
- Vendor mode access requires vendor role mapping and/or store-linked eligibility
- Explicit restriction messaging for non-vendor eligible accounts

## API Integrations

- Shared `BackendApiClient` with authenticated calls
- Vendor-relevant domains: store management, product management, order operations, finance/payout surfaces

## Websocket / Realtime

- Tracking websocket architecture exists backend-side and is role-gated
- Vendor app consumes realtime/order updates through available service pathways

## Payment / Settlement Surfaces

- Vendor side operationally interacts with payment outcomes, returns/refunds, and settlement endpoints through backend APIs

## Push Notifications

- Store-specific topic subscription pattern for eligible vendor/store users in `NotificationService`

## Security and Error Handling

- Shared auth-token refresh and unauthorized recovery pipeline
- Shared backend exception handling strategy from `BackendApiClient`

## Responsive Handling

- Flutter widget-driven adaptive UI behavior across mobile/web surfaces
