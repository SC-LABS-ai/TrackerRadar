param([string]$ResultPath)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$data = Join-Path $root 'data'
$testRoot = Join-Path $data 'firewall-test'
$requestRoot = Join-Path $data 'control-requests'
$changesRoot = Join-Path $data 'changes'
$controlScript = Join-Path $root 'TrackerRadar.Control.ps1'
$sourceCurl = Join-Path $env:WINDIR 'System32\curl.exe'
$testExe = Join-Path $testRoot 'TrackerRadar-Curl-Test.exe'
$testUrl = 'https://example.com/'
if ([string]::IsNullOrWhiteSpace($ResultPath)) { $ResultPath = Join-Path $testRoot 'firewall-test-result.json' }

foreach ($folder in @($data,$testRoot,$requestRoot,$changesRoot)) {
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
}

function Write-Result {
    param($Result)
    $json = $Result | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false)))
    $json
}

function Get-ShortHash {
    param([string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')
        return $hash.Substring(0,12)
    } finally { $sha.Dispose() }
}

function Get-RuleState {
    param([string]$RuleName)
    $output = & netsh.exe advfirewall firewall show rule name="$RuleName" verbose 2>&1
    $text = ($output -join [Environment]::NewLine)
    $notFound = $text -match 'No rules match|Keine Regeln|Es wurden keine Regeln'
    return [pscustomobject]@{ Exists=($LASTEXITCODE -eq 0 -and -not $notFound); Text=$text }
}

function Invoke-TestCurl {
    & $testExe '--silent' '--show-error' '--fail' '--max-time' '10' '--output' 'NUL' $testUrl 2>$null
    return $LASTEXITCODE
}

function Invoke-LocalHelperRequest {
    param($Request,[string]$Name)
    $requestPath = Join-Path $requestRoot ($Name + '.json')
    $responsePath = [IO.Path]::ChangeExtension($requestPath,'.response.json')
    $Request | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $requestPath -Encoding UTF8
    try {
        $process = Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$controlScript,'-RequestFile',$requestPath) -Wait -PassThru -WindowStyle Hidden
        if (-not (Test-Path -LiteralPath $responsePath)) { throw "Keine lokale Helper-Antwort fuer $Name (Exit $($process.ExitCode))." }
        return (Get-Content -LiteralPath $responsePath -Raw | ConvertFrom-Json)
    } finally {
        Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $responsePath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-ElevatedHelperRequest {
    param($Request,[string]$Name)
    $requestPath = Join-Path $requestRoot ($Name + '.json')
    $responsePath = [IO.Path]::ChangeExtension($requestPath,'.response.json')
    $Request | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $requestPath -Encoding UTF8
    try {
        $elevatedScript = Join-Path $root 'TrackerRadar.Elevated.ps1'
        $pointerPath = Join-Path $requestRoot 'elevated-request.txt'
        [IO.File]::WriteAllText($pointerPath,$requestPath,(New-Object Text.UTF8Encoding($false)))
        $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$elevatedScript)
        $argumentString = ($arguments | ForEach-Object {
            $value = [string]$_
            if ($value -match '[\s"]') { '"' + $value.Replace('"','\"') + '"' } else { $value }
        }) -join ' '
        try {
            $process = Start-Process powershell.exe -Verb RunAs -ArgumentList $argumentString -Wait -PassThru
        } catch {
            $nativeCode = 0
            try { $nativeCode = [int]$_.Exception.NativeErrorCode } catch { }
            if ($nativeCode -eq 1223 -or $_.Exception.Message -match 'canceled|cancelled|abgebrochen') {
                throw 'Windows-UAC wurde abgebrochen. Es wurde nichts geaendert.'
            }
            throw
        }
        if (-not (Test-Path -LiteralPath $responsePath)) {
            if ($process.ExitCode -eq -196608) { throw 'Windows-UAC wurde abgebrochen oder nicht bestaetigt. Es wurde nichts geaendert.' }
            throw "Keine Helper-Antwort fuer $Name (Exit $($process.ExitCode))."
        }
        return (Get-Content -LiteralPath $responsePath -Raw | ConvertFrom-Json)
    } finally {
        Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $responsePath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $requestRoot 'elevated-request.txt') -Force -ErrorAction SilentlyContinue
    }
}

$changeId = 'test-fw-' + [guid]::NewGuid().ToString('N')
$ruleName = 'SC LABS TrackerRadar Block ' + (Get-ShortHash $testExe.ToLowerInvariant())
$result = $null

try {
    Copy-Item -LiteralPath $sourceCurl -Destination $testExe -Force
    $preExit = Invoke-TestCurl
    if ($preExit -ne 0) { throw "Ausgangsverbindung fehlgeschlagen (curl Exit $preExit)." }

    $apply = Invoke-ElevatedHelperRequest ([pscustomobject]@{ Action='BlockInternet'; ProgramPath=$testExe; ChangeId=$changeId }) ('apply-' + $changeId)
    if (-not [bool]$apply.Ok) { throw [string]$apply.Error }
    $ruleAfterApply = Get-RuleState $ruleName
    $blockedExit = Invoke-TestCurl
    $duplicate = Invoke-LocalHelperRequest ([pscustomobject]@{ Action='BlockInternet'; ProgramPath=$testExe; ChangeId=('duplicate-' + [guid]::NewGuid().ToString('N')) }) ('duplicate-' + $changeId)
    $duplicatePrevented = (-not [bool]$duplicate.Ok -and [string]$duplicate.Error -match 'existiert bereits')

    $undo = Invoke-ElevatedHelperRequest ([pscustomobject]@{ Action='UndoChange'; ChangeId=$changeId }) ('undo-' + $changeId)
    if (-not [bool]$undo.Ok) { throw [string]$undo.Error }
    $ruleAfterUndo = Get-RuleState $ruleName
    $postExit = Invoke-TestCurl

    $result = [pscustomobject]@{
        Version='0.5.5-alpha'; Timestamp=(Get-Date).ToString('o')
        Passed=($ruleAfterApply.Exists -and $blockedExit -ne 0 -and $duplicatePrevented -and -not $ruleAfterUndo.Exists -and $postExit -eq 0)
        PreConnectionPassed=($preExit -eq 0)
        RuleCreatedAndVerified=$ruleAfterApply.Exists
        ConnectionBlocked=($blockedExit -ne 0)
        BlockedCurlExitCode=$blockedExit
        DuplicateRulePrevented=$duplicatePrevented
        RuleRemovedAndVerified=(-not $ruleAfterUndo.Exists)
        ConnectionRestored=($postExit -eq 0)
        RestoredCurlExitCode=$postExit
        RemainingRule=$ruleAfterUndo.Exists
    }
} catch {
    $result = [pscustomobject]@{ Version='0.5.5-alpha'; Timestamp=(Get-Date).ToString('o'); Passed=$false; Error=$_.Exception.Message }
} finally {
    try {
        $record = Join-Path $changesRoot ($changeId + '.json')
        if (Test-Path -LiteralPath $record) {
            $change = Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
            if ([string]$change.Status -eq 'Applied') {
                Invoke-ElevatedHelperRequest ([pscustomobject]@{ Action='UndoChange'; ChangeId=$changeId }) ('cleanup-' + $changeId) | Out-Null
            }
        }
    } catch { }
    Remove-Item -LiteralPath (Join-Path $changesRoot ($changeId + '.json')) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testExe -Force -ErrorAction SilentlyContinue
}

Write-Result $result | Out-Null
$result | ConvertTo-Json -Depth 8
if ([bool]$result.Passed) { exit 0 } else { exit 1 }
