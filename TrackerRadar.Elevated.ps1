param([switch]$SelfTest)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$controlScript = Join-Path $root 'TrackerRadar.Control.ps1'
$requestRoot = [IO.Path]::GetFullPath((Join-Path $root 'data\control-requests'))
$pointerPath = Join-Path $requestRoot 'elevated-request.txt'

if ($SelfTest) {
    $checks = @(
        [pscustomobject]@{ Name='ControlHelper'; Passed=(Test-Path -LiteralPath $controlScript -PathType Leaf); Detail=$controlScript },
        [pscustomobject]@{ Name='RequestFolder'; Passed=(Test-Path -LiteralPath $requestRoot -PathType Container); Detail=$requestRoot },
        [pscustomobject]@{ Name='PointerLocation'; Passed=$pointerPath.StartsWith($requestRoot,[StringComparison]::OrdinalIgnoreCase); Detail=$pointerPath }
    )
    $result = [pscustomobject]@{
        Product='TrackerRadar Elevated Wrapper'
        Version='0.5.4-alpha'
        Passed=@($checks | Where-Object Passed).Count
        Failed=@($checks | Where-Object { -not $_.Passed }).Count
        Checks=$checks
    }
    $result | ConvertTo-Json -Depth 5
    if ($result.Failed -gt 0) { exit 1 }
    exit 0
}

if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf)) {
    throw 'Die lokale Elevated-Request-Datei wurde nicht gefunden.'
}
$requestFile = (Get-Content -LiteralPath $pointerPath -Raw -ErrorAction Stop).Trim()
if ([string]::IsNullOrWhiteSpace($requestFile)) { throw 'Die Elevated-Request-Datei ist leer.' }
$requestPath = [IO.Path]::GetFullPath($requestFile)
$allowedPrefix = $requestRoot.TrimEnd('\') + '\'

if (-not $requestPath.StartsWith($allowedPrefix,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Die Control-Anfrage liegt ausserhalb des erlaubten TrackerRadar-Ordners.'
}
if (-not (Test-Path -LiteralPath $requestPath -PathType Leaf)) {
    throw 'Die Control-Anfrage wurde nicht gefunden.'
}
if (-not (Test-Path -LiteralPath $controlScript -PathType Leaf)) {
    throw 'TrackerRadar.Control.ps1 wurde nicht gefunden.'
}

& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $controlScript -RequestFile $requestPath
exit $LASTEXITCODE
