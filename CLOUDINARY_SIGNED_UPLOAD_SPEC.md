# ABZORA Cloudinary Signed Upload Contract

This document defines the backend contract for moving ABZORA from unsigned client uploads to signed Cloudinary uploads without changing the vendor UI flow.

## Goal

Allow the Flutter app to upload product and store branding images through Cloudinary, but only after a backend verifies the authenticated user and signs the upload parameters.

The Flutter app is already prepared to use this flow when:

- `CLOUDINARY_SIGNED_UPLOAD_ENDPOINT` is set

If the endpoint is not set, the app falls back to the current hardened unsigned upload path.

## Flutter request

The app sends a `POST` request to:

- `CLOUDINARY_SIGNED_UPLOAD_ENDPOINT`

Headers:

- `Content-Type: application/json`
- `Authorization: Bearer <firebase-id-token>`

Body:

```json
{
  "folder": "product_images",
  "ownerId": "vendorUid123",
  "publicId": "premium-kurta-1711478300000",
  "fileName": "kurta.jpg"
}
```

## Allowed folders

The backend should accept only:

- `product_images`
- `store_logos`
- `store_banners`

The backend should reject any other folder value.

## Backend validation rules

The signing backend should:

- verify the Firebase ID token
- require an authenticated user
- verify the user's role is `vendor`, `admin`, or `super_admin`
- ensure a vendor can sign only for their own `ownerId`
- ensure `ownerId` matches the authenticated vendor user ID
- build the final Cloudinary folder as:
  - `product_images/{ownerId}`
  - `store_logos/{ownerId}`
  - `store_banners/{ownerId}`
- sanitize `publicId`
- optionally rate-limit by user ID

## Success response

The backend should return:

```json
{
  "cloudName": "your-cloud-name",
  "apiKey": "123456789012345",
  "timestamp": "1711478300",
  "signature": "signed_hash_here",
  "folder": "product_images/vendorUid123",
  "publicId": "premium-kurta-1711478300000"
}
```

Optional:

```json
{
  "uploadPreset": "abzora_signed_uploads"
}
```

## Error response

Return a non-2xx response with:

```json
{
  "error": "You are not allowed to upload to this folder."
}
```

## Recommended backend implementation

Use one of these:

- Firebase Functions HTTP endpoint
- Cloud Run service
- your existing backend API

Recommended endpoint:

- `POST /cloudinary/sign-upload`

## Recommended Cloudinary signing parameters

The backend should sign:

- `folder`
- `public_id`
- `timestamp`

Optional signed constraints:

- `overwrite=false`
- `resource_type=image`
- moderation or eager transforms if you add them later

## Release plan

1. Keep current hardened unsigned uploads working.
2. Build the signing endpoint.
3. Set:
   - `CLOUDINARY_SIGNED_UPLOAD_ENDPOINT`
4. Validate vendor uploads in staging.
5. Disable unsigned production presets after signed uploads are stable.

## Flutter configuration

To enable signed uploads in Flutter, pass:

```powershell
--dart-define=CLOUDINARY_SIGNED_UPLOAD_ENDPOINT=https://your-domain.com/cloudinary/sign-upload
```

## Current app behavior

The signed flow is already wired in:

- [storage_service.dart](/C:/Users/AAA/Documents/abzio/lib/services/storage_service.dart)

The app now behaves like this:

- if `CLOUDINARY_SIGNED_UPLOAD_ENDPOINT` is set:
  - request a backend signature
  - upload using signed Cloudinary parameters
- otherwise:
  - use the current hardened unsigned upload flow
