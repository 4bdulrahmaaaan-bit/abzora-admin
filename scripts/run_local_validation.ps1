param(
  [switch]$UseEmulators,
  [switch]$ShowRtdbChecks
)

$ErrorActionPreference = "Stop"

Write-Host "Running flutter analyze..." -ForegroundColor Cyan
flutter analyze

Write-Host "Running flutter test..." -ForegroundColor Cyan
flutter test

if ($UseEmulators) {
  Write-Host "Emulator mode requested." -ForegroundColor Yellow
  Write-Host "Start Firebase emulators in a separate shell with:" -ForegroundColor Yellow
  Write-Host "firebase emulators:start --only auth,database" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Then launch Flutter with:" -ForegroundColor Yellow
  Write-Host "flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099 --dart-define=FIREBASE_DATABASE_EMULATOR_PORT=9000" -ForegroundColor Yellow
}

if ($ShowRtdbChecks) {
  Write-Host "" -ForegroundColor Yellow
  Write-Host "RTDB emulator validation checklist:" -ForegroundColor Cyan
  Write-Host "1. Start emulators: firebase emulators:start --only auth,database" -ForegroundColor Yellow
  Write-Host "2. Run the app with emulator defines enabled." -ForegroundColor Yellow
  Write-Host "3. Validate customer access:" -ForegroundColor Yellow
  Write-Host "   - create account/login" -ForegroundColor Gray
  Write-Host "   - save address, wishlist, measurements" -ForegroundColor Gray
  Write-Host "   - place order and confirm only own orders load" -ForegroundColor Gray
  Write-Host "   - cancel own order and confirm financial fields stay unchanged" -ForegroundColor Gray
  Write-Host "4. Validate vendor access:" -ForegroundColor Yellow
  Write-Host "   - onboard vendor and confirm store is pending" -ForegroundColor Gray
  Write-Host "   - add/edit only products for own store" -ForegroundColor Gray
  Write-Host "   - confirm only own store orders, payouts, and notifications load" -ForegroundColor Gray
  Write-Host "5. Validate rider access:" -ForegroundColor Yellow
  Write-Host "   - assign rider to order from admin/vendor flow" -ForegroundColor Gray
  Write-Host "   - confirm only assigned deliveries and rider notifications load" -ForegroundColor Gray
  Write-Host "6. Validate admin access:" -ForegroundColor Yellow
  Write-Host "   - approve/reject stores" -ForegroundColor Gray
  Write-Host "   - update order status and process payout" -ForegroundColor Gray
  Write-Host "   - confirm disputes/activity logs are visible" -ForegroundColor Gray
  Write-Host "7. Review the full matrix in RTDB_EMULATOR_VALIDATION.md" -ForegroundColor Yellow
  Write-Host "8. Run automated permission tests with: npm run test:rtdb-rules:emulator" -ForegroundColor Yellow
}
