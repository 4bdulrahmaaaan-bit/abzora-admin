$ErrorActionPreference = "Stop"

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "Generating CUSTOMER launcher icons..."
flutter pub run flutter_launcher_icons -f flutter_launcher_icons_customer.yaml

Write-Host "Generating PARTNER launcher icons..."
flutter pub run flutter_launcher_icons -f flutter_launcher_icons_partner.yaml

Write-Host "Done. Customer and partner icon sets regenerated."
