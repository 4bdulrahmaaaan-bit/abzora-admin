param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('customer','vendor','rider')]
  [string]$Flavor
)

$root = Split-Path $PSScriptRoot -Parent
$iosAssets = Join-Path $root 'ios\Runner\Assets.xcassets'
$suffix = switch ($Flavor) {
  'customer' { 'Customer' }
  'vendor' { 'Vendor' }
  'rider' { 'Rider' }
}
$appIconSrc = Join-Path $iosAssets ("AppIcon" + $suffix + '.appiconset')
$launchSrc = Join-Path $iosAssets ("LaunchImage" + $suffix + '.imageset')
$appIconDest = Join-Path $iosAssets 'AppIcon.appiconset'
$launchDest = Join-Path $iosAssets 'LaunchImage.imageset'

if (!(Test-Path $appIconSrc)) { throw "Missing source app icon set: $appIconSrc" }
if (!(Test-Path $launchSrc)) { throw "Missing source launch set: $launchSrc" }

Copy-Item -Path (Join-Path $appIconSrc '*') -Destination $appIconDest -Recurse -Force
Copy-Item -Path (Join-Path $launchSrc '*') -Destination $launchDest -Recurse -Force

$infoPlist = Join-Path $root 'ios\Runner\Info.plist'
$xml = Get-Content -Raw $infoPlist
$appName = switch ($Flavor) {
  'customer' { 'Abzora' }
  'vendor' { 'Abzora Vendor' }
  'rider' { 'Abzora Rider' }
}
$storyboard = "LaunchScreen$suffix"

$xml = [regex]::Replace($xml, '<key>CFBundleDisplayName</key>\s*<string>.*?</string>', "<key>CFBundleDisplayName</key>`n	<string>$appName</string>")
$xml = [regex]::Replace($xml, '<key>UILaunchStoryboardName</key>\s*<string>.*?</string>', "<key>UILaunchStoryboardName</key>`n	<string>$storyboard</string>")
Set-Content -Path $infoPlist -Value $xml

Write-Host "iOS branding switched to: $Flavor"
