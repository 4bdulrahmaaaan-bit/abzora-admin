# ABZIO Project Analysis

## Project Overview

**ABZIO** is a comprehensive, multi-platform **fashion marketplace application** built with Flutter for mobile/web clients and Node.js/Express for backend services. The system supports multiple user roles (customers, vendors, riders, admins) with features including real-time order tracking, AR try-on capabilities, custom tailoring, and payment integration.

---

## Architecture Overview

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Mobile/Web Frontend** | Flutter 3.11.1 + Dart 3.11+ |
| **Admin Dashboard** | Next.js 14.2 + React 18.3 + TypeScript |
| **Backend** | Node.js 20+ + Express 4.21 |
| **Database** | Firebase Realtime Database, Cloud Firestore, MongoDB (for backend services) |
| **Authentication** | Firebase Auth (Phone OTP) |
| **Payment** | Razorpay |
| **File Storage** | Cloudinary |
| **Maps** | Google Maps Flutter |
| **ML/AI** | Google MLKit (Face Detection), OpenAI integration |
| **AR/3D** | Unity, Flutter Unity Widget, Three.js (Next.js) |
| **Cloud Messaging** | Firebase Cloud Messaging (FCM) |
| **State Management** | Provider, Riverpod (Flutter), React hooks (Next.js) |

---

## Project Structure

### Root Level Files
```
├── README.md                          # Main project documentation
├── package.json                       # Root npm scripts for testing & releases
├── pubspec.yaml                       # Flutter dependencies
├── firebase.json                      # Firebase config (emulators, database rules)
├── vercel.json                        # Vercel deployment config (admin panel)
├── android/, ios/, web/, windows/, linux/, macos/  # Native platform files
└── Documentation Files:
    ├── PRODUCTION_DEPLOY_CHECKLIST.md
    ├── BACKEND_SETUP.md
    ├── STAGING_TEST_MATRIX.md
    ├── RTDB_EMULATOR_VALIDATION.md
    ├── LOG_RETENTION_STRATEGY.md
    ├── ADMIN_WEB_DEPLOY.md
    ├── IOS_HANDOFF.md
    └── [others]
```

### 1. **Flutter Mobile App** (`lib/` and `/lib/main_*.dart`)

#### Structure
```
lib/
├── main.dart                    # Main entry (role-based routing)
├── main_customer.dart           # Customer app entry
├── main_admin.dart              # Admin app entry
├── main_ops.dart                # Operations/Rider app entry
├── app_shell.dart               # App shell configuration
├── firebase_options.dart        # Firebase project config
├── theme.dart                   # Global theming
│
├── config/                      # Configuration & constants
├── constants/                   # App-wide constants
├── core/                        # Core utilities (logging, networking)
├── models/                      # Data models
│   ├── atelier_models.dart
│   ├── ar_try_on_models.dart
│   ├── ar_realtime_try_on_result.dart
│   ├── outfit_recommendation_model.dart
│   ├── trial_session.dart
│   ├── banner_model.dart
│   └── models.dart              # Central model exports
│
├── modules/                     # Feature modules (organized by domain)
│   ├── cart/                    # Shopping cart management
│   ├── categories/              # Category browsing
│   ├── home/                    # Home screen
│   ├── listing/                 # Product listing
│   ├── orders/                  # Order management
│   ├── product/                 # Product details
│   ├── profile/                 # User profiles
│   └── services/                # Feature services (internal)
│
├── screens/                     # UI Screens (organized by role)
│   ├── customer/                # Customer-facing screens
│   ├── vendor/                  # Vendor dashboard & screens
│   │   ├── vendor_dashboard.dart
│   │   ├── product_management.dart
│   │   ├── order_management.dart
│   │   ├── vendor_registration_screen.dart
│   │   ├── store_settings_screen.dart
│   │   └── [others]
│   ├── admin/                   # Admin screens
│   ├── rider/                   # Rider/Delivery screens
│   ├── shared/                  # Shared screens (auth, onboarding)
│   └── [role-specific screens]
│
├── services/                    # Business logic services
│   ├── app_bootstrap_service.dart  # Firebase/Emulator setup
│   ├── auth_service.dart
│   ├── payment_service.dart     # Razorpay integration
│   ├── [others]
│   └── service.dart
│
├── providers/                   # State management (Riverpod)
├── widgets/                     # Reusable UI components
├── shared/                      # Shared utilities & widgets
└── utils/                       # Utility functions
```

#### Key Features
- **Multi-role Support**: Separate entry points for Customer, Admin, and Rider
- **Firebase Integration**: Real-time database for orders, stores, products, notifications
- **AR Try-On**: Unity-based AR clothing try-on (custom Dart-Unity bridge)
- **Payment Integration**: Razorpay for secure payments
- **Real-time Messaging**: Firebase Cloud Messaging for notifications
- **Location Services**: Google Maps, Geolocator, Geocoding
- **Media Handling**: Image picker, camera, Cloudinary uploads

#### Platform Coverage
- Android (fully built in `/android/`)
- iOS (fully built in `/ios/`)
- Web (in `/web/`)
- Windows, Linux, macOS (scaffolding in place)

---

### 2. **Backend API** (`backend/`)

#### Structure
```
backend/
├── server.js                    # Express app entry point
├── package.json                 # Node.js dependencies
├── .env / .env.example          # Configuration
├── serviceAccountKey.json       # Firebase admin credentials
│
├── config/                      # Config files (database, auth, etc.)
├── middleware/                  # Express middleware (auth, validation, etc.)
├── routes/                      # API routes
├── controllers/                 # Business logic (35+ controllers)
│   ├── authController.js        # Auth & user management
│   ├── productController.js     # Product CRUD
│   ├── orderController.js       # Order processing
│   ├── paymentController.js     # Razorpay integration
│   ├── atelierController.js     # Custom tailoring
│   ├── tryOnController.js       # AR try-on backend
│   ├── mlController.js          # ML/AI (face detection, etc.)
│   ├── chatController.js        # Real-time chat
│   ├── kycController.js         # KYC verification
│   ├── analyticsController.js   # Analytics & metrics
│   ├── aiController.js          # AI features (recommendations, etc.)
│   ├── [35+ total controllers]
│   └── [others]
├── models/                      # Mongoose schemas (MongoDB)
├── services/                    # Utility services
├── validation/                  # Input validation (AJV schemas)
├── scripts/                     # Automation scripts
└── tmp/                         # Temporary files
```

#### API Endpoints (Partial)
```
GET    /health                          # Health check
GET    /auth/me                         # Current user info
POST   /stores                          # Create store
GET    /stores                          # List stores
GET    /stores/:id                      # Get store details
POST   /products                        # Create product
GET    /products                        # List products
GET    /products/:id                    # Get product details
POST   /orders                          # Create order
GET    /orders                          # List orders
POST   /orders/create-razorpay-order   # Razorpay integration
POST   /orders/verify-payment          # Payment verification
POST   /upload                          # File upload (Cloudinary)
[... 100+ endpoints across multiple domains]
```

#### Database
- **MongoDB**: Primary production database (Mongoose ODM)
- **Firebase Realtime Database**: Real-time data syncing
- **Firebase Firestore**: Additional document storage
- **Redis**: Rate limiting (optional, recommended for production)

#### Key Features
- Express middleware stack (CORS, auth validation, logging)
- Firebase Admin SDK for auth verification
- Cloudinary integration for image uploads
- Razorpay for payment processing
- Mongoose for MongoDB ORM
- WebSocket support (ws library)
- Cron jobs (node-cron) for scheduled tasks
- ML integration (OpenAI, Google MLKit)

#### Deployment
- **Render**: Primary deployment platform
- **Environment variables**: Firebase credentials, API keys, database URLs
- **HTTPS enforcement** in production

---

### 3. **Admin Dashboard** (`admin-next/`)

#### Structure
```
admin-next/
├── package.json                 # Next.js + React + TypeScript
├── next.config.js              # Next.js configuration
├── tsconfig.json               # TypeScript config
├── next-env.d.ts               # Next.js type definitions
│
├── app/                         # Next.js 13+ App Router
│   ├── globals.css             # Global styles
│   ├── layout.tsx              # Root layout
│   ├── page.tsx                # Home page
│   ├── products/               # Products management
│   ├── roles/                  # Role-based dashboards
│   ├── templates/              # Templates (AR, tailoring, etc.)
│   └── versions/               # Version management
│
├── components/                 # React components
└── lib/                        # Utilities & helpers
```

#### Tech Stack
- **Next.js 14.2**: Full-stack React framework
- **React 18.3**: UI library
- **TypeScript**: Type safety
- **Three.js & React Three Fiber**: 3D visualization (AR templates, etc.)
- **Vercel**: Deployment platform

#### Port
- Runs on **port 3100**

---

### 4. **Unity AR Components** (`unity/` and `packages/flutter_unity_widget/`)

- Custom Flutter-Unity bridge for real-time AR try-on
- 3D clothing models and avatar rendering
- Face detection integration
- Customizable parameter passing between Flutter and Unity

---

### 5. **Firebase Configuration**

#### Emulators
```
firebase emulators:start --only auth,database
```
- **Auth Emulator**: Port 9099
- **Database Emulator**: Port 9000
- **UI**: Enabled for testing

#### Rules & Security

**Database Rules** (`database.rules.json`):
- Role-based access control (Customer, Vendor, Rider, Admin)
- Customers: Can only access own orders, measurements, wishlist
- Vendors: Can manage own store and products
- Riders: Can access assigned orders only
- Admin: Full access

**Firestore Rules** (`firestore.rules`)
**Storage Rules** (`storage.rules`)

---

## Data Models & Domain Structure

### Core Collections (Firebase RTDB)

#### `users/{uid}`
```json
{
  "id": "firebase-uid",
  "name": "User Name",
  "email": "user@example.com",
  "phone": "+91...",
  "role": "user|vendor|rider|admin|super_admin",
  "isActive": true,
  "storeId": "store-id-for-vendors",
  "walletBalance": 0,
  "fcmToken": "device-token"
}
```

#### `stores/{storeId}`
```json
{
  "id": "store-id",
  "ownerId": "vendor-uid",
  "name": "Store Name",
  "description": "...",
  "imageUrl": "...",
  "rating": 4.8,
  "reviewCount": 124,
  "address": "...",
  "isApproved": false,
  "isActive": false,
  "commissionRate": 0.12,
  "walletBalance": 0
}
```

#### `products/{productId}`
```json
{
  "id": "product-id",
  "storeId": "store-id",
  "name": "Product Name",
  "description": "...",
  "price": 999,
  "images": ["..."],
  "sizes": ["S", "M", "L", "XL"],
  "stock": 50,
  "category": "category-name",
  "isCustomTailoring": false,
  "outfitType": "dress",
  "fabric": "cotton"
}
```

#### `orders/{orderId}`
```json
{
  "id": "order-id",
  "userId": "customer-uid",
  "storeId": "store-id",
  "riderId": "rider-uid",
  "items": [...],
  "totalAmount": 5000,
  "status": "Pending|Confirmed|Shipped|Delivered|Cancelled",
  "deliveryStatus": "Not Started|In Transit|Delivered",
  "payoutStatus": "Pending|Processed",
  "vendorEarnings": 4000,
  "createdAt": "timestamp",
  "paymentMethod": "razorpay"
}
```

#### Other Collections
- `measurements/{uid}/*` - User body measurements for tailoring
- `wishlist/{uid}/*` - Saved favorite products
- `notifications/*` - System notifications (role-based)
- `chats/*` - Real-time messaging
- `reviews/*` - Product reviews
- `payouts/*` - Vendor payouts
- `activityLogs/*` - Admin audit trail
- `categories/*` - Product categories

---

## Feature Breakdown

### 1. **Customer Features**
- Browse products by category
- Search and filter
- **AR Try-On**: Real-time virtual try-on using Unity
- Shopping cart (enforced single-store)
- Checkout with Razorpay payment
- Order tracking with real-time updates
- Custom tailoring orders
- Measurements management
- Wishlist management
- Product reviews
- Real-time chat with vendors
- Voice assistant integration
- Video feed recommendations
- Push notifications

### 2. **Vendor Features**
- Store registration and KYC verification
- Product catalog management
- Custom tailoring product setup
- Order management & fulfillment
- Real-time order notifications
- Store analytics & metrics
- Payout management
- Customer communication
- Store settings & branding

### 3. **Rider/Logistics Features**
- Order assignment notifications
- Real-time delivery tracking
- GPS location sharing
- Order status updates
- Delivery completion confirmation

### 4. **Admin Features**
- Dashboard with analytics
- Vendor approval & management
- Product oversight
- Order management & dispute resolution
- Platform configuration
- Payout processing
- Activity logging
- System monitoring

### 5. **Cross-Platform Features**
- **Real-time Database**: Instant updates across all clients
- **Push Notifications**: Role-based messaging
- **Payment Processing**: Razorpay integration
- **Media Management**: Cloudinary uploads
- **AR/3D**: Unity-based try-on and visualization
- **AI Features**: Face detection, outfit recommendations, chat

---

## Development Workflows

### Local Development Setup

#### 1. Flutter App
```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File .\scripts\run_local_validation.ps1
flutter analyze
flutter test
```

#### 2. Firebase Emulators
```powershell
firebase emulators:start --only auth,database
```

#### 3. Backend
```bash
cd backend
npm install
npm run dev  # Runs on default port with nodemon
```

#### 4. Admin Dashboard
```bash
cd admin-next
npm install
npm run dev  # Runs on port 3100
```

### Testing

#### Flutter Tests
```powershell
flutter test                # Run all tests
```

#### RTDB Rules Tests
```bash
npm run test:rtdb-rules
npm run test:rtdb-rules:emulator  # Against emulator
```

---

## Production Deployment

### Firebase
- Deploy database rules via Firebase CLI
- Configure storage rules
- Set up emulator validation before production release

### Backend (Render)
```bash
Build: npm install
Start: npm start
Environment: Firebase credentials via env vars (not JSON file)
```

### Admin Dashboard (Vercel)
```bash
Build: next build
Start: next start (port 3100)
```

### Security Checklist
- ✅ Phone Auth enabled in Firebase Console
- ✅ Authorized domains configured
- ✅ Database rules validated with emulators
- ✅ Environment variables for all secrets
- ✅ HTTPS enforcement in production
- ✅ Firebase rate limiting configured
- ✅ Test auth routes disabled in non-local environments

---

## Key Documentation Files

| File | Purpose |
|------|---------|
| [README.md](README.md) | Main project overview & quick start |
| [PRODUCTION_DEPLOY_CHECKLIST.md](PRODUCTION_DEPLOY_CHECKLIST.md) | Pre-deployment validation checklist |
| [BACKEND_SETUP.md](BACKEND_SETUP.md) | Backend configuration & Firebase schema |
| [STAGING_TEST_MATRIX.md](STAGING_TEST_MATRIX.md) | Testing matrix for staging releases |
| [RTDB_EMULATOR_VALIDATION.md](RTDB_EMULATOR_VALIDATION.md) | Firebase rules validation scenarios |
| [LOG_RETENTION_STRATEGY.md](LOG_RETENTION_STRATEGY.md) | Log management & archival |
| [ADMIN_WEB_DEPLOY.md](ADMIN_WEB_DEPLOY.md) | Admin dashboard deployment guide |
| [IOS_HANDOFF.md](IOS_HANDOFF.md) | iOS-specific handoff features |
| [CLOUDINARY_SIGNED_UPLOAD_SPEC.md](CLOUDINARY_SIGNED_UPLOAD_SPEC.md) | File upload configuration |
| [MIGRATION_AUDIT.md](MIGRATION_AUDIT.md) | Data migration tracking |

---

## Important Directories

| Directory | Purpose |
|-----------|---------|
| `/assets/` | Images, AR models, ML models, branding, 3D files, Lottie animations |
| `/android/`, `/ios/` | Native platform-specific code |
| `/functions/` | Firebase Cloud Functions (if deployed) |
| `/build/` | Build artifacts (compiled packages) |
| `/scripts/` | Automation scripts (release, validation, archival) |
| `/test/` | Flutter unit and integration tests |
| `/packages/flutter_unity_widget/` | Custom Flutter-Unity bridge package |
| `/unity/` | Unity project files (AR try-on) |
| `/mongo-backup/` | Database backups |

---

## Key Technologies Summary

| Category | Technologies |
|----------|---------------|
| **Frontend** | Flutter, Dart, React, Next.js, TypeScript |
| **Backend** | Node.js, Express, MongoDB, Mongoose |
| **Real-time** | Firebase RTDB, Firebase Messaging, WebSockets |
| **Authentication** | Firebase Auth (Phone OTP) |
| **Payments** | Razorpay |
| **File Storage** | Cloudinary, Firebase Storage |
| **ML/AI** | Google MLKit, OpenAI, Custom ML models |
| **3D/AR** | Unity, Three.js, Custom Flutter-Unity bridge |
| **Maps & Location** | Google Maps, Geolocator, Geocoding |
| **State Management** | Provider, Riverpod (Flutter), React Hooks |
| **Deployment** | Firebase, Render, Vercel |

---

## Next Steps & Recommendations

1. **Review Database Rules**: Validate all access control patterns in `database.rules.json`
2. **Test AR Features**: Ensure Unity bridge is properly configured
3. **Backend Security**: Verify environment variables and API key handling
4. **Deployment Pipeline**: Set up CI/CD for automated testing before release
5. **Documentation**: Keep deployment docs updated as features evolve

