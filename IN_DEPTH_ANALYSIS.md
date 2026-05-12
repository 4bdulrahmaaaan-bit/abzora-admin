# ABZIO In-Depth Technical Analysis

## Executive Summary

ABZIO is a sophisticated, multi-layered fashion marketplace with complex business logic spanning:
- **42 Backend controllers** managing distinct domains (35+ route files)
- **60+ MongoDB Mongoose models** with financial, operational, and ML-driven features
- **Role-based access control** across 6+ user roles (customer, vendor, rider, admin, designer, QA)
- **Real-time infrastructure** combining Firebase RTDB + MongoDB + Redis caching
- **11 Riverpod providers** managing Flutter state across 81+ screens
- **AR/3D capabilities** with custom Unity-Flutter bridge + Three.js admin visualization
- **ML/AI integration** including bandit algorithms, fraud detection, and outfit recommendations

---

## Architecture Analysis

### 1. **Layered Architecture Pattern**

```
┌─────────────────────────────────────────────────────────┐
│  Flutter Mobile App (Dart)                              │
│  - Multi-role entry points (main_customer/vendor/admin) │
│  - 11 Riverpod providers for state management           │
│  - 80+ screens organized by role                        │
└────────────────┬────────────────────────────────────────┘
                 │
         ┌───────┴────────┬──────────────┐
         │                │              │
    Firebase RTDB    MongoDB Backend   Next.js Admin
    (Real-time)    (Persistent)      (3D Dashboard)
         │                │              │
         └───────┬────────┴──────────────┘
                 │
    ┌────────────┴────────────────┐
    │  42 Backend Controllers     │
    │  40+ Backend Services       │
    │  60+ Mongoose Models        │
    │  3x Middleware Layers       │
    └────────────────────────────┘
```

### 2. **Multi-Role Routing Strategy**

**Flutter** implements 4 separate entry points:
```dart
main.dart                    // Unified (role selector)
main_customer.dart          // Customer-specific
main_admin.dart             // Admin-specific
main_ops.dart               // Rider/Operations
```

**Backend** enforces role authorization through:
```javascript
authMiddleware              // Verify Firebase token
authorizationMiddleware    // Role-based access (requireAdmin, requireVendor, requireRider)
securityMiddleware         // CORS, headers, rate limiting
```

### 3. **Data Persistence Strategy**

| Layer | Storage | Purpose |
|-------|---------|---------|
| **Real-time** | Firebase RTDB | Orders, notifications, measurements (100+ ms latency tolerance) |
| **Persistent** | MongoDB | User profiles, products, transactions, audit logs |
| **Cache** | Redis | Rate limiting, session tokens (optional production) |
| **Local** | SharedPreferences | Device preferences, theme, auth tokens (Flutter) |

---

## Security Deep Dive

### 1. **Authentication Flow**

```
Flutter App
    ↓ (Firebase Phone OTP)
Firebase Auth
    ↓ (ID Token)
Backend /auth/me endpoint
    ↓ (Verify Firebase token via Firebase Admin SDK)
MongoDB User Upsert (if not exists)
    ↓ (Serialize user with roles)
Session established (JWT in cookies or Bearer token)
```

**Key Security Measures:**
- ✅ Firebase Auth (no password exposure)
- ✅ Phone OTP verification
- ✅ Admin email allowlist (`ALLOWED_ADMIN_EMAILS`)
- ✅ Role normalization (prevents injection)
- ✅ User deserialization with role maps

**Potential Concerns:**
- ⚠️ Firebase Admin credentials in environment (not JSON file in prod) — **Well handled**
- ⚠️ Token expiration logic — **Not explicitly shown, verify in authMiddleware**
- ⚠️ Session fixation — **Verify token rotation on role changes**

### 2. **Firebase RTDB Security Rules Analysis**

#### **Strengths:**
- ✅ Granular role-based rules (Customer, Vendor, Rider, Admin)
- ✅ Immutable field protection (e.g., can't modify `storeId` post-creation)
- ✅ Vendor store isolation (can only manage own store)
- ✅ Order state machine enforcement (Placed → Confirmed → Packed → etc.)
- ✅ Idempotency key validation prevents duplicate orders
- ✅ Payment verification required for non-COD orders

#### **Complexity Issues:**
- ⚠️ **Rules are extremely verbose** (200+ lines for `orders` alone)
- ⚠️ **Rules are NOT readable** — Multiple nested conditions make debugging difficult
- ⚠️ **No rule composition** — Repeated patterns for vendor/rider/admin checks
- ⚠️ **State transitions hardcoded** — Can't easily add new order statuses without rule changes
- ⚠️ **ETA field in orders write rule** — Not validated (could bypass frontend)

#### **Recommended Refactoring:**
```javascript
// Extract common patterns
function isAdmin() { return root.child('users').child(auth.uid).child('role').val() === 'admin'; }
function isVendor() { return root.child('users').child(auth.uid).child('role').val() === 'vendor'; }

// Extract order write validation
function isValidOrderTransition(oldStatus, newStatus) {
  return (oldStatus === 'Placed' && newStatus === 'Confirmed')
      || (oldStatus === 'Confirmed' && newStatus === 'Shipped');
}
```

### 3. **Backend Security Layers**

#### **Middleware Stack:**
```javascript
// middleware/securityMiddleware.js
- CORS validation (configurable origins)
- Security headers (X-Content-Type-Options: nosniff, X-Frame-Options: DENY)
- HTTPS enforcement (enforceHttps middleware)
- Request context (request ID, timing)
- Request audit logging (all requests logged)
- Razorpay webhook raw body parsing (prevents signature tampering)
- Rate limiting (configurable per endpoint)
  - Auth endpoint: 25 attempts per 15 minutes
  - Order endpoint: (configurable)
  - Webhook endpoint: (configurable)
```

#### **Rate Limiting Strategy:**
```javascript
// Key generation: `auth:${clientIp}:${email || phone || 'anon'}`
// Uses client IP for guest flows
// Uses email/phone for authenticated flows
```

**Concern:** If multiple users behind same corporate proxy, they share rate limit quota.

#### **Authorization Middleware:**
```javascript
requireAdmin  // Only super_admin or admin
requireVendor // Only vendor role + own store verification
requireRider  // Only rider role
```

### 4. **Data Validation**

**Backend uses AJV (Another JSON Schema Validator):**
- ✅ Type checking (string, number, array, object)
- ✅ Format validation (email, URI, phone)
- ✅ Custom schemas for complex types (measurements, garment templates)
- ✅ AJV with formats plugin enabled

**Issue:** Validation schemas are split across multiple files — no central registry visible.

---

## Backend Architecture Deep Dive

### 1. **Service Layer Organization (40+ Services)**

| Category | Services | Purpose |
|----------|----------|---------|
| **Payment** | `razorpayPayoutService`, `financeService` | Payment processing, settlement |
| **ML/AI** | `mlBanditService`, `fraudDetectionService` | Experience optimization, fraud prevention |
| **Logistics** | `dispatchEngineService`, `trackingGateway`, `etaService` | Order routing, ETA calculation |
| **Caching** | `redisCacheService` | Session/rate limit caching |
| **Operations** | `opsRuntimeService`, `opsMetricsService` | Ops workflow automation |
| **Pricing** | `pricingGateway`, `pricingConfigService` | Dynamic pricing |
| **Audit** | `auditLogger`, `financeService` | Security & compliance logging |

### 2. **Controller Organization (42 Controllers)**

**By Domain:**
- Auth: `authController`
- Products: `productController`, `garmentTemplateController`
- Orders: `orderController`, `dispatchController`
- Payment: `paymentController`, `cardController`
- Vendors: `storeController`, `vendorController`, `customVendorController`
- Riders: `riderController`, `trackingController`
- AI: `aiController`, `mlController`, `supportAiService`
- Analytics: `analyticsController`
- Atelier (Custom Tailoring): `atelierController`
- AR: `tryOnController`, `arRoutes`
- Other: 20+ specialized domains

### 3. **Database Model Complexity (60+ Models)**

**Core Models:**
```
User, Store, Product, Order, Review
```

**Financial Models:**
```
Transaction, FinanceAuditLog, AdminPayout, VendorWallet, RiderWallet
VendorKycRequest, RiderKycRequest, RefundRequest, WithdrawalRequest
```

**ML/AI Models:**
```
ExperienceControl, ExperienceLog, AiEventLog, AiUsageLog, UserAiUsageStat
MLBanditState, FraudAlert
```

**Operational Models:**
```
DeliveryTask, DispatchBatch, DispatchSchedulerService
OpsActionLog, OpsAlert, OpsMetricsSnapshot
```

**AR/Fashion Models:**
```
GarmentTemplate, GarmentConfig, ArTryOnLook
MeasurementProfile, FitProfile
```

**Advanced Features:**
```
TrialHomeSession, TryOnSession, GrowthOffer, CommunityPost
LookShare, InfluencerLook, SupportChat, ChatHistory
```

---

## State Management Analysis

### Flutter: Riverpod Providers (11)

```dart
auth_provider.dart              // User authentication state
cart_provider.dart              // Shopping cart (single-store enforced)
product_provider.dart           // Product browsing state
chat_provider.dart              // Real-time messaging
wishlist_provider.dart          // Saved products
location_provider.dart          // GPS & address
network_provider.dart           // Connectivity checking
theme_provider.dart             // UI theme state
banner_provider.dart            // Promotional banners
atelier_flow_provider.dart      // Custom tailoring workflow
trial_home_provider.dart        // Trial session management
```

### Issues:
- ⚠️ **Limited provider coverage** — Only 11 providers for 80+ screens
- ⚠️ **Potential state scaling issues** — Large providers may cause unnecessary rebuilds
- ⚠️ **No evidence of Ref.watch optimization** — Could benefit from `.select()`

### Next.js Admin: React Hooks
- State in component-level hooks (standard pattern)
- Redux or Context not implemented (might scale poorly with complex dashboards)

---

## Real-time & Messaging Architecture

### 1. **Firebase Cloud Messaging (FCM)**
**Path in RTDB:** `notifications/{notificationId}`

**Role-based routing:**
```json
{
  "userId": "specific-user",     // For customer/rider notifications
  "storeId": "vendor-store",     // For vendor notifications
  "audienceRole": "admin|rider|all",  // For broad notifications
  "timestamp": "ISO-8601",
  "title": "Order Update",
  "body": "Your order is ready"
}
```

**Queries supported:**
- `orderByChild('userId')` — Single user notifications
- `orderByChild('storeId')` — Store-specific notifications
- `orderByChild('audienceRole')` — Broadcast notifications

### 2. **WebSocket Support**
- Backend includes `ws` library for real-time chat
- Path: `chatHistory/{uid}/{chatId}/{messageId}`

---

## Data Flow Examples

### **Order Creation Flow:**

```
1. Flutter App
   ├─ User selects products
   ├─ Validates single-store constraint
   └─ Initiates checkout

2. Razorpay Payment
   ├─ Frontend creates order via Razorpay SDK
   ├─ User completes payment
   └─ Receives payment_id, order_id, signature

3. Backend Verification
   ├─ POST /orders/create-razorpay-order
   ├─ Verify Firebase token
   ├─ Verify Razorpay signature (HMAC-SHA256)
   ├─ Create MongoDB Order document
   └─ Write to Firebase RTDB (orders/{orderId})

4. Real-time Updates
   ├─ Vendor receives FCN notification (Firebase Messaging)
   ├─ Rider receives assignment FCN
   └─ Customer receives order status FCN

5. Order Lifecycle
   Placed → Confirmed → Packed → Ready for Pickup
        → Picked Up → Out for Delivery → Delivered
```

### **Custom Tailoring Order:**

```
1. Customer creates tailored product
   ├─ Select measurements (via MeasurementProfile)
   ├─ Choose customizations (fabric, fit adjustments)
   ├─ Set "neededBy" date
   └─ Add tailoring_extra_cost

2. Vendor receives order with:
   ├─ Order.tailoringDeliveryMode (express/standard)
   ├─ Order.measurementProfileLabel
   ├─ Product.customizations[]
   └─ Timestamp for SLA tracking

3. AI/ML Intervention:
   ├─ Fit prediction (via MLBanditService)
   ├─ Return risk scoring
   ├─ Fraud detection (via fraudDetectionService)
   └─ Recommendation to customer

4. Settlement:
   ├─ Platform takes 12% commission (configurable)
   ├─ Vendor receives 88% + tailoring cost
   └─ Payout processed weekly (configurable)
```

---

## ML/AI Features

### 1. **Multi-Armed Bandit (MLBandit)**

**Purpose:** Optimize customer experience through contextual recommendations

**Features input:**
```javascript
{
  fitConfidence,        // How confident is the fit prediction?
  returnRate,           // Historical return rate
  sessionDepth,         // Pages browsed in session
  sameDayAvailable,     // Is same-day delivery available?
  productFitRisk,       // Risk score for product fit
  userType              // Customer segment
}
```

**Decision output:**
```javascript
{
  action: "UPSELL|RECOMMEND|HOLD|TRIAL",
  armId: "arm-123",
  epsilon: 0.15,        // 15% exploration vs exploitation
  confidence: 0.87
}
```

### 2. **Fraud Detection**

**Path:** `fraudLogs/{logId}`

**Scoring factors:**
- Refund request ratio
- Rapid repurchase patterns
- Geographic anomalies
- Payment method variations

### 3. **Outfit Recommendation Engine**

**Path:** `outfitEngine.js`

**ML inputs:**
- User browsing history
- Previous purchases
- Wishlist items
- Similar users' preferences

---

## Deployment & Infrastructure

### 1. **Local Development**

**Firebase Emulator Suite:**
```bash
firebase emulators:start --only auth,database
```

**Ports:**
- Auth Emulator: 9099
- RTDB Emulator: 9000
- Emulator UI: 4000

**Environment config:**
```dart
// lib/services/app_config.dart
useFirebaseEmulators: true
firebaseEmulatorHost: "127.0.0.1"
firebaseAuthEmulatorPort: 9099
firebaseDbEmulatorPort: 9000
```

### 2. **Production Deployment**

#### **Backend (Render)**
```
Build: npm install
Start: npm start
Port: 5000 (configurable via PORT env var)
Database: MongoDB Atlas (requires IP allowlist)
Cache: Redis (optional, for rate limiting)
```

#### **Admin Dashboard (Vercel)**
```
Build: next build
Start: next start -p 3100
Deployment: Direct from Git (auto-deploy on push)
```

#### **Flutter App (Native)**
```
Android: Built to /android/app/build/outputs/apk/
iOS: Built to /ios/build/Release-iphoneos/
Web: Not primary platform (scaffolding exists)
```

### 3. **Environment Variables**

**Backend Requirements:**
```
MONGO_URI              # MongoDB connection string
FIREBASE_PROJECT_ID    # Firebase project ID
FIREBASE_CLIENT_EMAIL  # Firebase service account email
FIREBASE_PRIVATE_KEY   # Firebase private key (base64 encoded)
RAZORPAY_KEY           # Public key
RAZORPAY_SECRET        # Secret key
RAZORPAY_WEBHOOK_SECRET # Webhook signing secret
CLOUDINARY_NAME        # Cloudinary account
CLOUDINARY_KEY         # API key
CLOUDINARY_SECRET      # API secret
OPENAI_API_KEY         # OpenAI/ChatGPT integration
GOOGLE_MAPS_API_KEY    # Maps API (Flutter + Backend)
ALLOWED_ADMIN_EMAILS   # Comma-separated admin emails
REDIS_URL              # Redis for rate limiting
CLIENT_ORIGIN          # CORS allowed origins
ENFORCE_HTTPS          # Force HTTPS in production
NODE_ENV               # production/development
```

**Flutter Requirements:**
```
RAZORPAY_KEY           # Razorpay public key (dart-define)
GOOGLE_MAPS_API_KEY    # Maps key (dart-define)
USE_FIREBASE_EMULATORS # Local dev flag
FIREBASE_EMULATOR_HOST # Emulator URL
```

---

## Performance & Scalability Analysis

### 1. **Firebase RTDB Considerations**

**Strengths:**
- ✅ Sub-500ms latency for real-time updates
- ✅ Built-in indexes for common queries
- ✅ Automatic replication (high availability)

**Limitations:**
- ⚠️ No transactions across paths
- ⚠️ No aggregation queries (must do in client/backend)
- ⚠️ 32 levels maximum nesting (ABZIO respects this)
- ⚠️ Query complexity O(n) if no index

**ABZIO RTDB Indexes:**
```json
{
  "users": ["role", "storeId", "riderApprovalStatus"],
  "stores": ["ownerId", "isApproved", "city"],
  "products": ["storeId", "category", "createdAt"],
  "orders": ["userId", "storeId", "riderId", "status"],
  "notifications": ["userId", "audienceRole"]
}
```

### 2. **MongoDB Performance**

**Key Indexes Needed:**
```javascript
// User lookups
db.users.index({ firebaseUid: 1 })
db.users.index({ email: 1 })
db.users.index({ phone: 1 })

// Order queries
db.orders.index({ userId: 1, createdAt: -1 })
db.orders.index({ storeId: 1, status: 1 })
db.orders.index({ riderId: 1 })

// Product searches
db.products.index({ storeId: 1, category: 1 })
db.products.index({ name: "text" })  // Full-text search
```

**Warning:** No visible index configuration file — indexes may not be optimized!

### 3. **Rate Limiting Strategy**

**Current Implementation:**
```javascript
createRateLimiter({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 25,                    // 25 requests per window
  keyGenerator: clientIp      // By IP (with email/phone for auth)
})
```

**Issues:**
- ⚠️ In-memory limiter (resets on server restart)
- ⚠️ Doesn't scale to multiple instances (no Redis by default)
- ⚠️ Single-window strategy (all requests equal weight)

**Recommendation:** Use Redis limiter in production

### 4. **Image Optimization**

**Cloudinary Integration:**
```javascript
// backend/config/cloudinary.js
cloudinary.config({
  cloud_name: env.CLOUDINARY_NAME,
  api_key: env.CLOUDINARY_KEY,
  api_secret: env.CLOUDINARY_SECRET
})
```

**Storage Rules Enforce:**
- Max file size: 10 MB
- Allowed types: image/* only
- Paths: product_images/, store_logos/, store_banners/

---

## Potential Issues & Tech Debt

### 1. **Critical Issues**

| Issue | Impact | Priority |
|-------|--------|----------|
| **RTDB rules overly complex** | Hard to maintain, audit, debug | 🔴 HIGH |
| **No MongoDB index configuration visible** | Poor query performance at scale | 🔴 HIGH |
| **Rate limiter in-memory only** | Distributed requests bypass limits | 🔴 HIGH |
| **Firebase credentials in env vars** | Requires careful DevOps setup | 🔴 HIGH |
| **Payment webhook signature validation** | If skipped = payment fraud risk | 🔴 HIGH |

### 2. **Moderate Issues**

| Issue | Impact | Priority |
|-------|--------|----------|
| **Validation schemas not centralized** | Hard to discover & maintain | 🟡 MEDIUM |
| **Error handling inconsistent** | Some errors swallowed silently | 🟡 MEDIUM |
| **Cart single-store constraint enforced in app** | Backend should also enforce | 🟡 MEDIUM |
| **No query result pagination** | Could load entire collections | 🟡 MEDIUM |
| **Middleware order critical** | Express middleware order matters | 🟡 MEDIUM |

### 3. **Optimization Opportunities**

| Opportunity | Benefit |
|-------------|---------|
| Implement field-level Riverpod `.select()` | Reduce Flutter rebuilds 30-40% |
| Add MongoDB aggregation pipeline | Complex queries 10x faster |
| Redis caching for product lists | Response times from 500ms → 50ms |
| GraphQL for flexible queries | Eliminate over/under-fetching |
| Implement circuit breakers for external APIs | Graceful degradation |

---

## Feature-Specific Analysis

### 1. **AR Try-On System**

**Components:**
```
Flutter ← → Unity Bridge ← → 3D Models
  ↓
Face Detection (Google MLKit)
  ↓
Pose Estimation (MediaPipe)
  ↓
Garment Overlay
  ↓
AR Session stored in Firebase
```

**Potential Issues:**
- ⚠️ No visible error handling for AR initialization failures
- ⚠️ Custom Flutter-Unity bridge could have memory leaks
- ⚠️ 3D model loading not cached (network dependent)

### 2. **Custom Tailoring Workflow**

**State Machine:**
```
MeasurementProfile
    ↓
CustomProduct (with tailoringDeliveryMode)
    ↓
Order with SLA (neededBy date)
    ↓
Vendor Fulfillment Tracking
    ↓
Express/Standard Delivery
    ↓
Completion + Review
```

**Financial Logic:**
```javascript
// Order settlement
platformCommission = totalAmount × 0.12  // 12% default
vendorEarnings = totalAmount - platformCommission
tailoringExtraCost = vendor-defined
finalVendorPayout = vendorEarnings + tailoringExtraCost
```

### 3. **Fraud Detection & Refunds**

**Fraud Scoring:**
```
Score inputs:
- refundRequestRatio (historical returns)
- rapidRepurchasePattern (same item multiple times)
- geographicAnomaly (delivery location vs purchase location)
- paymentMethodVariation (different cards/wallets)
- order_value vs user_average (outlier detection)

Decision:
- score > 0.8: BLOCK order
- score 0.5-0.8: REQUEST verification
- score < 0.5: APPROVE
```

**Refund Flow:**
```
RefundRequest
  ↓
Admin review + fraud scoring
  ↓
ApprovalDecision (approve/reject)
  ↓
VendorWallet balance adjustment
  ↓
CustomerRefundProcessing
```

---

## Code Quality & Testing

### 1. **Flutter Testing**

**Test Coverage Areas (from /test):**
```
✅ Role routing & restrictions
✅ Cart single-store enforcement
✅ Model copyWith safety
✅ App smoke boot
```

**Gaps:**
- ⚠️ No integration tests with backend
- ⚠️ No AR feature tests
- ⚠️ No payment flow tests
- ⚠️ No Firebase RTDB tests

### 2. **Backend Testing**

**RTDB Rules Testing:**
```bash
npm run test:rtdb-rules
npm run test:rtdb-rules:emulator
```

**Available:**
- ✅ RTDB rule validation via Firebase Rules Unit Testing
- ⚠️ No visible backend API unit tests
- ⚠️ No controller tests
- ⚠️ No integration tests

### 3. **Analysis & Linting**

**Flutter:**
```bash
flutter analyze
```

**Backend:**
- ⚠️ No ESLint config visible
- ⚠️ No Prettier enforcement
- ⚠️ No TypeScript (using plain JS)

---

## Recommendations

### Immediate Actions (Week 1)

1. **Refactor RTDB Rules**
   - Extract common functions (isAdmin, isVendor, etc.)
   - Add inline documentation
   - Create rule composition library

2. **Add MongoDB Indexes**
   - Create `scripts/createIndexes.js`
   - Document index strategy
   - Add to deployment pipeline

3. **Enable Redis Rate Limiting**
   - Configure Redis URL in .env
   - Test distributed rate limiting
   - Remove in-memory fallback after validation

4. **Add Backend Tests**
   - Unit tests for payment verification
   - Integration tests for order flow
   - API contract tests

### Mid-term Actions (Month 1)

5. **Optimize Riverpod State**
   - Add `.select()` for field-level updates
   - Reduce provider scope
   - Implement caching logic

6. **Implement GraphQL**
   - Replace REST endpoints for complex queries
   - Reduce payload sizes 20-30%
   - Add query complexity analysis

7. **Add Circuit Breakers**
   - For Razorpay API calls
   - For Cloudinary uploads
   - For Firebase operations

8. **Documentation**
   - API endpoint documentation (Swagger/OpenAPI)
   - RTDB schema documentation
   - Deployment runbooks

### Long-term Actions (Q2+)

9. **Multi-region Deployment**
   - Add CDN for static assets
   - Replicate MongoDB to secondary region
   - Implement geo-routing

10. **Advanced Caching**
    - Implement Redis caching for product lists
    - Add cache invalidation strategy
    - Measure cache hit rates

11. **Performance Monitoring**
    - Add APM (Application Performance Monitoring)
    - Dashboard for key metrics
    - Alert thresholds for anomalies

12. **Security Hardening**
    - Implement request signing for webhooks
    - Add rate limiting by user tier
    - Implement WAF (Web Application Firewall)

---

## Summary Table

| Area | Status | Risk |
|------|--------|------|
| **Architecture** | Well-layered | Low |
| **Authentication** | Firebase Auth (solid) | Low |
| **Authorization** | Role-based (complex rules) | High |
| **Database** | Hybrid (RTDB + MongoDB) | Medium |
| **Real-time** | Firebase Messaging | Low |
| **Payments** | Razorpay (secure) | Low |
| **ML/AI** | Bandit + Fraud detection | Medium |
| **Testing** | Minimal coverage | High |
| **Deployment** | Render + Vercel + Native | Medium |
| **Scalability** | Needs indexing + caching | High |
| **Security** | Good practices, some gaps | Medium |
| **Documentation** | Comprehensive but scattered | Medium |

