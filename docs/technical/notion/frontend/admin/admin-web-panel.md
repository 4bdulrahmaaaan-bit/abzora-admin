# Admin Web Panel Architecture

## Overview

Entrypoint: `lib/main_admin.dart` with initial route `/admin-login`.

Admin is implemented as a Flutter web-panel surface backed by admin-protected backend APIs.

## Folder Structure (Admin-Relevant)

- `lib/screens/admin/*`
- Shared auth/providers/services

## State Management and Routing

- Shared provider auth/session model
- Admin route entry from unified shell with admin-focused screens

## Authentication and Authorization

- Backend `/admin/*` routes require authenticated admin/super_admin role enforcement
- Ingress policy includes stricter source-range controls for admin host

## API Integrations

Primary admin domains:
- dashboard summaries
- users/stores/products/orders moderation
- finance/payout controls
- pricing configuration
- KYC and dispute handling
- trial-home review controls
- outbox dead-letter replay endpoint

## Websocket Usage

- Backend admin-only pricing websocket (`/ws/pricing`) is implemented
- Dedicated frontend usage path is not clearly surfaced in scanned files

## Security and Operational Controls

- Admin rate limiting + auth middleware
- Dedicated ingress with tighter request/connections controls

## Implementation Note

A separate React/Next admin web codebase was not found in this repository; admin panel is Flutter-based.
