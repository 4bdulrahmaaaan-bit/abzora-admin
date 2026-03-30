# iOS Handoff

## Current Status

- Android is the validated platform right now.
- iOS has been partially prepared but not build-verified.
- A real iOS build still requires macOS, Xcode, and CocoaPods.

## Already Prepared

- Customer Firebase iOS config is present at `ios/Runner/GoogleService-Info.plist`
- Bundle identifier currently matches the customer Firebase app:
  - `com.abdz.fashion.abzio`
- Flutter Firebase mobile config points customer iOS to:
  - `abzora-bbed7`
- Privacy usage descriptions were added to `ios/Runner/Info.plist` for:
  - camera
  - location
  - microphone
  - photo library
  - speech recognition

## Still Required On macOS

1. Install prerequisites:
   - Xcode
   - CocoaPods
   - Flutter SDK

2. From the project root, run:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --no-codesign
```

3. Open the workspace in Xcode:

```bash
open ios/Runner.xcworkspace
```

4. In Xcode:
   - select a development team
   - confirm signing settings
   - verify bundle identifier is `com.abdz.fashion.abzio`
   - run on simulator or physical iPhone

## Things To Verify On iOS

- Firebase initializes successfully
- Phone authentication works
- Mongo/backend calls succeed against:
  - `https://abzora-backend.onrender.com`
- Camera and photo picker permissions work
- Location permission flow works
- Firebase Messaging / push flow behaves correctly
- Razorpay flow works on iOS
- Google Maps works if used in production

## Likely Follow-up Tasks

- Confirm `ios/Podfile` exists and `pod install` succeeds
- Re-check any iOS payment callback requirements for Razorpay
- Add APNs configuration for production push notifications
- If partner app also needs iPhone support:
  - add/verify a separate iOS Firebase app config for partner
  - verify the partner bundle identifier and plist

## Important Files

- `ios/Runner/Info.plist`
- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/AppDelegate.swift`
- `lib/firebase_options.dart`

## Honest Summary

- The project is iOS-prepared, not iOS-verified.
- The remaining blocker is environment, not Flutter code alone.
- Once a Mac is available, use this checklist to finish iOS setup quickly.
