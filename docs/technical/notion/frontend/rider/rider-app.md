# Rider App Architecture

## Overview

Entrypoint: `lib/main_rider.dart`.

Rider app uses dedicated app composition with `ProviderScope`, rider routes, and rider-focused services for live tracking and delivery operations.

## Folder Structure (Rider-Relevant)

- `lib/features/dashboard/*`
- `lib/features/onboarding/*`
- `lib/routes/rider_router.dart`, `lib/routes/rider_routes.dart`
- `lib/core/services/rider_api_service.dart`, `lib/core/services/rider_socket_service.dart`

## State Management

- Mixed Provider + Riverpod approach
- Rider signup flow uses `StateNotifierProvider`

## Routing / Navigation

- GoRouter-based route graph for rider flows
- Additional imperative navigation in selected screens

## Authentication Flow

- Firebase-authenticated user
- ID token fetched for API and websocket authentication
- Rider mode access checks via rider role and approval status logic

## Websocket Usage

- `RiderSocketService` connects to tracking websocket endpoint
- Uses bearer auth and reconnect handling
- Emits delivery status/location/order-assignment signals

## API Integrations

- `RiderApiService` (Dio) for rider operational endpoints
- Includes location updates, ETA lookup, delivery status transitions, completion actions

## Realtime and Notifications

- Combined websocket + REST sync model
- Rider-specific topic subscription support in notification service

## Security and Error Handling

- Shared session safety from auth provider unauthorized handlers
- Request retry/backoff behavior inherited through shared client patterns

## Performance Notes

- Lightweight reconnect timer strategy for websocket disruption
- Role-focused feature segmentation keeps rider runtime surface bounded
