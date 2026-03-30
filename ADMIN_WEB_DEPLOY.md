# Admin Web Deploy

## Important Reality

This workspace does not contain a separate React or Next.js admin app.

The admin panel here is part of the Flutter application and is exposed through
the web build, with admin routes such as:

- `/admin-login`
- `/admin`

That means production deployment should target Flutter web, not a separate
React/Next admin folder.

## Backend URL

Use the deployed backend:

```text
https://abzora-backend.onrender.com
```

In this codebase, Flutter uses:

- `BACKEND_BASE_URL` via `--dart-define`

It does not use:

- `REACT_APP_API_URL`
- `NEXT_PUBLIC_API_URL`

## Auth

Admin requests already use Firebase ID tokens through the shared API client.

The client sends:

```http
Authorization: Bearer <firebase_id_token>
```

Backend admin routes are already protected by:

- Firebase token verification
- Mongo user lookup
- admin / super_admin role checks

## Backend Admin Endpoints

Already available on Render:

- `GET /admin/dashboard`
- `GET /admin/users`
- `GET /admin/stores`
- `GET /admin/products`
- `GET /admin/orders`
- `GET /admin/kyc/vendors`
- `GET /admin/kyc/riders`
- `PATCH /admin/kyc/vendors/:id/review`
- `PATCH /admin/kyc/riders/:id/review`

## Vercel Deployment

### Framework

- Framework preset: `Other`

### Build command

```bash
flutter build web --release --dart-define=BACKEND_BASE_URL=https://abzora-backend.onrender.com
```

### Output directory

```text
build/web
```

### Rewrites

`vercel.json` is included so Flutter web routes continue to work on refresh:

- `/admin`
- `/admin-login`

## Suggested Repo Layout

If you want a separate GitHub repo just for admin web deployment, create one
from this workspace only if you are intentionally deploying the Flutter web app
as its own project.

## Production Test Flow

1. Open the deployed Vercel URL
2. Go to `/admin-login`
3. Sign in with a Firebase admin account
4. Verify admin APIs load
5. Verify non-admin accounts are denied by backend role checks

## Honest Status

- Backend role protection: in place
- Firebase token auth: in place
- Flutter admin web routes: in place
- Vercel routing support: added
- Separate React/Next admin app: not present in this repo
