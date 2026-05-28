# Authentication Session Validation Matrix

This matrix is for manual verification of the production-hardened auth/session flow across the customer, vendor, rider, and admin apps.

## Scope

- Persistent login after app restart, backgrounding, sleep, and network reconnect
- Silent token refresh before expiry
- Retry-once behavior for protected API calls
- Offline resilience without forced logout
- Session restore on cold startup
- Logout revocation and multi-device behavior

## Preconditions

- Backend session endpoints are deployed and reachable
- Firebase auth is configured in the target environment
- Secure storage is available on the device/emulator
- Test accounts exist for each role:
  - Customer
  - Vendor
  - Rider
  - Admin

## Validation Matrix

| Scenario | Apps | Steps | Expected Result |
|---|---|---|---|
| Fresh sign-in | Customer, Vendor, Rider, Admin | Sign in, then relaunch the app | User returns to the signed-in state without being sent back to login |
| Cold start restore | Customer, Vendor, Rider, Admin | Force-close the app, reopen it | Session restores from secure storage and the UI lands on the correct home route |
| Idle for 1+ hour | Customer, Vendor, Rider, Admin | Leave the app idle or backgrounded for 60+ minutes, then return | Session remains valid or refreshes silently, with no login flash |
| Device sleep/wake | Customer, Vendor, Rider, Admin | Lock the device, wait several minutes, then unlock | App resumes on the current screen and session remains intact |
| Network reconnect | Customer, Vendor, Rider, Admin | Disable network, attempt a protected action, then reconnect | App shows offline/retry state, then recovers silently after connectivity returns |
| Token near expiry | Customer, Vendor, Rider, Admin | Keep session active until access token is within the refresh window | Access token refreshes in the background before a 401 is seen |
| Checkout/order placement | Customer | Start checkout, wait near token expiry, then place the order | Checkout completes without interruption or cart loss |
| Invoice load and action | Customer, Vendor, Admin | Open invoice screens during token expiry window | Invoice requests retry once and continue without user-facing auth errors |
| Rider live updates | Rider | Keep live tracking open during reconnect or expiry window | Tracking continues with silent recovery and no forced logout |
| Multi-request burst | Customer, Vendor, Rider, Admin | Trigger several protected requests at the same time | Only one refresh runs, queued calls replay after recovery, no refresh storm |
| Logout revocation | Customer, Vendor, Rider, Admin | Log out from the app, then reuse the same device/session | Local session is cleared and backend session is revoked |
| Multiple devices | Customer, Vendor, Rider, Admin | Sign in on two devices, revoke one session, keep the other active | Revoked device is logged out; the other session stays valid if not revoked |
| Backend restart | Customer, Vendor, Rider, Admin | Keep a session active while restarting backend services | App handles transient failures gracefully and recovers without raw auth errors |

## Role-Specific Checks

- Customer:
  - Home, cart, checkout, order history, invoice access
- Vendor:
  - Dashboard, order updates, invoice-related flows
- Rider:
  - Live tracking, delivery status updates, rider API calls
- Admin:
  - Admin dashboard, analytics, order/vendor/rider management, invoice actions

## Pass Criteria

- No unexpected logout
- No raw `401`, `Unauthorized`, or `Session expired` UI exposure
- No redirect flicker to login during silent refresh
- No duplicate refresh requests during concurrent API activity
- No session loss after restart, backgrounding, or reconnect

## Fail Criteria

- Login screen appears while a valid session exists
- Cart/order/invoice flow is interrupted by token expiry
- Refresh storms or repeated retries occur
- Offline state forces logout before connectivity is restored
- Logout does not revoke the backend session

## Notes

- Use the browser/devtools network panel or backend logs to confirm refresh rotation and retry-once behavior.
- If a test fails, capture the timestamp, app role, device type, and the last auth/session log entry before rerunning.
