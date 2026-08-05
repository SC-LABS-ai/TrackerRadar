param(
    [string]$Version = '0.5.5-alpha'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist "TrackerRadar-$Version"
$zip = Join-Path $dist "TrackerRadar-$Version-portable.zip"
$hashFile = Join-Path $dist "TrackerRadar-$Version-SHA256.txt"

& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.App.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Monitoring self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.Control.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Control self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.Elevated.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Elevated-wrapper self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.AccessScan.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Access-scan self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.AccessScan.Elevated.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Access-scan wrapper self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'Test-TrackerRadar-Localization.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Localization self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'Test-TrackerRadar-Launcher.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Hidden-launcher self-test failed. Package was not created.' }
& powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.App.ps1') -UiSmokeTest
if ($LASTEXITCODE -ne 0) { throw 'UI smoke test failed. Package was not created.' }

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$files = @(
    'TrackerRadar.App.ps1',
    'TrackerRadar.Control.ps1',
    'TrackerRadar.Elevated.ps1',
    'TrackerRadar.AccessScan.ps1',
    'TrackerRadar.AccessScan.Elevated.ps1',
    'TrackerRadar.Localization.ps1',
    'Start-TrackerRadar.cmd',
    'Start-TrackerRadar.vbs',
    'Test-TrackerRadar-App.ps1',
    'Test-TrackerRadar-Localization.ps1',
    'Test-TrackerRadar-Launcher.ps1',
    'Test-Firewall-BlockUndo.ps1',
    'README.md',
    'CHANGELOG.md',
    'PRIVACY.md',
    'SECURITY.md',
    'LICENSE.md',
    'NOTICE.md'
)
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $stage $file) -Force
}
Copy-Item -LiteralPath (Join-Path $root 'assets') -Destination (Join-Path $stage 'assets') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'locales') -Destination (Join-Path $stage 'locales') -Recurse -Force

Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
"$hash  $(Split-Path -Leaf $zip)" | Set-Content -LiteralPath $hashFile -Encoding ASCII

[pscustomobject]@{
    Version = $Version
    Package = $zip
    SHA256 = $hash
    SizeBytes = (Get-Item -LiteralPath $zip).Length
} | ConvertTo-Json -Depth 3
