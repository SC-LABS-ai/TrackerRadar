param(
    [switch]$SelfTest,
    [switch]$ScanMode,
    [int]$DurationSeconds = 5
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataRoot = Join-Path $script:Root 'data\access-scan'
if (-not (Test-Path -LiteralPath $script:DataRoot)) {
    New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Invoke-NativeTool {
    param([string]$Executable,[string[]]$ToolArguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Executable @ToolArguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Text = ($output -join [Environment]::NewLine)
    }
}

function Convert-PidField {
    param([string]$Value)
    $clean = ([string]$Value).Trim()
    if ($clean -match '^0x([0-9A-Fa-f]+)$') {
        try { return [Convert]::ToInt32($Matches[1],16) } catch { return 0 }
    }
    $number = 0
    [void][int]::TryParse(($clean -replace '[^0-9]',''),[ref]$number)
    return $number
}

function Get-DefaultRoots {
    $profile = [Environment]::GetFolderPath('UserProfile')
    $local = [Environment]::GetFolderPath('LocalApplicationData')
    $oneDrive = [Environment]::GetEnvironmentVariable('OneDrive')
    if ([string]::IsNullOrWhiteSpace($oneDrive) -and -not [string]::IsNullOrWhiteSpace($profile)) {
        $fallbackOneDrive = Join-Path $profile 'OneDrive'
        if (Test-Path -LiteralPath $fallbackOneDrive) { $oneDrive = $fallbackOneDrive }
    }

    $candidates = @(
        [pscustomobject]@{ Label='Dokumente'; Path=[Environment]::GetFolderPath('MyDocuments') },
        [pscustomobject]@{ Label='Desktop'; Path=[Environment]::GetFolderPath('Desktop') },
        [pscustomobject]@{ Label='Downloads'; Path=if ($profile) { Join-Path $profile 'Downloads' } else { '' } },
        [pscustomobject]@{ Label='OneDrive'; Path=$oneDrive },
        [pscustomobject]@{ Label='Edge-Profil'; Path=if ($local) { Join-Path $local 'Microsoft\Edge\User Data' } else { '' } },
        [pscustomobject]@{ Label='Chrome-Profil'; Path=if ($local) { Join-Path $local 'Google\Chrome\User Data' } else { '' } }
    )

    $roots = @()
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace([string]$candidate.Path)) { continue }
        try { $full = [IO.Path]::GetFullPath([string]$candidate.Path).TrimEnd('\') } catch { continue }
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $suffix = if ($full.Length -gt 2 -and $full[1] -eq ':') { $full.Substring(2) } else { $full }
        if (-not ($roots | Where-Object { $_.Path -eq $full })) {
            $roots += [pscustomobject]@{
                Label = [string]$candidate.Label
                Path = $full
                DeviceSuffix = $suffix.TrimEnd('\')
            }
        }
    }
    return @($roots)
}

function Get-ProcessMap {
    $map = @{}
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        $pidValue = [int]$process.ProcessId
        $name = if ([string]::IsNullOrWhiteSpace([string]$process.Name)) { 'Unbekannter Prozess' } else { [string]$process.Name }
        $map[$pidValue] = [pscustomobject]@{
            Name = $name
            Path = [string]$process.ExecutablePath
        }
    }
    return $map
}

function Merge-ProcessMap {
    param([hashtable]$Target,[hashtable]$Source)
    foreach ($key in $Source.Keys) {
        if (-not $Target.ContainsKey($key) -or [string]$Target[$key].Name -eq 'Unbekannter Prozess') {
            $Target[$key] = $Source[$key]
        }
    }
}

function Get-PathFromEventLine {
    param([string]$Line)
    $match = [regex]::Match($Line,'(?i)(\\Device\\HarddiskVolume\d+\\[^\"]+|[A-Za-z]:\\[^\"]+)')
    if ($match.Success) { return $match.Groups[1].Value }
    return ''
}

function Get-RootForEventPath {
    param([string]$EventPath,[object[]]$Roots)
    if ([string]::IsNullOrWhiteSpace($EventPath)) { return $null }
    $comparable = $EventPath -replace '^(?i)\\Device\\HarddiskVolume\d+',''
    if ($comparable.Length -gt 2 -and $comparable[1] -eq ':') { $comparable = $comparable.Substring(2) }
    foreach ($root in $Roots) {
        if ($comparable.StartsWith([string]$root.DeviceSuffix,[StringComparison]::OrdinalIgnoreCase)) {
            return $root
        }
    }
    return $null
}

function Convert-AccessCsv {
    param([string]$CsvPath,[object[]]$Roots,[hashtable]$ProcessMap)
    $groups = @{}
    $reader = New-Object System.IO.StreamReader($CsvPath,$true)
    try {
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line.IndexOf('Microsoft-Windows-Kernel-File',[StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $parts = $line.Split([char]44,20)
            if ($parts.Length -lt 10) { continue }

            $eventId = 0
            [void][int]::TryParse((([string]$parts[2]).Trim()),[ref]$eventId)
            if ($eventId -notin @(12,20)) { continue }

            $eventPath = Get-PathFromEventLine $line
            $root = Get-RootForEventPath -EventPath $eventPath -Roots $Roots
            if ($null -eq $root) { continue }

            $processId = Convert-PidField ([string]$parts[9])
            $processInfo = if ($ProcessMap.ContainsKey($processId)) {
                $ProcessMap[$processId]
            } else {
                [pscustomobject]@{ Name='Unbekannter Prozess'; Path='' }
            }
            $operation = if ($eventId -eq 12) { 'Geoeffnet' } else { 'Ordner durchsucht' }
            $key = "$processId|$($root.Label)|$operation"
            if (-not $groups.ContainsKey($key)) {
                $groups[$key] = [pscustomobject]@{
                    ProcessName = [string]$processInfo.Name
                    ProcessId = $processId
                    ExecutablePath = [string]$processInfo.Path
                    Folder = [string]$root.Label
                    Operation = $operation
                    AccessCount = 0
                }
            }
            $groups[$key].AccessCount++
        }
    } finally {
        $reader.Dispose()
    }
    return @($groups.Values | Sort-Object AccessCount -Descending)
}

function Write-JsonUtf8 {
    param([string]$Path,$Value)
    [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
}

function Invoke-SelfTest {
    $fixtureRoot = Join-Path $script:DataRoot 'fixture-root'
    $fixture = Join-Path $script:DataRoot 'access-fixture.csv'
    if (-not (Test-Path -LiteralPath $fixtureRoot)) { New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null }
    $target = Join-Path $fixtureRoot 'sample.txt'
    $devicePath = '\Device\HarddiskVolume3' + $target.Substring(2)
    $lines = @(
        'Event Name,Type,Event ID,Version,Channel,Level,Opcode,Task,Keyword,PID,TID,Processor,User Data',
        "Microsoft-Windows-Kernel-File,Info,12,1,16,4,0,12,0xA0,0x00000065,0x1,0,`"$devicePath`"",
        "Microsoft-Windows-Kernel-File,Info,20,1,16,4,0,20,0x20,0x00000065,0x1,0,`"$devicePath`"",
        'Microsoft-Windows-Kernel-File,Info,12,1,16,4,0,12,0xA0,0x000000CA,0x1,0,"\Device\HarddiskVolume3\Windows\Temp\ignored.txt"'
    )
    [IO.File]::WriteAllLines($fixture,$lines,(New-Object Text.UTF8Encoding($false)))
    $rootSuffix = $fixtureRoot.Substring(2)
    $roots = @([pscustomobject]@{ Label='Testordner'; Path=$fixtureRoot; DeviceSuffix=$rootSuffix })
    $map = @{ 101=[pscustomobject]@{ Name='test.exe'; Path='C:\Test\test.exe' } }
    $groups = @(Convert-AccessCsv -CsvPath $fixture -Roots $roots -ProcessMap $map)
    $checks = @(
        [pscustomobject]@{ Name='RootFilter'; Passed=($groups.Count -eq 2); Detail="$($groups.Count) Gruppen" },
        [pscustomobject]@{ Name='ProcessMapping'; Passed=(-not ($groups | Where-Object { $_.ProcessName -ne 'test.exe' })); Detail='test.exe / PID 101' },
        [pscustomobject]@{ Name='OpenMapping'; Passed=([bool]($groups | Where-Object { $_.Operation -eq 'Geoeffnet' })); Detail='Event 12' },
        [pscustomobject]@{ Name='DirEnumMapping'; Passed=([bool]($groups | Where-Object { $_.Operation -eq 'Ordner durchsucht' })); Detail='Event 20' },
        [pscustomobject]@{ Name='OutsideIgnored'; Passed=(-not ($groups | Where-Object { $_.ProcessId -eq 202 })); Detail='Windows Temp ignoriert' },
        [pscustomobject]@{ Name='NoFileNames'; Passed=(-not (($groups | ConvertTo-Json -Depth 5) -match 'sample.txt')); Detail='Keine Dateinamen im Ergebnis' }
    )
    $result = [pscustomobject]@{
        Product = 'TrackerRadar Access Scan'
        Version = '0.5.4-alpha'
        Passed = @($checks | Where-Object { $_.Passed }).Count
        Failed = @($checks | Where-Object { -not $_.Passed }).Count
        Checks = $checks
        SampleGroups = $groups
    }
    $result | ConvertTo-Json -Depth 7
    Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    if ($result.Failed -gt 0) { exit 1 }
    exit 0
}

function Invoke-AccessScan {
    if (-not (Test-IsAdministrator)) { throw 'Visible Windows UAC approval is required.' }
    if ($DurationSeconds -lt 1 -or $DurationSeconds -gt 10) { throw 'DurationSeconds must be between 1 and 10.' }

    $session = 'TrackerRadarAccessScan-' + $PID
    $provider = '{EDD08927-9CC4-4E65-B970-C2560FB5C289}'
    $etl = Join-Path $script:DataRoot 'access-scan.etl'
    $csv = Join-Path $script:DataRoot 'access-scan.csv'
    $resultPath = Join-Path $script:DataRoot 'latest-access-scan.json'
    foreach ($path in @($etl,$csv)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }

    $roots = @(Get-DefaultRoots)
    if ($roots.Count -eq 0) { throw 'No supported user folders were found.' }

    $processMap = Get-ProcessMap
    $sessionStarted = $false
    try {
        $create = Invoke-NativeTool 'logman.exe' @('create','trace',$session,'-p',$provider,'0x00000000000003F0','0x04','-o',$etl,'-f','bincirc','-max','16','-nb','4','16','-bs','64','-ets')
        if ($create.ExitCode -ne 0) { throw "ETW start failed: $($create.Text)" }
        $sessionStarted = $true

        Start-Sleep -Seconds $DurationSeconds

        $stop = Invoke-NativeTool 'logman.exe' @('stop',$session,'-ets')
        $sessionStarted = $false
        if ($stop.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $etl)) { throw "ETW stop failed: $($stop.Text)" }

        Merge-ProcessMap -Target $processMap -Source (Get-ProcessMap)
        $trace = Invoke-NativeTool 'tracerpt.exe' @($etl,'-o',$csv,'-of','CSV','-y')
        if ($trace.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $csv)) { throw "tracerpt failed: $($trace.Text)" }

        $groups = @(Convert-AccessCsv -CsvPath $csv -Roots $roots -ProcessMap $processMap)
        $result = [pscustomobject]@{
            Product = 'TrackerRadar Access Scan'
            Version = '0.5.4-alpha'
            Timestamp = (Get-Date).ToString('o')
            Mode = 'UserFolders'
            Passed = $true
            DurationSeconds = $DurationSeconds
            MonitoredFolders = @($roots | Select-Object -ExpandProperty Label)
            GroupCount = $groups.Count
            RawEtlBytes = (Get-Item -LiteralPath $etl).Length
            RawCsvBytes = (Get-Item -LiteralPath $csv).Length
            Privacy = 'No file contents and no individual file names are stored in the result.'
            CurrentLimit = 'Access/open and directory enumeration only; exact read/write classification is not claimed.'
            Groups = $groups
        }
        Write-JsonUtf8 -Path $resultPath -Value $result
        $result | ConvertTo-Json -Depth 8
        exit 0
    } finally {
        if ($sessionStarted) { & logman.exe stop $session -ets 2>$null | Out-Null }
        & logman.exe delete $session 2>$null | Out-Null
        Remove-Item -LiteralPath $etl,$csv -Force -ErrorAction SilentlyContinue
    }
}

if ($SelfTest) { Invoke-SelfTest }
if ($ScanMode) { Invoke-AccessScan }
throw 'Use -SelfTest or -ScanMode.'
