# ABZORA Real-Time AR Body Try-On System

This system turns ABZORA's existing body-scan and overlay stack into a production-ready AR module with:

- Flutter UI entry points
- Native Android and iOS AR module shells
- MediaPipe pose tracking
- Product AR metadata and alignment config
- Try-on session persistence

## Architecture

### Flutter

- `lib/screens/user/live_ar_try_on_screen.dart`
  Existing premium live try-on UI with camera stream, pose processing, fit feedback, and capture flow.
- `lib/services/ar_try_on_service.dart`
  Calculates hybrid 2D overlay transforms from pose landmarks.
- `lib/services/mediapipe_pose_bridge.dart`
  Typed Flutter bridge for MediaPipe native pose inference.
- `lib/services/real_time_ar_try_on_bridge.dart`
  New production bridge for native renderer lifecycle, garment switching, camera direction changes, and preview capture.
- `lib/widgets/ar_native_try_on_view.dart`
  Embeds the native AR surface via platform views.
- `lib/models/ar_try_on_models.dart`
  Typed metadata/session payloads shared by UI and API layers.

### Android

- `android/app/src/main/kotlin/com/abdz/fashion/abzio/MediaPipePoseBridge.kt`
  Native MediaPipe Pose integration.
- `android/app/src/main/kotlin/com/abdz/fashion/abzio/RealTimeArTryOnPlugin.kt`
  Native AR bridge shell for platform view registration, renderer commands, and capture requests.

### iOS

- `ios/Runner/MediaPipePoseBridge.swift`
  Native MediaPipe Pose integration.
- `ios/Runner/RealTimeArTryOnPlugin.swift`
  Native AR bridge shell for platform view registration and event streaming.

### Backend

- `backend/services/arAssetService.js`
  Generates normalized overlay metadata from product images.
- `backend/controllers/tryOnController.js`
  Exposes product-level try-on metadata and session persistence.
- `backend/models/TryOnSession.js`
  Stores AR try-on sessions for analytics, debugging, and future size intelligence.
- `backend/routes/arRoutes.js`
  Public metadata endpoint plus authenticated session save.

## Backend API

### `GET /ar/product/:id`

Returns:

```json
{
  "id": "product_id",
  "name": "Slim Fit Shirt",
  "category": "shirt",
  "images": ["..."],
  "model3d": "",
  "overlayAssetUrl": "https://...",
  "transparentAssetUrl": "https://...",
  "alignmentConfig": {
    "anchorTemplate": "torso_template",
    "scaleFactor": 1.08,
    "widthFactor": 1.12,
    "heightFactor": 1.58,
    "anchors": {
      "leftShoulder": { "x": 0.32, "y": 0.18 },
      "rightShoulder": { "x": 0.68, "y": 0.18 },
      "center": { "x": 0.5, "y": 0.44 }
    }
  },
  "arAsset": {}
}
```

### `POST /ar/tryon/session`

Authenticated route for analytics and future fit personalization.

```json
{
  "productId": "mongo_product_id",
  "sessionId": "tryon_20260410_001",
  "platform": "android",
  "deviceModel": "motorola edge 70 fusion",
  "cameraFacing": "front",
  "mode": "live_overlay",
  "captureCount": 2,
  "outfitSwitchCount": 1,
  "averageFps": 28.4,
  "peakFps": 31.0,
  "averagePoseConfidence": 0.83,
  "bodyProfileSnapshot": {
    "heightCm": 176.0,
    "chestCm": 98.0
  },
  "measurements": {
    "shoulderCm": 44.0,
    "waistCm": 84.0
  },
  "renderStats": {
    "renderer": "hybrid_2d",
    "occlusionEnabled": true,
    "physicsEnabled": false,
    "frameSkipCount": 18
  },
  "events": [
    {
      "timestampMs": 1712757900000,
      "fps": 30,
      "poseConfidence": 0.84,
      "bodyVisible": true,
      "lightingScore": 0.71
    }
  ],
  "previewImageUrl": "",
  "status": "completed"
}
```

## Runtime Flow

1. Flutter opens `LiveArTryOnScreen`.
2. App fetches `GET /ar/product/:id` for overlay asset and alignment config.
3. Native MediaPipe bridge produces 33 pose landmarks.
4. `ArTryOnService` stabilizes overlay width, height, rotation, and fallback behavior.
5. `ArNativeTryOnView` hosts native renderer for Android/iOS.
6. Flutter can capture preview and persist `POST /ar/tryon/session`.

## Alignment Logic

The current production overlay path uses:

- shoulder distance -> width scale
- shoulder midpoint to hip midpoint -> torso height
- shoulder angle -> garment rotation
- decayed previous landmarks -> pose-loss fallback
- smoothed interpolation -> jitter reduction

This keeps rendering stable even before full 3D cloth simulation is introduced.

## Native Renderer Strategy

The newly added native plugin files are renderer shells. They provide:

- a clean channel contract
- platform view registration
- event streaming for render state
- future-safe extension points for ARCore and ARKit

Recommended next production step:

- Android: swap `RealTimeArTryOnPlugin.kt` internal view implementation to `ArFragment`/Sceneform or Filament-based renderer with ARCore availability checks
- iOS: replace the placeholder `UIView` with `ARSCNView` or `ARView` and map pose transforms into SceneKit/RealityKit nodes

The channel contract is already stable, so renderer upgrades can happen without changing Flutter entry points.

## Performance Guidance

- target `ResolutionPreset.medium` for live inference unless device-tier allows higher
- process every 2nd or 3rd frame if FPS drops below 24
- keep pose smoothing enabled
- cache overlay and 3D assets aggressively
- prefer GPU-backed MediaPipe delegates on capable devices
- use front camera for apparel preview, back camera for room-aware AR only when needed

## Edge Cases

- no body detected -> show guide outline
- low visibility landmarks -> freeze last good transform and reduce opacity
- partial body -> disable capture and show framing guidance
- low light -> show warning chip

## Asset Preparation

For best results:

- use transparent PNG garment cutouts for 2D hybrid mode
- keep assets centered on a 3:4 canvas
- save alignment defaults in metadata
- upload normalized processed overlays to Cloudinary/Firebase Storage

Reference config:

- `assets/ar/sample_alignment_config.json`

## Setup Steps

1. Ensure MediaPipe model exists at `assets/ml/pose_landmarker_lite.task`.
2. Keep `camera` permissions configured for Android and iOS.
3. Verify backend exposes `/ar/product/:id` and `/ar/tryon/session`.
4. Use `BackendCommerceService.getTryOnProductMetadata(productId)` before opening the native AR view.
5. Initialize the bridge:

```dart
final metadata = await BackendCommerceService().getTryOnProductMetadata(product.id);
await RealTimeArTryOnBridge.instance.initialize(metadata: metadata);
```

6. Render the native view:

```dart
ArNativeTryOnView(metadata: metadata)
```

7. On session end, persist analytics:

```dart
await BackendCommerceService().saveTryOnSession(sessionPayload);
```

## Recommended Next Upgrades

- 3D skeleton-driven `.glb` garments for blazers, dresses, and gowns
- depth-aware occlusion
- body measurement save-to-profile
- cloth secondary motion
- vendor-facing AR asset approval workflow
- try-on snapshot upload to Firebase Storage
