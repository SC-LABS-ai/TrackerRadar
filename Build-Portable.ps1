param(
    [string]$Version = '0.3.0-alpha'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist "TrackerRadar-$Version"
$zip = Join-Path $dist "TrackerRadar-$Version-portable.zip"
$hashFile = Join-Path $dist "TrackerRadar-$Version-SHA256.txt"

& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'TrackerRadar.App.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Self-test failed. Package was not created.' }

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$files = @(
    'TrackerRadar.App.ps1',
    'Start-TrackerRadar.cmd',
    'Test-TrackerRadar-App.ps1',
    'README.md',
    'CHANGELOG.md',
    'PRIVACY.md',
    'SECURITY.md',
    'NOTICE.md'
)
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $stage $file) -Force
}
Copy-Item -LiteralPath (Join-Path $root 'assets') -Destination (Join-Path $stage 'assets') -Recurse -Force

Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
"$hash  $(Split-Path -Leaf $zip)" | Set-Content -LiteralPath $hashFile -Encoding ASCII

[pscustomobject]@{
    Version = $Version
    Package = $zip
    SHA256 = $hash
    SizeBytes = (Get-Item -LiteralPath $zip).Length
} | ConvertTo-Json -Depth 3
