# API and Auth

Authentication:
- Firebase ID token verification in auth middleware
- Token propagated by clients via Bearer Authorization

Authorization:
- Role checks for `admin`, `super_admin`, `vendor`, `rider`
- Admin-critical domains guarded at route level (`/admin`, `/ops`, selected metrics)

Route architecture:
- Domain routes in `backend/routes/*`
- Validation middleware (`backend/validation/*`) enforces payload schemas
