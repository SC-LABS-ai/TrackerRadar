param([switch]$SelfTest)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$scanScript = Join-Path $root 'TrackerRadar.AccessScan.ps1'
$dataFolder = Join-Path $root 'data\access-scan'
$logPath = Join-Path $dataFolder 'elevated-scan.log'

if ($SelfTest) {
    $checks = @(
        [pscustomobject]@{ Name='ScanScript'; Passed=(Test-Path -LiteralPath $scanScript -PathType Leaf); Detail=$scanScript },
        [pscustomobject]@{ Name='RelativeRoot'; Passed=($root -eq (Split-Path -Parent $MyInvocation.MyCommand.Path)); Detail=$root },
        [pscustomobject]@{ Name='DataFolder'; Passed=(-not [string]::IsNullOrWhiteSpace($dataFolder)); Detail=$dataFolder }
    )
    $passed = @($checks | Where-Object { $_.Passed }).Count
    [pscustomobject]@{
        Product='TrackerRadar Access Scan Wrapper'
        Version='0.5.0-alpha'
        Passed=$passed
        Failed=($checks.Count-$passed)
        Checks=$checks
    } | ConvertTo-Json -Depth 5
    if ($passed -ne $checks.Count) { exit 1 }
    exit 0
}

if (-not (Test-Path -LiteralPath $dataFolder)) {
    New-Item -ItemType Directory -Path $dataFolder -Force | Out-Null
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"START $(Get-Date -Format o) admin=$isAdmin" | Set-Content -LiteralPath $logPath -Encoding UTF8

if (-not $isAdmin) {
    'Administratorrechte wurden nicht erteilt.' | Add-Content -LiteralPath $logPath -Encoding UTF8
    exit 2
}
if (-not (Test-Path -LiteralPath $scanScript -PathType Leaf)) {
    'TrackerRadar.AccessScan.ps1 wurde nicht gefunden.' | Add-Content -LiteralPath $logPath -Encoding UTF8
    exit 3
}

& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $scanScript -ScanMode -DurationSeconds 5 *>> $logPath
$code = $LASTEXITCODE
"EXIT $code" | Add-Content -LiteralPath $logPath -Encoding UTF8
exit $code
