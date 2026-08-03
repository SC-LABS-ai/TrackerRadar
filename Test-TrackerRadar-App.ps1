$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$data = Join-Path $root 'data'
$app = Join-Path $root 'TrackerRadar.App.ps1'
$control = Join-Path $root 'TrackerRadar.Control.ps1'
$elevated = Join-Path $root 'TrackerRadar.Elevated.ps1'
if (-not (Test-Path -LiteralPath $data)) { New-Item -ItemType Directory -Path $data | Out-Null }

$selfOut = Join-Path $data 'app-selftest-output.txt'
$controlOut = Join-Path $data 'control-selftest-output.txt'
$elevatedOut = Join-Path $data 'elevated-selftest-output.txt'
$uiOut = Join-Path $data 'app-ui-smoke-output.txt'
$guiOut = Join-Path $data 'app-gui-stdout.txt'
$guiErr = Join-Path $data 'app-gui-stderr.txt'
Remove-Item $selfOut,$controlOut,$elevatedOut,$uiOut,$guiOut,$guiErr -Force -ErrorAction SilentlyContinue

$self = Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$app,'-SelfTest') -Wait -PassThru -RedirectStandardOutput $selfOut
$controlTest = Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$control,'-SelfTest') -Wait -PassThru -RedirectStandardOutput $controlOut
$elevatedTest = Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$elevated,'-SelfTest') -Wait -PassThru -RedirectStandardOutput $elevatedOut
$uiSmoke = Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$app,'-UiSmokeTest') -Wait -PassThru -RedirectStandardOutput $uiOut
$gui = Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$app) -PassThru -RedirectStandardOutput $guiOut -RedirectStandardError $guiErr

Start-Sleep -Seconds 10
$gui.Refresh()
$alive = -not $gui.HasExited
$workingSetMb = if ($alive) { [math]::Round($gui.WorkingSet64 / 1MB, 1) } else { 0 }
$privateMb = if ($alive) { [math]::Round($gui.PrivateMemorySize64 / 1MB, 1) } else { 0 }
$cpuSeconds = if ($alive) { [math]::Round($gui.TotalProcessorTime.TotalSeconds, 2) } else { 0 }
$errorText = ''
if (Test-Path -LiteralPath $guiErr) {
    $raw = Get-Content -LiteralPath $guiErr -Raw -ErrorAction SilentlyContinue
    if ($null -ne $raw) { $errorText = [string]$raw }
}

if ($alive) {
    Stop-Process -Id $gui.Id -Force -ErrorAction SilentlyContinue
    $gui.WaitForExit()
}

$result = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('o')
    SelfTestExitCode = $self.ExitCode
    ControlSelfTestExitCode = $controlTest.ExitCode
    ElevatedSelfTestExitCode = $elevatedTest.ExitCode
    UiSmokeExitCode = $uiSmoke.ExitCode
    GuiStarted = $alive
    WorkingSetMb = $workingSetMb
    PrivateMemoryMb = $privateMb
    CpuSecondsAfter10s = $cpuSeconds
    GuiError = $errorText.Trim()
    RamTarget150Passed = ($workingSetMb -gt 0 -and $workingSetMb -le 150)
    RamTarget180Passed = ($workingSetMb -gt 0 -and $workingSetMb -le 180)
    OverallPassed = ($self.ExitCode -eq 0 -and $controlTest.ExitCode -eq 0 -and $elevatedTest.ExitCode -eq 0 -and $uiSmoke.ExitCode -eq 0 -and $alive -and [string]::IsNullOrWhiteSpace($errorText))
}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $data 'app-full-test.json') -Encoding UTF8
$result | ConvertTo-Json -Depth 4
if (-not $result.OverallPassed) { exit 1 }
