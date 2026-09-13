$ErrorActionPreference = 'Stop'
$manifest = Join-Path $PSScriptRoot '..\android\app\src\main\AndroidManifest.xml'
$manifest = [System.IO.Path]::GetFullPath($manifest)

if (-not (Test-Path $manifest)) {
  throw "Fant ikke AndroidManifest.xml: $manifest. Kjør flutter create --platforms=android . først dersom android-mappen mangler."
}

$content = Get-Content -Raw -Path $manifest
$permissions = @(
  '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
  '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
  '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />',
  '<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
  '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />',
  '<uses-permission android:name="android.permission.WAKE_LOCK" />'
)

$missing = @()
foreach ($permission in $permissions) {
  $name = [regex]::Match($permission, 'android:name="([^"]+)"').Groups[1].Value
  if ($content -notmatch [regex]::Escape($name)) {
    $missing += $permission
  }
}

if ($missing.Count -eq 0) {
  Write-Host 'Live tracking-permissions finnes allerede i AndroidManifest.xml.'
  exit 0
}

$insert = "`r`n    " + ($missing -join "`r`n    ") + "`r`n"
$content = [regex]::Replace($content, '(<manifest\b[^>]*>)', '$1' + $insert, 1)
Set-Content -Path $manifest -Value $content -Encoding UTF8
Write-Host "La til $($missing.Count) Android-permissions for live tracking."
Write-Host $manifest
