$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $projectRoot 'android\app\src\main\AndroidManifest.xml'
$resRoot = Join-Path $projectRoot 'android\app\src\main\res'
$brandingRoot = Join-Path $PSScriptRoot 'waycrew_branding\res'

if (-not (Test-Path $manifestPath)) {
  throw "Fant ikke AndroidManifest.xml på $manifestPath. Kjør scriptet fra WayCrew-prosjektet etter at Android-plattformen er opprettet."
}

[xml]$manifest = Get-Content -Raw -Path $manifestPath
$androidNs = 'http://schemas.android.com/apk/res/android'
$application = $manifest.manifest.application
if ($null -eq $application) {
  throw 'Fant ikke <application> i AndroidManifest.xml.'
}
$application.SetAttribute('label', $androidNs, 'WayCrew')
$manifest.Save($manifestPath)

$densities = @('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi')
foreach ($density in $densities) {
  $sourceDir = Join-Path $brandingRoot $density
  $targetDir = Join-Path $resRoot $density
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
  Copy-Item -Force (Join-Path $sourceDir 'ic_launcher.png') (Join-Path $targetDir 'ic_launcher.png')
  Copy-Item -Force (Join-Path $sourceDir 'ic_launcher_round.png') (Join-Path $targetDir 'ic_launcher_round.png')
}

Write-Host 'WayCrew-navn og launcher-ikon er lagt inn i Android-host.'
