# ABZIO

ABZIO is a Flutter-based multi-role fashion marketplace with:

- customer shopping and custom clothing
- vendor operations
- rider delivery workflow
- admin web control panel

Backend integrations:

- Firebase Auth (phone OTP)
- Firebase Realtime Database
- Firebase Messaging
- Cloudinary
- Razorpay

## Local development

Install dependencies and run the standard checks:

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File .\scripts\run_local_validation.ps1
```

## Run with Firebase emulators

Start emulators:

```powershell
firebase emulators:start --only auth,database
```

Run the app against emulators:

```powershell
flutter run `
  --dart-define=USE_FIREBASE_EMULATORS=true `
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 `
  --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099 `
  --dart-define=FIREBASE_DATABASE_EMULATOR_PORT=9000
```

The app will automatically switch Firebase Auth and Realtime Database to emulator mode through [app_bootstrap_service.dart](/C:/Users/AAA/Documents/abzio/lib/services/app_bootstrap_service.dart).

## Validation

Static analysis:

```powershell
flutter analyze
```

Tests:

```powershell
flutter test
```

## Production readiness docs

- Deploy checklist: [PRODUCTION_DEPLOY_CHECKLIST.md](/C:/Users/AAA/Documents/abzio/PRODUCTION_DEPLOY_CHECKLIST.md)
- Staging UX release checklist: [STAGING_TEST_MATRIX.md](/C:/Users/AAA/Documents/abzio/STAGING_TEST_MATRIX.md)
- RTDB emulator validation: [RTDB_EMULATOR_VALIDATION.md](/C:/Users/AAA/Documents/abzio/RTDB_EMULATOR_VALIDATION.md)

## Current test coverage

The repo currently includes tests for:

- role routing and role restrictions
- cart one-store enforcement
- model update safety via `copyWith`
- app smoke boot

See the [test](/C:/Users/AAA/Documents/abzio/test) folder.
