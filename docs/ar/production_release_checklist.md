# ABZORA AR Production Release Checklist

This checklist covers Flutter app, Unity runtime, Node backend, MongoDB, CDN assets, and Admin CMS.

## 1. Environment Configuration

### Backend (`backend/.env`)
- `PORT=5000`
- `HOST=0.0.0.0`
- `MONGO_URI=<production-mongo-uri>`
- `REDIS_URL=<production-redis-uri>`
- `REDIS_DISABLED=false`
- `ALLOWED_ADMIN_EMAILS=<comma-separated-admin-emails>`
- `AUTH_MAX_SESSION_AGE_MINUTES=480`
- `REQUIRE_EMAIL_VERIFICATION=true`
- Cloudinary/Firebase/Razorpay keys already used by your current backend.

### Admin CMS (`admin-next/.env.local`)
- `NEXT_PUBLIC_BACKEND_URL=https://<your-backend-domain>`
- Optional: `BACKEND_SERVICE_URL=https://<your-backend-domain>`

### Flutter app
- Ensure backend base URL points to production.
- Confirm Firebase configs match production project.
- Ensure AR try-on routes are reachable:
  - `GET /ar/product/:id`
  - `GET /ar/templates`
  - `POST /ar/fit/score`

## 2. Unity Bundle + CDN Release

### Build outputs (per template/version)
- `lod0` bundle
- `lod1` bundle
- `lod2` bundle
- texture assets (albedo, normal, roughness as needed)

### CDN path convention
- `/ar/templates/{template-slug}/v{n}/lod0.bundle`
- `/ar/templates/{template-slug}/v{n}/lod1.bundle`
- `/ar/templates/{template-slug}/v{n}/lod2.bundle`
- `/ar/textures/{fabric-code}/{texture-file}`

### Cache policy
- Versioned assets: immutable long cache (recommended 1 year).
- JSON API: short TTL via backend/redis.

## 3. Backend Data Readiness

### Template registry
- Create/update templates via `POST /ar/templates/upsert`.
- Verify each template includes:
  - `category`, `modelUrls`, `rigProfile`
  - `customizableParts`
  - `supportedFits`
  - `cachePolicy`

### Product linkage
- Each AR-enabled product has `garmentConfig`:
  - `templateId`
  - `fabricTextureUrl`
  - `normalMapUrl` (if used)
  - `fitPreset`
  - `colorHex`
  - `designOptions`
  - `blendShapeOverrides`
  - `lodPreference`

## 4. Security + Role Controls

- Keep `/ar/templates/upsert` behind auth + role checks (`admin`, `super_admin`, `designer`).
- Verify admin JWT flow for Next.js CMS actions.
- Confirm only authorized roles can publish template updates.

## 5. Performance Gates (must pass)

### Mobile runtime
- AR first render target: <= 2.5 seconds on test devices.
- Runtime FPS target: 30-60 FPS.
- LOD fallback triggers when FPS drops under threshold.

### Asset quality
- No missing bundle URLs.
- No missing texture URLs.
- Blend shape names match runtime keys.

## 6. Functional QA Matrix

### Try Live flow
- Product page -> Try Live opens Unity AR screen.
- Payload initializes correctly for all garment categories.
- Fit result callback appears (`recommendedSize`, `fitScore`, `confidence`, `fitLabel`).

### Fallback behavior
- If Unity/payload fails, fallback path remains usable.
- Camera permission denied path is handled.

### Checkout continuity
- User returns from AR and can continue add-to-cart / checkout.

## 7. Observability

- Monitor backend route health:
  - `/ar/product/:id`
  - `/ar/fit/score`
  - `/ar/tryon/session`
- Track AR events:
  - `unity_ready`
  - `onLoaded`
  - `onFitCalculated`
  - `onError`

## 8. Deployment Order (recommended)

1. Upload Unity bundles/textures to CDN.
2. Upsert template records in backend.
3. Link products to templates/garment configs.
4. Deploy backend (Node).
5. Deploy admin-next (CMS).
6. Release Flutter app build.
7. Smoke test live Try Live flow end-to-end.

## 10. One-Command Release Scripts

Run from repository root:

- `npm run release:backend`
- `npm run release:ar-assets`
- `npm run release:admin`
- `npm run release:all`

## 9. Rollback Plan

- Keep previous template versions active on CDN.
- Roll back template mapping in CMS/version page.
- If needed, disable AR CTA for affected products while preserving purchase flow.
