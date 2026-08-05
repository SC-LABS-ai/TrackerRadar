$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$vbs=Join-Path $root 'Start-TrackerRadar.vbs'
$cmd=Join-Path $root 'Start-TrackerRadar.cmd'
$app=Join-Path $root 'TrackerRadar.App.ps1'

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class TrackerRadarWindowProbe {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extraData);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder className, int maxCount);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsWindowVisible(IntPtr hWnd);
}
'@

function Get-TrackerRadarProcesses {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
        [string]$_.CommandLine -match [regex]::Escape($app)
    })
}

function Get-ProcessWindows([int]$ProcessId) {
    $items=New-Object System.Collections.Generic.List[object]
    $callback=[TrackerRadarWindowProbe+EnumWindowsProc]{
        param([IntPtr]$handle,[IntPtr]$unused)
        $owner=0
        [void][TrackerRadarWindowProbe]::GetWindowThreadProcessId($handle,[ref]$owner)
        if([int]$owner -eq $ProcessId){
            $class=New-Object Text.StringBuilder 256
            $title=New-Object Text.StringBuilder 512
            [void][TrackerRadarWindowProbe]::GetClassName($handle,$class,$class.Capacity)
            [void][TrackerRadarWindowProbe]::GetWindowText($handle,$title,$title.Capacity)
            $items.Add([pscustomobject]@{Handle=$handle.ToInt64();Class=$class.ToString();Title=$title.ToString();Visible=[TrackerRadarWindowProbe]::IsWindowVisible($handle)})
        }
        return $true
    }
    [void][TrackerRadarWindowProbe]::EnumWindows($callback,[IntPtr]::Zero)
    return $items.ToArray()
}

$checks=@()
$newProcess=$null
try {
    $checks += [pscustomobject]@{Name='VbsLauncher';Passed=(Test-Path -LiteralPath $vbs -PathType Leaf);Detail=$vbs}
    $checks += [pscustomobject]@{Name='CmdLauncher';Passed=(Test-Path -LiteralPath $cmd -PathType Leaf);Detail=$cmd}
    $vbsText=if(Test-Path -LiteralPath $vbs){[IO.File]::ReadAllText($vbs)}else{''}
    $cmdText=if(Test-Path -LiteralPath $cmd){[IO.File]::ReadAllText($cmd)}else{''}
    $checks += [pscustomobject]@{Name='HiddenPowerShell';Passed=($vbsText -match '-WindowStyle Hidden' -and $vbsText -match 'TrackerRadar\.App\.ps1');Detail='VBS starts PowerShell hidden'}
    $checks += [pscustomobject]@{Name='CmdUsesWScript';Passed=($cmdText -match 'wscript\.exe' -and $cmdText -notmatch 'powershell\.exe');Detail='CMD delegates to Windows Script Host'}

    $existing=@(Get-TrackerRadarProcesses | ForEach-Object {[int]$_.ProcessId})
    Start-Process -FilePath 'wscript.exe' -ArgumentList @('"'+$vbs+'"') | Out-Null
    $deadline=(Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 300
        $newProcess=Get-TrackerRadarProcesses | Where-Object { [int]$_.ProcessId -notin $existing } | Select-Object -First 1
    } until($newProcess -or (Get-Date) -ge $deadline)
    $checks += [pscustomobject]@{Name='AppStarted';Passed=($null -ne $newProcess);Detail=if($newProcess){[string]$newProcess.ProcessId}else{'No new process'}}

    $windows=@()
    if($newProcess){
        Start-Sleep -Seconds 3
        $windows=Get-ProcessWindows -ProcessId ([int]$newProcess.ProcessId)
    }
    $visibleWpf=@($windows | Where-Object {$_.Visible -and $_.Class -ne 'ConsoleWindowClass' -and $_.Title -match 'TrackerRadar'})
    $visibleConsole=@($windows | Where-Object {$_.Visible -and $_.Class -eq 'ConsoleWindowClass'})
    $checks += [pscustomobject]@{Name='TrackerRadarWindowVisible';Passed=($visibleWpf.Count -ge 1);Detail=($visibleWpf | ConvertTo-Json -Compress)}
    $checks += [pscustomobject]@{Name='NoVisiblePowerShellConsole';Passed=($visibleConsole.Count -eq 0);Detail=($visibleConsole | ConvertTo-Json -Compress)}
} finally {
    if($newProcess){Stop-Process -Id ([int]$newProcess.ProcessId) -Force -ErrorAction SilentlyContinue}
}

$passed=@($checks|Where-Object {$_.Passed}).Count
$result=[pscustomobject]@{Product='TrackerRadar Launcher';Version='0.5.5-alpha';Passed=$passed;Failed=($checks.Count-$passed);Checks=$checks}
$result|ConvertTo-Json -Depth 6
if($result.Failed -ne 0){exit 1}
