param(
    [switch]$SelfTest,
    [switch]$ExportOnly,
    [switch]$UiSmokeTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Version = '0.5.5-alpha'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Split-Path -Leaf $script:Root) -eq '_development') { $script:Root = Split-Path -Parent $script:Root }
$script:Data = Join-Path $script:Root 'data'
$script:State = Join-Path $script:Data 'state'
$script:History = Join-Path $script:Data 'history'
$script:AccessScanData = Join-Path $script:Data 'access-scan'
foreach ($folder in @($script:Data, $script:State, $script:History, $script:AccessScanData)) {
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Write-JsonFile {
    param([string]$Path, $Value, [int]$Depth = 8)
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

$localizationScript = Join-Path $script:Root 'TrackerRadar.Localization.ps1'
if (-not (Test-Path -LiteralPath $localizationScript -PathType Leaf)) { throw 'TrackerRadar.Localization.ps1 fehlt.' }
. $localizationScript
Initialize-TrackerRadarLocalization -Root $script:Root -Data $script:Data
$script:LastSnapshot = $null
$script:CurrentView = 'Overview'
$script:LanguageChanging = $false
function Get-StringHash {
    param([string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Test-PrivateAddress {
    param([string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { return $true }
    try { $ip = [System.Net.IPAddress]::Parse($Address) } catch { return $false }
    if ([System.Net.IPAddress]::IsLoopback($ip)) { return $true }
    if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
        if ($ip.IsIPv6LinkLocal -or $ip.IsIPv6SiteLocal -or $ip.IsIPv6Multicast) { return $true }
        $first = $ip.GetAddressBytes()[0]
        return (($first -band 0xFE) -eq 0xFC)
    }
    $b = $ip.GetAddressBytes()
    if ($b[0] -in @(0,10,127)) { return $true }
    if ($b[0] -eq 169 -and $b[1] -eq 254) { return $true }
    if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return $true }
    if ($b[0] -eq 192 -and $b[1] -eq 168) { return $true }
    if ($b[0] -ge 224) { return $true }
    return $false
}

function Test-SuspiciousPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = $Path.ToLowerInvariant()
    return ($p.Contains('\appdata\local\temp\') -or
            $p.Contains('\windows\temp\') -or
            $p.Contains('\downloads\') -or
            $p.Contains('\$recycle.bin\'))
}

function Get-ProcessMap {
    $map = @{}
    foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
        $path = ''
        try { $path = [string]$p.Path } catch { }
        $name = [string]$p.ProcessName
        if ($name -and -not $name.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
            $name += '.exe'
        }
        $map[[int]$p.Id] = [pscustomobject]@{
            Id = [int]$p.Id
            Name = $name
            Path = $path
        }
    }
    return $map
}

function Get-DnsCacheMap {
    $map = @{}
    $currentName = ''
    try {
        $lines = & ipconfig.exe /displaydns 2>$null
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -notmatch ':\s*(.+)$') { continue }
            $value = ([string]$Matches[1]).Trim().TrimEnd('.')
            if ([string]::IsNullOrWhiteSpace($value)) { continue }

            $parsedIp = $null
            if ([System.Net.IPAddress]::TryParse($value, [ref]$parsedIp)) {
                if (-not [string]::IsNullOrWhiteSpace($currentName) -and -not $map.ContainsKey($value)) {
                    $map[$value] = $currentName
                }
                continue
            }

            if ($value -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9-]{2,}$') {
                $currentName = $value.ToLowerInvariant()
            }
        }
    } catch { }
    return $map
}

function Get-TargetContext {
    param([string]$Domain, [string]$Address, [int]$Port)

    $d = ([string]$Domain).ToLowerInvariant()
    $provider = 'Unbekannter Dienst'
    $purpose = if ($Port -eq 443) { 'Verschluesselte Webverbindung' } elseif ($Port -eq 80) { 'Webverbindung' } else { "Netzwerkdienst auf Port $Port" }

    if ($d -match 'anthropic|claude') {
        $provider = 'Anthropic'
        $purpose = 'KI-Cloud-Dienst'
    } elseif ($d -match 'openai|chatgpt') {
        $provider = 'OpenAI'
        $purpose = 'KI-Cloud-Dienst'
    } elseif ($d -match 'microsoft|windows|office|live\.com|azure|msedge|teams') {
        $provider = 'Microsoft'
        $purpose = 'Microsoft- oder Windows-Onlinedienst'
    } elseif ($d -match 'google|gstatic|googleapis|youtube') {
        $provider = 'Google'
        $purpose = 'Google-Onlinedienst'
    } elseif ($d -match 'amazonaws|cloudfront|amazon') {
        $provider = 'Amazon Web Services'
        $purpose = 'Cloud- oder Inhaltsdienst'
    } elseif ($d -match 'cloudflare') {
        $provider = 'Cloudflare'
        $purpose = 'Netzwerk- oder Inhaltsdienst'
    } elseif ($d -match 'akamai|akamaiedge|edgekey') {
        $provider = 'Akamai'
        $purpose = 'Inhaltsauslieferung'
    } elseif ($d -match 'fastly') {
        $provider = 'Fastly'
        $purpose = 'Inhaltsauslieferung'
    } elseif ($d -match 'github|githubusercontent') {
        $provider = 'GitHub'
        $purpose = 'Software- oder Entwicklungsdienst'
    } elseif ($d -match 'dropbox') {
        $provider = 'Dropbox'
        $purpose = 'Cloud-Synchronisierung'
    } elseif ($d -match 'apple|icloud') {
        $provider = 'Apple'
        $purpose = 'Apple-Onlinedienst'
    }

    return [pscustomobject]@{
        Provider = $provider
        Purpose = $purpose
        DisplayTarget = if ([string]::IsNullOrWhiteSpace($Domain)) { $Address } else { $Domain }
    }
}

function Get-StateIndex {
    param($Items)
    $index = @{}
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $key = [string]$item.Key
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        $index[$key] = $item
    }
    return $index
}

function Get-ExternalConnections {
    param(
        [hashtable]$ProcessMap,
        [hashtable]$DnsMap,
        [hashtable]$KnownIndex,
        [hashtable]$PreviousIndex,
        [bool]$BaselineExists
    )

    $result = @()
    $lines = & netstat.exe -ano -p tcp 2>$null
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('TCP', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $parts = @($trimmed -split '\s+')
        if ($parts.Count -lt 5) { continue }
        $state = [string]$parts[3]
        if ($state -notin @('ESTABLISHED','HERGESTELLT')) { continue }

        $remote = [string]$parts[2]
        $pidValue = 0
        if (-not [int]::TryParse([string]$parts[4], [ref]$pidValue)) { continue }
        $lastColon = $remote.LastIndexOf(':')
        if ($lastColon -lt 1) { continue }
        $address = $remote.Substring(0, $lastColon).Trim('[',']')
        $port = 0
        [void][int]::TryParse($remote.Substring($lastColon + 1), [ref]$port)
        if (Test-PrivateAddress $address) { continue }

        $proc = if ($ProcessMap.ContainsKey($pidValue)) { $ProcessMap[$pidValue] } else { $null }
        $app = if ($proc) { $proc.Name } else { 'Unbekannt' }
        $path = if ($proc) { $proc.Path } else { '' }
        $identity = if ([string]::IsNullOrWhiteSpace($path)) { $app } else { $path }
        $key = ("{0}|{1}|{2}" -f $identity, $address, $port).ToLowerInvariant()
        $domain = if ($DnsMap.ContainsKey($address)) { [string]$DnsMap[$address] } else { '' }
        $context = Get-TargetContext -Domain $domain -Address $address -Port $port

        $firstSeen = (Get-Date).ToString('o')
        if ($KnownIndex.ContainsKey($key)) { $firstSeen = [string]$KnownIndex[$key].FirstSeen }
        $change = 'Baseline'
        if ($BaselineExists) {
            if (-not $KnownIndex.ContainsKey($key)) { $change = 'Neu' }
            elseif (-not $PreviousIndex.ContainsKey($key)) { $change = 'Wieder aktiv' }
            else { $change = 'Aktiv' }
        }

        $firstSeenDisplay = '-'
        try { $firstSeenDisplay = ([datetime]$firstSeen).ToString('dd.MM. HH:mm') } catch { }
        $result += [pscustomobject]@{
            Key = $key
            App = $app
            Pid = $pidValue
            Target = $context.DisplayTarget
            Domain = $domain
            Address = $address
            Provider = $context.Provider
            Purpose = $context.Purpose
            Port = $port
            Path = $path
            FirstSeen = $firstSeen
            FirstSeenDisplay = $firstSeenDisplay
            Change = $change
            Status = if ($change -eq 'Neu') { 'Neu entdeckt' } else { 'Erlaubt' }
            Risk = 0
            Reason = 'Aktive externe Verbindung'
        }
    }
    return @($result | Sort-Object App, Address, Port -Unique)
}

function Get-StartupEntries {
    param(
        [hashtable]$KnownIndex,
        [hashtable]$PreviousIdentityIndex,
        [bool]$BaselineExists
    )

    $result = @()
    $locations = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($location in $locations) {
        if (-not (Test-Path -LiteralPath $location)) { continue }
        try {
            $item = Get-ItemProperty -LiteralPath $location -ErrorAction Stop
            foreach ($property in $item.PSObject.Properties) {
                if ($property.Name.StartsWith('PS')) { continue }
                $command = [string]$property.Value
                $identityKey = ("{0}|{1}" -f $property.Name, $location).ToLowerInvariant()
                $key = ("{0}|{1}" -f $identityKey, $command).ToLowerInvariant()
                $change = 'Baseline'
                if ($BaselineExists) {
                    if (-not $KnownIndex.ContainsKey($key)) {
                        if ($PreviousIdentityIndex.ContainsKey($identityKey)) { $change = 'Geaendert' } else { $change = 'Neu' }
                    } else { $change = 'Bekannt' }
                }
                $firstSeen = (Get-Date).ToString('o')
                if ($KnownIndex.ContainsKey($key)) { $firstSeen = [string]$KnownIndex[$key].FirstSeen }
                $result += [pscustomobject]@{
                    Key = $key
                    IdentityKey = $identityKey
                    Name = [string]$property.Name
                    Command = $command
                    Location = $location
                    Suspicious = (Test-SuspiciousPath $command)
                    Change = $change
                    FirstSeen = $firstSeen
                }
            }
        } catch { }
    }

    $folders = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup')
    )
    foreach ($folder in $folders) {
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue) {
            $identityKey = ("{0}|{1}" -f $file.BaseName, $folder).ToLowerInvariant()
            $key = ("{0}|{1}" -f $identityKey, $file.FullName).ToLowerInvariant()
            $change = 'Baseline'
            if ($BaselineExists) {
                if (-not $KnownIndex.ContainsKey($key)) {
                    if ($PreviousIdentityIndex.ContainsKey($identityKey)) { $change = 'Geaendert' } else { $change = 'Neu' }
                } else { $change = 'Bekannt' }
            }
            $firstSeen = (Get-Date).ToString('o')
            if ($KnownIndex.ContainsKey($key)) { $firstSeen = [string]$KnownIndex[$key].FirstSeen }
            $result += [pscustomobject]@{
                Key = $key
                IdentityKey = $identityKey
                Name = $file.BaseName
                Command = $file.FullName
                Location = $folder
                Suspicious = (Test-SuspiciousPath $file.FullName)
                Change = $change
                FirstSeen = $firstSeen
            }
        }
    }
    return @($result)
}

function Get-Findings {
    param(
        [object[]]$Connections,
        [object[]]$StartupEntries,
        [object[]]$RemovedStartupEntries,
        [bool]$BaselineExists
    )

    $result = @()
    $scriptHosts = @('powershell.exe','pwsh.exe','cmd.exe','wscript.exe','cscript.exe','mshta.exe','rundll32.exe','regsvr32.exe')

    foreach ($group in $Connections | Group-Object Pid) {
        $first = $group.Group | Select-Object -First 1
        $score = 0
        $reasons = @()
        if (Test-SuspiciousPath $first.Path) {
            $score += 4
            $reasons += 'Start aus einem ungewoehnlichen Ordner'
        }
        if ($scriptHosts -contains ([string]$first.App).ToLowerInvariant()) {
            $score += 3
            $reasons += 'Script- oder Systemwerkzeug mit Internetzugriff'
        }
        if ([string]::IsNullOrWhiteSpace($first.Path)) {
            $score += 2
            $reasons += 'Programmpfad konnte nicht bestaetigt werden'
        }
        if ($group.Count -ge 12) {
            $score += 1
            $reasons += 'viele gleichzeitige Verbindungen'
        }
        if ($score -gt 0) {
            $level = if ($score -ge 7) { 'Kritisch' } elseif ($score -ge 4) { 'Verdaechtig' } else { 'Pruefen' }
            $result += [pscustomobject]@{
                App = [string]$first.App
                Score = $score
                Level = $level
                Summary = "$($first.App): $($reasons -join ', ')."
                Detail = "PID $($first.Pid), $($group.Count) Verbindung(en), Pfad: $($first.Path)"
            }
        }
    }

    foreach ($entry in $StartupEntries) {
        if ($entry.Suspicious) {
            $result += [pscustomobject]@{
                App = $entry.Name
                Score = 5
                Level = 'Verdaechtig'
                Summary = "$($entry.Name): Autostart aus einem ungewoehnlichen Ordner."
                Detail = $entry.Command
                ActionType = 'DisableStartup'
                StartupName = $entry.Name
                StartupLocation = $entry.Location
                StartupCommand = $entry.Command
            }
        } elseif ($BaselineExists -and $entry.Change -eq 'Neu') {
            $result += [pscustomobject]@{
                App = $entry.Name
                Score = 2
                Level = 'Neu'
                Summary = "$($entry.Name): neuer Autostart wurde entdeckt."
                Detail = "$($entry.Location)`n$($entry.Command)"
                ActionType = 'DisableStartup'
                StartupName = $entry.Name
                StartupLocation = $entry.Location
                StartupCommand = $entry.Command
            }
        } elseif ($BaselineExists -and $entry.Change -eq 'Geaendert') {
            $result += [pscustomobject]@{
                App = $entry.Name
                Score = 3
                Level = 'Geaendert'
                Summary = "$($entry.Name): bestehender Autostart wurde veraendert."
                Detail = "$($entry.Location)`n$($entry.Command)"
                ActionType = 'DisableStartup'
                StartupName = $entry.Name
                StartupLocation = $entry.Location
                StartupCommand = $entry.Command
            }
        }
    }

    foreach ($entry in $RemovedStartupEntries) {
        $result += [pscustomobject]@{
            App = $entry.Name
            Score = 0
            Level = 'Info'
            Summary = "$($entry.Name): Autostart ist nicht mehr vorhanden."
            Detail = "$($entry.Location)`n$($entry.Command)"
        }
    }

    if ($Connections.Count -eq 0) {
        $result += [pscustomobject]@{
            App = 'TrackerRadar'
            Score = 0
            Level = 'Info'
            Summary = 'Aktuell keine externen TCP-Verbindungen erkannt.'
            Detail = 'Dies ist eine Momentaufnahme.'
        }
    }

    return @($result | Sort-Object Score -Descending | Select-Object -First 30)
}

function Save-State {
    param(
        [object[]]$Connections,
        [object[]]$StartupEntries,
        $KnownState
    )

    $now = (Get-Date).ToString('o')
    $knownConnections = @($KnownState.KnownConnections)
    $knownApps = @($KnownState.KnownApps)
    $knownStartups = @($KnownState.KnownStartups)
    $connectionIndex = Get-StateIndex $knownConnections
    $appIndex = Get-StateIndex $knownApps
    $startupIndex = Get-StateIndex $knownStartups

    foreach ($connection in $Connections) {
        if (-not $connectionIndex.ContainsKey($connection.Key)) {
            $item = [pscustomobject]@{ Key=$connection.Key; FirstSeen=$now; App=$connection.App; Target=$connection.Target; Address=$connection.Address; Port=$connection.Port }
            $knownConnections += $item
            $connectionIndex[$connection.Key] = $item
        }
        $appKey = ([string]$connection.App).ToLowerInvariant()
        if (-not $appIndex.ContainsKey($appKey)) {
            $item = [pscustomobject]@{ Key=$appKey; FirstSeen=$now; App=$connection.App }
            $knownApps += $item
            $appIndex[$appKey] = $item
        }
    }
    foreach ($startup in $StartupEntries) {
        if (-not $startupIndex.ContainsKey($startup.Key)) {
            $item = [pscustomobject]@{ Key=$startup.Key; FirstSeen=$now; Name=$startup.Name; Command=$startup.Command; Location=$startup.Location }
            $knownStartups += $item
            $startupIndex[$startup.Key] = $item
        }
    }

    $newKnownState = [pscustomobject]@{
        Version = 1
        UpdatedAt = $now
        KnownConnections = $knownConnections
        KnownApps = $knownApps
        KnownStartups = $knownStartups
    }
    Write-JsonFile -Path (Join-Path $script:State 'known-state.json') -Value $newKnownState -Depth 8

    $previousState = [pscustomobject]@{
        Timestamp = $now
        Connections = @($Connections | Select-Object Key,App,Target,Address,Port,Path)
        Startups = @($StartupEntries | Select-Object Key,IdentityKey,Name,Command,Location)
    }
    Write-JsonFile -Path (Join-Path $script:State 'previous-state.json') -Value $previousState -Depth 7
}

function Write-HistoryEvent {
    param($Snapshot, [string[]]$ConnectionKeys, [string[]]$StartupKeys)

    $lastPath = Join-Path $script:State 'last-history.json'
    $last = Read-JsonFile $lastPath
    $fingerprintSource = (@($ConnectionKeys | Sort-Object) -join ';') + '|' + (@($StartupKeys | Sort-Object) -join ';') + "|$($Snapshot.FindingCount)|$($Snapshot.NewCount)"
    $fingerprint = Get-StringHash $fingerprintSource
    $now = Get-Date
    $shouldWrite = $true
    if ($last -and [string]$last.Fingerprint -eq $fingerprint) {
        try {
            $lastTime = [datetime]$last.Timestamp
            if (($now - $lastTime).TotalMinutes -lt 15) { $shouldWrite = $false }
        } catch { }
    }
    if (-not $shouldWrite) { return }

    $changes = @()
    foreach ($activity in @($Snapshot.Activities | Where-Object { $_.Change -in @('Neu','Wieder aktiv') } | Select-Object -First 8)) {
        $changes += "$($activity.Change): $($activity.App) -> $($activity.Target)"
    }
    foreach ($finding in @($Snapshot.Findings | Where-Object { $_.Level -in @('Neu','Geaendert','Kritisch','Verdaechtig') } | Select-Object -First 8)) {
        $changes += $finding.Summary
    }

    $event = [pscustomobject]@{
        Timestamp = $now.ToString('o')
        ActiveApps = $Snapshot.ActiveApps
        ExternalConnections = $Snapshot.ExternalConnections
        NewCount = $Snapshot.NewCount
        FindingCount = $Snapshot.FindingCount
        CriticalCount = $Snapshot.CriticalCount
        Changes = @($changes | Select-Object -Unique)
        Summary = "$($Snapshot.ActiveApps) Apps, $($Snapshot.ExternalConnections) Verbindungen, $($Snapshot.NewCount) neu, $($Snapshot.FindingCount) Befunde"
    }
    $line = $event | ConvertTo-Json -Depth 5 -Compress
    $historyPath = Join-Path $script:History ((Get-Date -Format 'yyyy-MM-dd') + '.jsonl')
    [System.IO.File]::AppendAllText($historyPath, $line + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    Write-JsonFile -Path $lastPath -Value ([pscustomobject]@{ Timestamp=$now.ToString('o'); Fingerprint=$fingerprint }) -Depth 3

    $cutoff = (Get-Date).Date.AddDays(-7)
    foreach ($file in Get-ChildItem -LiteralPath $script:History -Filter '*.jsonl' -File -ErrorAction SilentlyContinue) {
        if ($file.LastWriteTime -lt $cutoff) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue }
    }
}

function Get-HistoryRows {
    param([int]$Maximum = 100)
    $rows = @()
    $files = @(Get-ChildItem -LiteralPath $script:History -Filter '*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    foreach ($file in $files) {
        foreach ($line in @(Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $event = $line | ConvertFrom-Json -ErrorAction Stop
                $timeDisplay = try { ([datetime]$event.Timestamp).ToString('dd.MM.yyyy HH:mm') } catch { [string]$event.Timestamp }
                $changeText = @($event.Changes) -join ' | '
                $rows += [pscustomobject]@{
                    Timestamp = [string]$event.Timestamp
                    Time = $timeDisplay
                    Apps = [int]$event.ActiveApps
                    Connections = [int]$event.ExternalConnections
                    New = [int]$event.NewCount
                    Findings = [int]$event.FindingCount
                    Summary = [string]$event.Summary
                    Changes = $changeText
                }
            } catch { }
        }
    }
    return @($rows | Sort-Object Timestamp -Descending | Select-Object -First $Maximum)
}

function Get-Snapshot {
    $started = Get-Date
    $knownPath = Join-Path $script:State 'known-state.json'
    $previousPath = Join-Path $script:State 'previous-state.json'
    $baselineExists = Test-Path -LiteralPath $knownPath

    $knownState = Read-JsonFile $knownPath
    if (-not $knownState) {
        $knownState = [pscustomobject]@{ KnownConnections=@(); KnownApps=@(); KnownStartups=@() }
    }
    $previousState = Read-JsonFile $previousPath
    if (-not $previousState) {
        $previousState = [pscustomobject]@{ Connections=@(); Startups=@() }
    }

    $knownConnectionIndex = Get-StateIndex $knownState.KnownConnections
    $knownStartupIndex = Get-StateIndex $knownState.KnownStartups
    $previousConnectionIndex = Get-StateIndex $previousState.Connections
    $previousStartupIdentityIndex = @{}
    foreach ($item in @($previousState.Startups)) {
        if ($item -and -not [string]::IsNullOrWhiteSpace([string]$item.IdentityKey)) {
            $previousStartupIdentityIndex[[string]$item.IdentityKey] = $item
        }
    }

    $processes = Get-ProcessMap
    $dnsMap = Get-DnsCacheMap
    $connections = @(Get-ExternalConnections -ProcessMap $processes -DnsMap $dnsMap -KnownIndex $knownConnectionIndex -PreviousIndex $previousConnectionIndex -BaselineExists $baselineExists)
    $startups = @(Get-StartupEntries -KnownIndex $knownStartupIndex -PreviousIdentityIndex $previousStartupIdentityIndex -BaselineExists $baselineExists)

    $currentStartupIdentityIndex = @{}
    foreach ($item in $startups) { $currentStartupIdentityIndex[$item.IdentityKey] = $item }
    $removedStartups = @()
    if ($baselineExists) {
        foreach ($old in @($previousState.Startups)) {
            if ($old -and -not $currentStartupIdentityIndex.ContainsKey([string]$old.IdentityKey)) { $removedStartups += $old }
        }
    }

    $findings = @(Get-Findings -Connections $connections -StartupEntries $startups -RemovedStartupEntries $removedStartups -BaselineExists $baselineExists)
    foreach ($connection in $connections) {
        $finding = $findings | Where-Object { $_.App -eq $connection.App -and $_.Score -gt 0 } | Select-Object -First 1
        if ($finding) {
            $connection.Risk = [int]$finding.Score
            $connection.Status = [string]$finding.Level
            $connection.Reason = [string]$finding.Summary
        }
    }

    $newConnections = @($connections | Where-Object { $_.Change -eq 'Neu' })
    $newStartups = @($startups | Where-Object { $_.Change -in @('Neu','Geaendert') })
    $newCount = $newConnections.Count + $newStartups.Count
    $snapshot = [pscustomobject]@{
        Product = 'TrackerRadar Alpha'
        Version = $script:Version
        Timestamp = (Get-Date).ToString('o')
        DurationMs = [int]((Get-Date) - $started).TotalMilliseconds
        BaselineExists = $baselineExists
        BaselineMessage = if ($baselineExists) { 'Baseline aktiv' } else { 'Baseline wurde erstellt' }
        ExternalConnections = $connections.Count
        ActiveApps = @($connections | Select-Object -ExpandProperty Pid -Unique).Count
        StartupEntries = $startups.Count
        NewCount = $newCount
        NewConnections = $newConnections.Count
        NewStartups = $newStartups.Count
        FindingCount = @($findings | Where-Object { $_.Score -gt 0 }).Count
        CriticalCount = @($findings | Where-Object { $_.Score -ge 7 }).Count
        Activities = @($connections | Sort-Object @{Expression='Risk';Descending=$true}, @{Expression={ if ($_.Change -eq 'Neu') {0} elseif ($_.Change -eq 'Wieder aktiv') {1} else {2} };Descending=$false}, @{Expression='App';Descending=$false} | Select-Object -First 100)
        Findings = $findings
        Startup = $startups
        RemovedStartup = $removedStartups
        History = @()
        Limitations = @(
            'Momentaufnahme aktiver externer TCP-Verbindungen',
            'Domainnamen stammen aus dem lokalen Windows-DNS-Cache und sind nicht immer verfuegbar',
            'Keine Entschluesselung von HTTPS-Inhalten',
            'Dateizugriffe werden nur im bewusst gestarteten Kurzscan erfasst; keine Dauerueberwachung'
        )
    }

    Save-State -Connections $connections -StartupEntries $startups -KnownState $knownState
    Write-HistoryEvent -Snapshot $snapshot -ConnectionKeys @($connections | Select-Object -ExpandProperty Key) -StartupKeys @($startups | Select-Object -ExpandProperty Key)
    $snapshot.History = @(Get-HistoryRows -Maximum 100)
    Write-JsonFile -Path (Join-Path $script:Data 'latest-scan.json') -Value $snapshot -Depth 9
    return $snapshot
}

function Invoke-SelfTest {
    $checks = @()
    $checks += [pscustomobject]@{ Name='PowerShell'; Passed=($PSVersionTable.PSVersion.Major -ge 5); Detail=$PSVersionTable.PSVersion.ToString() }
    $checks += [pscustomobject]@{ Name='netstat'; Passed=[bool](Get-Command netstat.exe -ErrorAction SilentlyContinue); Detail='Windows-Netzwerkerfassung' }
    $checks += [pscustomobject]@{ Name='ipconfig'; Passed=[bool](Get-Command ipconfig.exe -ErrorAction SilentlyContinue); Detail='Lokaler DNS-Cache' }
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $checks += [pscustomobject]@{ Name='WPF'; Passed=$true; Detail='PresentationFramework geladen' }
    } catch {
        $checks += [pscustomobject]@{ Name='WPF'; Passed=$false; Detail=$_.Exception.Message }
    }
    $checks += [pscustomobject]@{ Name='AccessScan'; Passed=(Test-Path -LiteralPath (Join-Path $script:Root 'TrackerRadar.AccessScan.ps1') -PathType Leaf); Detail='Manueller File-I/O-Kurzscan' }
    $checks += [pscustomobject]@{ Name='AccessScanWrapper'; Passed=(Test-Path -LiteralPath (Join-Path $script:Root 'TrackerRadar.AccessScan.Elevated.ps1') -PathType Leaf); Detail='Sichtbare UAC-Ausfuehrung' }
    try {
        $snapshot = Get-Snapshot
        $checks += [pscustomobject]@{ Name='Live-Snapshot'; Passed=$true; Detail="$($snapshot.ExternalConnections) Verbindung(en), $($snapshot.DurationMs) ms" }
        $checks += [pscustomobject]@{ Name='Baseline'; Passed=(Test-Path -LiteralPath (Join-Path $script:State 'known-state.json')); Detail=$snapshot.BaselineMessage }
        $checks += [pscustomobject]@{ Name='Verlauf'; Passed=(@(Get-ChildItem -LiteralPath $script:History -Filter '*.jsonl' -File -ErrorAction SilentlyContinue).Count -gt 0); Detail="$(@($snapshot.History).Count) sichtbare Verlaufseintraege" }
        $checks += [pscustomobject]@{ Name='Bericht'; Passed=(Test-Path -LiteralPath (Join-Path $script:Data 'latest-scan.json')); Detail=(Join-Path $script:Data 'latest-scan.json') }
    } catch {
        $checks += [pscustomobject]@{ Name='Live-Snapshot'; Passed=$false; Detail=$_.Exception.Message }
    }
    $result = [pscustomobject]@{
        Product='TrackerRadar Alpha'
        Version=$script:Version
        Timestamp=(Get-Date).ToString('o')
        Passed=@($checks | Where-Object { $_.Passed }).Count
        Failed=@($checks | Where-Object { -not $_.Passed }).Count
        Checks=$checks
    }
    Write-JsonFile -Path (Join-Path $script:Data 'self-test.json') -Value $result -Depth 6
    $result | ConvertTo-Json -Depth 6
    if ($result.Failed -gt 0) { exit 1 }
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if ($ExportOnly) {
    Get-Snapshot | ConvertTo-Json -Depth 9
    exit 0
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TrackerRadar 0.5.5 Alpha | SC LABS" Width="1180" Height="720" MinWidth="960" MinHeight="620" UseLayoutRounding="True" SnapsToDevicePixels="True"
        WindowStartupLocation="CenterScreen" Background="#071018" Foreground="#ECF3F7"
        FontFamily="Segoe UI" FontSize="14">
    <Window.Resources>
        <SolidColorBrush x:Key="Panel" Color="#0D1922"/>
        <SolidColorBrush x:Key="PanelAlt" Color="#10212B"/>
        <SolidColorBrush x:Key="Line" Color="#1B3442"/>
        <SolidColorBrush x:Key="Accent" Color="#25D7C0"/>
        <SolidColorBrush x:Key="Green" Color="#38D27C"/>
        <SolidColorBrush x:Key="Amber" Color="#F2A93B"/>
        <SolidColorBrush x:Key="Red" Color="#FF5D68"/>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#ECF3F7"/>
            <Setter Property="Background" Value="#103A38"/>
            <Setter Property="BorderBrush" Value="#25D7C0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="18,11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonChrome" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="11" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonChrome" Property="Background" Value="#174A47"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonChrome" Property="Background" Value="#0D2E2C"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonChrome" Property="Opacity" Value="0.55"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Foreground" Value="#AABAC4"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Padding" Value="12,10"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Margin" Value="0,2,0,2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="NavChrome" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="NavChrome" Property="Background" Value="#102630"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="LanguageComboBoxItem" TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="#DCE8ED"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Padding" Value="12,9"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="ItemChrome" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemChrome" Property="Background" Value="#174A47"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemChrome" Property="Background" Value="#103A38"/>
                                <Setter Property="Foreground" Value="#6BE7D6"/>
                                <Setter Property="FontWeight" Value="SemiBold"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="LanguageComboBox" TargetType="ComboBox">
            <Setter Property="Foreground" Value="#ECF3F7"/>
            <Setter Property="Background" Value="#0D1922"/>
            <Setter Property="BorderBrush" Value="#24776F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Height" Value="52"/>
            <Setter Property="MinWidth" Value="132"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource LanguageComboBoxItem}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <Border x:Name="ComboChrome" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="11">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
                                    <ContentPresenter Margin="13,0,7,0" VerticalAlignment="Center" HorizontalAlignment="Left" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
                                    <Border Grid.Column="1" Margin="0,7,7,7" Background="#102630" CornerRadius="8">
                                        <Path Width="9" Height="5" Stretch="Fill" Fill="#6BE7D6" Data="M 0 0 L 4.5 5 L 9 0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                </Grid>
                            </Border>
                            <ToggleButton Focusable="False" Background="Transparent" BorderThickness="0" ClickMode="Press" IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border Background="Transparent"/></ControlTemplate></ToggleButton.Template>
                            </ToggleButton>
                            <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade" IsOpen="{TemplateBinding IsDropDownOpen}">
                                <Border Margin="0,5,0,0" MinWidth="{TemplateBinding ActualWidth}" Background="#0B1720" BorderBrush="#25D7C0" BorderThickness="1" CornerRadius="11" Padding="5">
                                    <ScrollViewer MaxHeight="220" VerticalScrollBarVisibility="Auto"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ComboChrome" Property="Background" Value="#102630"/>
                                <Setter TargetName="ComboChrome" Property="BorderBrush" Value="#25D7C0"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="ComboChrome" Property="BorderBrush" Value="#25D7C0"/></Trigger>
                            <Trigger Property="IsDropDownOpen" Value="True">
                                <Setter TargetName="ComboChrome" Property="Background" Value="#103A38"/>
                                <Setter TargetName="ComboChrome" Property="BorderBrush" Value="#6BE7D6"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ComboChrome" Property="Opacity" Value="0.55"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#0D1922"/>
            <Setter Property="Foreground" Value="#ECF3F7"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#1B3442"/>
            <Setter Property="RowBackground" Value="#0D1922"/>
            <Setter Property="AlternatingRowBackground" Value="#10212B"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="AutoGenerateColumns" Value="False"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="SelectionMode" Value="Single"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#112731"/>
            <Setter Property="Foreground" Value="#92A8B4"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="BorderBrush" Value="#1B3442"/>
        </Style>
        <Style TargetType="DataGridCell"><Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="9,7"/></Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="205"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>

        <Border Grid.Column="0" Background="#08141D" BorderBrush="#18303D" BorderThickness="0,0,1,0">
            <Grid Margin="20">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel>
                    <StackPanel Orientation="Horizontal">
                        <Border Width="48" Height="48" CornerRadius="10" Background="#00020A" BorderBrush="#234455" BorderThickness="1" ClipToBounds="True"><Image x:Name="ScLabsLogo" Stretch="Uniform" SnapsToDevicePixels="True" RenderTransformOrigin="0.5,0.5"><Image.RenderTransform><ScaleTransform ScaleX="1.12" ScaleY="1.12"/></Image.RenderTransform></Image></Border>
                        <StackPanel Margin="10,6,0,0"><TextBlock Text="SC LABS" FontSize="16" FontWeight="Bold"/><TextBlock Text="PRODUCT SERIES" FontSize="9" Foreground="#718B99"/></StackPanel>
                    </StackPanel>
                    <Border Margin="0,20,0,0" Height="132" CornerRadius="12" Background="#00020A" BorderBrush="#234455" BorderThickness="1" ClipToBounds="True"><Image x:Name="TrackerRadarLogo" Stretch="Uniform" SnapsToDevicePixels="True" RenderTransformOrigin="0.5,0.5"><Image.RenderTransform><ScaleTransform ScaleX="1.20" ScaleY="1.20"/></Image.RenderTransform></Image></Border>
                    <TextBlock x:Name="TaglineText" Text="Sieh, was Programme wirklich tun." Margin="0,10,0,0" Foreground="#8EA2AF" TextWrapping="Wrap"/>
                </StackPanel>
                <StackPanel Grid.Row="1" Margin="0,30,0,0">
                    <Button x:Name="NavOverview" Style="{StaticResource NavButton}" Content="Uebersicht"/>
                    <Button x:Name="NavActivities" Style="{StaticResource NavButton}" Content="Aktivitaeten"/>
                    <Button x:Name="NavFindings" Style="{StaticResource NavButton}" Content="Befunde"/>
                    <Button x:Name="NavHistory" Style="{StaticResource NavButton}" Content="Verlauf"/>
                    <Button x:Name="NavAccess" Style="{StaticResource NavButton}" Content="Dateizugriffe"/>
                    <Button x:Name="NavChanges" Style="{StaticResource NavButton}" Content="Aenderungen"/>
                </StackPanel>
                <Border Grid.Row="3" Background="#0E211D" BorderBrush="#1C523F" BorderThickness="1" CornerRadius="12" Padding="12">
                    <StackPanel>
                        <TextBlock x:Name="PrivacyTitleText" Text="LOKAL UND PRIVAT" Foreground="{StaticResource Green}" FontWeight="SemiBold"/>
                        <TextBlock x:Name="PrivacyBodyText" Text="Keine Cloud. Keine Telemetrie." Foreground="#8FA8A0" Margin="0,4,0,0" FontSize="12"/>
                        <TextBlock x:Name="MoreProductsTitleText" Text="WEITERE SC LABS APPS" Foreground="#718B99" Margin="0,10,0,3" FontSize="9" FontWeight="SemiBold"/>
                        <TextBlock x:Name="ScLabsWebsiteLinkText" Text="sclabs.uk" Foreground="#49C8D8" FontSize="12" FontWeight="SemiBold" TextDecorations="Underline" Cursor="Hand" Tag="https://sclabs.uk/" ToolTip="https://sclabs.uk/"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <Grid Grid.Column="1" Margin="27,21,27,18">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="14"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel VerticalAlignment="Center"><TextBlock x:Name="ViewTitle" Text="Uebersicht" FontSize="27" FontWeight="SemiBold"/><TextBlock x:Name="ViewSubtitle" Text="Neue Aktivitaeten und wichtige Aenderungen auf einen Blick." Foreground="#91A5B2" Margin="0,5,0,0"/></StackPanel>
                <ComboBox x:Name="LanguageSelector" Grid.Column="1" Style="{StaticResource LanguageComboBox}" VerticalAlignment="Center" ToolTip="Deutsch / English">
                    <ComboBoxItem Tag="de" Content="Deutsch"/>
                    <ComboBoxItem Tag="en" Content="English"/>
                </ComboBox>
                <Button x:Name="ScanButton" Grid.Column="3" Content="Jetzt pruefen" MinWidth="132" Height="52" VerticalAlignment="Center"/>
            </Grid>

            <Grid Grid.Row="1" Margin="0,20,0,0">
                <Grid x:Name="OverviewView">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <Grid Margin="0,0,0,18">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17"><StackPanel><TextBlock x:Name="OverviewAppsLabel" Text="Internetaktive Apps" Foreground="#92A6B2"/><TextBlock x:Name="AppsCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Accent}" Margin="0,4,0,0"/></StackPanel></Border>
                        <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17"><StackPanel><TextBlock x:Name="OverviewNewLabel" Text="Neu entdeckt" Foreground="#92A6B2"/><TextBlock x:Name="NewCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Amber}" Margin="0,4,0,0"/></StackPanel></Border>
                        <Border Grid.Column="4" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17"><StackPanel><TextBlock x:Name="OverviewFindingsLabel" Text="Befunde" Foreground="#92A6B2"/><TextBlock x:Name="FindingsCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Red}" Margin="0,4,0,0"/><TextBlock x:Name="CriticalHint" Text="0 kritisch" FontSize="11" Foreground="#8DA1AD"/></StackPanel></Border>
                    </Grid>
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="1.55*"/><ColumnDefinition Width="17"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                            <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                                <StackPanel Margin="17,14,17,11"><TextBlock x:Name="CurrentActivitiesTitle" Text="Aktuelle Aktivitaeten" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="CurrentActivitiesHint" Text="Ziele werden aus dem lokalen DNS-Cache erklaert" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                                <DataGrid x:Name="OverviewActivityGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.15*"/><DataGridTextColumn Header="ZIEL" Binding="{Binding Target}" Width="1.5*"/><DataGridTextColumn Header="STATUS" Binding="{Binding Change}" Width="105"/></DataGrid.Columns></DataGrid>
                            </Grid>
                        </Border>
                        <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                            <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <StackPanel Margin="17,14,17,11"><TextBlock x:Name="ImportantFindingsTitle" Text="Wichtigste Befunde" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="ImportantFindingsHint" Text="Gebuedelt statt Warnungsflut" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                                <ListBox x:Name="OverviewFindingsList" Grid.Row="1" Background="Transparent" BorderThickness="0" Foreground="#ECF3F7" DisplayMemberPath="Summary" Padding="10"/>
                                <Button x:Name="ReportButton" Grid.Row="2" Content="Lokalen Bericht oeffnen" Margin="15"/>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>

                <Border x:Name="ActivitiesView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock x:Name="ActivitiesPanelTitle" Text="Alle aktiven Internetverbindungen" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="ActivitiesPanelHint" Text="Domain, Anbieter, IP-Adresse und erster Erkennungszeitpunkt" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="ActivityGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.1*"/><DataGridTextColumn Header="ZIEL" Binding="{Binding Target}" Width="1.35*"/><DataGridTextColumn Header="ANBIETER" Binding="{Binding Provider}" Width="1.15*"/><DataGridTextColumn Header="IP" Binding="{Binding Address}" Width="1.05*"/><DataGridTextColumn Header="PORT" Binding="{Binding Port}" Width="60"/><DataGridTextColumn Header="STATUS" Binding="{Binding Change}" Width="100"/><DataGridTextColumn Header="ERSTMALS" Binding="{Binding FirstSeenDisplay}" Width="105"/></DataGrid.Columns></DataGrid>
                        <Button x:Name="BlockInternetButton" Grid.Row="2" Content="Internetzugriff blockieren" HorizontalAlignment="Right" MinWidth="235" Margin="15" IsEnabled="False" Tag="Block"/>
                    </Grid>
                </Border>

                <Border x:Name="FindingsView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock x:Name="FindingsPanelTitle" Text="Befunde und Systemaenderungen" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="FindingsPanelHint" Text="Neue oder veraenderte Autostarts und auffaelliges Prozessverhalten" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="FindingsGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="STUFE" Binding="{Binding Level}" Width="95"/><DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.0*"/><DataGridTextColumn Header="BEGRUENDUNG" Binding="{Binding Summary}" Width="2.8*"/><DataGridTextColumn Header="PUNKTE" Binding="{Binding Score}" Width="70"/></DataGrid.Columns></DataGrid>
                        <Button x:Name="DisableStartupButton" Grid.Row="2" Content="Ausgewaehlten Autostart deaktivieren" HorizontalAlignment="Right" MinWidth="270" Margin="15"/>
                    </Grid>
                </Border>

                <Border x:Name="HistoryView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock x:Name="HistoryPanelTitle" Text="Lokaler 7-Tage-Verlauf" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="HistoryPanelHint" Text="Es wird nur bei Aenderungen oder spaetestens alle 15 Minuten gespeichert" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="HistoryGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="ZEIT" Binding="{Binding Time}" Width="135"/><DataGridTextColumn Header="APPS" Binding="{Binding Apps}" Width="60"/><DataGridTextColumn Header="VERBINDUNGEN" Binding="{Binding Connections}" Width="105"/><DataGridTextColumn Header="NEU" Binding="{Binding New}" Width="55"/><DataGridTextColumn Header="BEFUNDE" Binding="{Binding Findings}" Width="70"/><DataGridTextColumn Header="ZUSAMMENFASSUNG" Binding="{Binding Summary}" Width="2.5*"/></DataGrid.Columns></DataGrid>
                    </Grid>
                </Border>

                <Border x:Name="AccessView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <Grid Margin="17,14,17,11"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <StackPanel><TextBlock x:Name="AccessPanelTitle" Text="Manueller Datei- und Ordnerzugriffs-Scan" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="AccessPanelHint" Text="Fuenf Sekunden, lokale Windows-Ereignisse, keine Dateiinhalte und keine einzelnen Dateinamen" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                            <Button x:Name="AccessScanButton" Grid.Column="1" Content="5-Sekunden-Scan starten" MinWidth="210" Margin="15,0,0,0"/>
                        </Grid>
                        <DataGrid x:Name="AccessGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="APP" Binding="{Binding ProcessName}" Width="1.15*"/><DataGridTextColumn Header="PID" Binding="{Binding ProcessId}" Width="70"/><DataGridTextColumn Header="ORDNER" Binding="{Binding Folder}" Width="1.1*"/><DataGridTextColumn Header="AKTION" Binding="{Binding Operation}" Width="130"/><DataGridTextColumn Header="ZUGRIFFE" Binding="{Binding AccessCount}" Width="85"/><DataGridTextColumn Header="PROGRAMMPFAD" Binding="{Binding ExecutablePath}" Width="2.2*"/></DataGrid.Columns></DataGrid>
                        <TextBlock x:Name="AccessSummary" Grid.Row="2" Text="Noch kein Kurzscan vorhanden." Foreground="#8DA1AD" TextWrapping="Wrap" Margin="17,11,17,14"/>
                    </Grid>
                </Border>

                <Border x:Name="ChangesView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock x:Name="ChangesPanelTitle" Text="Change Vault" FontSize="18" FontWeight="SemiBold"/><TextBlock x:Name="ChangesPanelHint" Text="Jede genehmigte Systemaenderung mit sicherer Ruecknahme" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="ChangeGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="ZEIT" Binding="{Binding Time}" Width="135"/><DataGridTextColumn Header="AKTION" Binding="{Binding DisplayAction}" Width="1.25*"/><DataGridTextColumn Header="ZIEL" Binding="{Binding TargetName}" Width="1.55*"/><DataGridTextColumn Header="STATUS" Binding="{Binding StatusDisplay}" Width="115"/></DataGrid.Columns></DataGrid>
                        <Button x:Name="UndoChangeButton" Grid.Row="2" Content="Ausgewaehlte Aenderung rueckgaengig" HorizontalAlignment="Right" MinWidth="280" Margin="15"/>
                    </Grid>
                </Border>
            </Grid>

            <Grid Grid.Row="2" Margin="0,13,0,0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <TextBlock x:Name="StatusText" Text="Bereit" Foreground="#8DA1AD" TextTrimming="CharacterEllipsis"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,12,0">
                    <TextBlock x:Name="FooterVersionText" Text="TrackerRadar 0.5.5 Alpha | SC LABS" Foreground="#627985" FontSize="12" VerticalAlignment="Center"/>
                    <TextBlock Text="  |  " Foreground="#36515F" FontSize="12" VerticalAlignment="Center"/>
                    <TextBlock x:Name="FooterMalwareRadarLinkText" Text="MalwareRadar" Foreground="#49C8D8" FontSize="12" FontWeight="SemiBold" TextDecorations="Underline" Cursor="Hand" VerticalAlignment="Center" Tag="https://sclabs.uk/products/malwareradar/" ToolTip="https://sclabs.uk/products/malwareradar/"/>
                    <TextBlock Text="  |  " Foreground="#36515F" FontSize="12" VerticalAlignment="Center"/>
                    <TextBlock x:Name="FooterPrivacyRadarLinkText" Text="PrivacyRadar" Foreground="#49C8D8" FontSize="12" FontWeight="SemiBold" TextDecorations="Underline" Cursor="Hand" VerticalAlignment="Center" Tag="https://sclabs.uk/products/privacyradar/" ToolTip="https://sclabs.uk/products/privacyradar/"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$reader.Close()
$xaml = $null
$reader = $null

$scanButton = $window.FindName('ScanButton')
$reportButton = $window.FindName('ReportButton')
$overviewActivityGrid = $window.FindName('OverviewActivityGrid')
$overviewFindingsList = $window.FindName('OverviewFindingsList')
$activityGrid = $window.FindName('ActivityGrid')
$findingsGrid = $window.FindName('FindingsGrid')
$historyGrid = $window.FindName('HistoryGrid')
$accessGrid = $window.FindName('AccessGrid')
$accessSummary = $window.FindName('AccessSummary')
$accessScanButton = $window.FindName('AccessScanButton')
$changeGrid = $window.FindName('ChangeGrid')
$blockInternetButton = $window.FindName('BlockInternetButton')
$disableStartupButton = $window.FindName('DisableStartupButton')
$undoChangeButton = $window.FindName('UndoChangeButton')
$appsCount = $window.FindName('AppsCount')
$newCount = $window.FindName('NewCount')
$findingsCount = $window.FindName('FindingsCount')
$criticalHint = $window.FindName('CriticalHint')
$statusText = $window.FindName('StatusText')
$viewTitle = $window.FindName('ViewTitle')
$viewSubtitle = $window.FindName('ViewSubtitle')
$scLabsLogo = $window.FindName('ScLabsLogo')
$trackerRadarLogo = $window.FindName('TrackerRadarLogo')
$navOverview = $window.FindName('NavOverview')
$navActivities = $window.FindName('NavActivities')
$navFindings = $window.FindName('NavFindings')
$navHistory = $window.FindName('NavHistory')
$navAccess = $window.FindName('NavAccess')
$navChanges = $window.FindName('NavChanges')
$overviewView = $window.FindName('OverviewView')
$activitiesView = $window.FindName('ActivitiesView')
$findingsView = $window.FindName('FindingsView')
$historyView = $window.FindName('HistoryView')
$accessView = $window.FindName('AccessView')
$changesView = $window.FindName('ChangesView')
$languageSelector = $window.FindName('LanguageSelector')
$taglineText = $window.FindName('TaglineText')
$privacyTitleText = $window.FindName('PrivacyTitleText')
$privacyBodyText = $window.FindName('PrivacyBodyText')
$moreProductsTitleText = $window.FindName('MoreProductsTitleText')
$scLabsWebsiteLinkText = $window.FindName('ScLabsWebsiteLinkText')
$footerVersionText = $window.FindName('FooterVersionText')
$footerMalwareRadarLinkText = $window.FindName('FooterMalwareRadarLinkText')
$footerPrivacyRadarLinkText = $window.FindName('FooterPrivacyRadarLinkText')
$overviewAppsLabel = $window.FindName('OverviewAppsLabel')
$overviewNewLabel = $window.FindName('OverviewNewLabel')
$overviewFindingsLabel = $window.FindName('OverviewFindingsLabel')
$currentActivitiesTitle = $window.FindName('CurrentActivitiesTitle')
$currentActivitiesHint = $window.FindName('CurrentActivitiesHint')
$importantFindingsTitle = $window.FindName('ImportantFindingsTitle')
$importantFindingsHint = $window.FindName('ImportantFindingsHint')
$activitiesPanelTitle = $window.FindName('ActivitiesPanelTitle')
$activitiesPanelHint = $window.FindName('ActivitiesPanelHint')
$findingsPanelTitle = $window.FindName('FindingsPanelTitle')
$findingsPanelHint = $window.FindName('FindingsPanelHint')
$historyPanelTitle = $window.FindName('HistoryPanelTitle')
$historyPanelHint = $window.FindName('HistoryPanelHint')
$accessPanelTitle = $window.FindName('AccessPanelTitle')
$accessPanelHint = $window.FindName('AccessPanelHint')
$changesPanelTitle = $window.FindName('ChangesPanelTitle')
$changesPanelHint = $window.FindName('ChangesPanelHint')
function Set-UiImage {
    param([Parameter(Mandatory)]$Control, [Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.UriSource = New-Object System.Uri($Path)
    $bitmap.EndInit()
    $bitmap.Freeze()
    $Control.Source = $bitmap
    return $bitmap
}

function Set-GridHeaders {
    param($Grid,[string[]]$Keys)
    for ($index=0; $index -lt $Keys.Count -and $index -lt $Grid.Columns.Count; $index++) {
        $Grid.Columns[$index].Header = Get-Text $Keys[$index]
    }
}

function Apply-Language {
    $window.Title = "TrackerRadar $script:Version | SC LABS"
    $footerVersionText.Text = "TrackerRadar $script:Version | SC LABS"
    $taglineText.Text = Get-Text 'Tagline'
    $navOverview.Content = Get-Text 'NavOverview'
    $navActivities.Content = Get-Text 'NavActivities'
    $navFindings.Content = Get-Text 'NavFindings'
    $navHistory.Content = Get-Text 'NavHistory'
    $navAccess.Content = Get-Text 'NavAccess'
    $navChanges.Content = Get-Text 'NavChanges'
    $privacyTitleText.Text = Get-Text 'PrivacyTitle'
    $privacyBodyText.Text = Get-Text 'PrivacyBody'
    $moreProductsTitleText.Text = Get-Text 'MoreProductsTitle'
    $scanButton.Content = Get-Text 'ScanNow'
    $overviewAppsLabel.Text = Get-Text 'OverviewApps'
    $overviewNewLabel.Text = Get-Text 'OverviewNew'
    $overviewFindingsLabel.Text = Get-Text 'OverviewFindings'
    $currentActivitiesTitle.Text = Get-Text 'CurrentActivities'
    $currentActivitiesHint.Text = Get-Text 'CurrentActivitiesHint'
    $importantFindingsTitle.Text = Get-Text 'ImportantFindings'
    $importantFindingsHint.Text = Get-Text 'ImportantFindingsHint'
    $reportButton.Content = Get-Text 'OpenLocalReport'
    $activitiesPanelTitle.Text = Get-Text 'ActivitiesPanelTitle'
    $activitiesPanelHint.Text = Get-Text 'ActivitiesPanelHint'
    $blockInternetButton.Content = Get-Text 'BlockInternet'
    $findingsPanelTitle.Text = Get-Text 'FindingsPanelTitle'
    $findingsPanelHint.Text = Get-Text 'FindingsPanelHint'
    $disableStartupButton.Content = Get-Text 'DisableStartup'
    $historyPanelTitle.Text = Get-Text 'HistoryPanelTitle'
    $historyPanelHint.Text = Get-Text 'HistoryPanelHint'
    $accessPanelTitle.Text = Get-Text 'AccessPanelTitle'
    $accessPanelHint.Text = Get-Text 'AccessPanelHint'
    $accessScanButton.Content = Get-Text 'AccessStart'
    $changesPanelTitle.Text = Get-Text 'ChangesPanelTitle'
    $changesPanelHint.Text = Get-Text 'ChangesPanelHint'
    $undoChangeButton.Content = Get-Text 'UndoChange'
    Set-GridHeaders $overviewActivityGrid @('HeaderApp','HeaderTarget','HeaderStatus')
    Set-GridHeaders $activityGrid @('HeaderApp','HeaderTarget','HeaderProvider','HeaderIP','HeaderPort','HeaderStatus','HeaderFirstSeen')
    Set-GridHeaders $findingsGrid @('HeaderLevel','HeaderApp','HeaderReason','HeaderPoints')
    Set-GridHeaders $historyGrid @('HeaderTime','HeaderApps','HeaderConnections','HeaderNew','HeaderFindings','HeaderSummary')
    Set-GridHeaders $accessGrid @('HeaderApp','HeaderPID','HeaderFolder','HeaderOperation','HeaderAccesses','HeaderProgramPath')
    Set-GridHeaders $changeGrid @('HeaderTime','HeaderAction','HeaderTarget','HeaderStatus')
    if ($null -eq $script:LastSnapshot) { $statusText.Text = Get-Text 'Ready' }
    Update-BlockInternetButton
}

function Refresh-LocalizedRows {
    if ($script:LastSnapshot) {
        $activities = @(Convert-ActivityRows @($script:LastSnapshot.Activities))
        $findings = @(Convert-FindingRows @($script:LastSnapshot.Findings))
        $history = @(Convert-HistoryRows @($script:LastSnapshot.History))
        $overviewActivityGrid.ItemsSource = @($activities | Select-Object -First 15)
        $overviewFindingsList.ItemsSource = @($findings | Select-Object -First 8)
        $activityGrid.ItemsSource = $activities
        $findingsGrid.ItemsSource = $findings
        $historyGrid.ItemsSource = $history
        $criticalHint.Text = Format-Text 'CriticalFormat' @($script:LastSnapshot.CriticalCount)
        if (-not $script:LastSnapshot.BaselineExists) {
            $statusText.Text = Format-Text 'StatusBaseline' @($script:LastSnapshot.ExternalConnections,$script:LastSnapshot.DurationMs)
        } else {
            $statusText.Text = Format-Text 'StatusLastCheck' @((Get-Date -Format 'HH:mm:ss'),$script:LastSnapshot.ExternalConnections,$script:LastSnapshot.NewCount,$script:LastSnapshot.DurationMs)
        }
    }
    $changeGrid.ItemsSource = @(Get-ChangeVaultRows)
    Update-AccessView
    Update-BlockInternetButton
}

function Set-Language {
    param([ValidateSet('de','en')][string]$Language,[bool]$Save=$true)
    Set-TrackerRadarLanguage -Language $Language -Save $Save
    Apply-Language
    Refresh-LocalizedRows
    Set-View $script:CurrentView
}
function Get-AccessScanResult {
    return (Read-JsonFile (Join-Path $script:AccessScanData 'latest-access-scan.json'))
}

function Update-AccessView {
    $result = Get-AccessScanResult
    if (-not $result) {
        $accessGrid.ItemsSource = @()
        $accessSummary.Text = Get-Text 'AccessNone'
        return
    }
    $accessGrid.ItemsSource = @(Convert-AccessRows @($result.Groups))
    $time = [string]$result.Timestamp
    try { $time = ([datetime]$result.Timestamp).ToString('dd.MM.yyyy HH:mm:ss') } catch { }
    $folders = @($result.MonitoredFolders | ForEach-Object { Convert-DisplayText ([string]$_) }) -join ', '
    $accessSummary.Text = Format-Text 'AccessSummary' @($time,$result.DurationSeconds,$result.GroupCount,$folders)
}

function Start-AccessScan {
    $wrapper = Join-Path $script:Root 'TrackerRadar.AccessScan.Elevated.ps1'
    if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) { throw 'TrackerRadar.AccessScan.Elevated.ps1 fehlt.' }
    $resultPath = Join-Path $script:AccessScanData 'latest-access-scan.json'
    $previousWrite = [datetime]::MinValue
    if (Test-Path -LiteralPath $resultPath) { $previousWrite = (Get-Item -LiteralPath $resultPath).LastWriteTimeUtc }

    $accessScanButton.IsEnabled = $false
    $accessScanButton.Content = Get-Text 'AccessRunning'
    $statusText.Text = Get-Text 'AccessPreparing'
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    $window.Dispatcher.Invoke([action]{}, 'Background')
    try {
        $argumentString = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $wrapper + '"'
        try {
            $process = Start-Process powershell.exe -Verb RunAs -ArgumentList $argumentString -Wait -PassThru
        } catch {
            $nativeCode = 0
            try { $nativeCode = [int]$_.Exception.NativeErrorCode } catch { }
            if ($nativeCode -eq 1223 -or $_.Exception.Message -match 'canceled|cancelled|abgebrochen') {
                throw 'Windows-Abfrage wurde abgebrochen. Der bisherige Scan bleibt erhalten.'
            }
            throw
        }
        if ($process.ExitCode -ne 0) { throw "Dateizugriffs-Scan fehlgeschlagen (Exit $($process.ExitCode))." }
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'Der Scan lieferte kein Ergebnis.' }
        $newWrite = (Get-Item -LiteralPath $resultPath).LastWriteTimeUtc
        if ($newWrite -le $previousWrite) { throw 'Der Scan wurde nicht aktualisiert.' }
        Update-AccessView
        $result = Get-AccessScanResult
        $statusText.Text = Format-Text 'AccessDone' @($result.GroupCount)
    } finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
        $accessScanButton.Content = Get-Text 'AccessStart'
        $accessScanButton.IsEnabled = $true
    }
}

function Get-ChangeVaultRows {
    $rows = @()
    $folder = Join-Path $script:Data 'changes'
    if (-not (Test-Path -LiteralPath $folder)) { return @() }
    foreach ($file in Get-ChildItem -LiteralPath $folder -Filter '*.json' -File -ErrorAction SilentlyContinue) {
        try {
            $record = Read-JsonFile $file.FullName
            if (-not $record) { continue }
            $time = [string]$record.Timestamp
            try { $time = ([datetime]$record.Timestamp).ToString('dd.MM.yyyy HH:mm') } catch { }
            $status = switch ([string]$record.Status) {
                'Applied' { Get-Text 'ChangeStatusApplied' }
                'Undone' { Get-Text 'ChangeStatusUndone' }
                'Pending' { Get-Text 'ChangeStatusPending' }
                'Failed' { Get-Text 'ChangeStatusFailed' }
                default { Convert-DisplayText ([string]$record.Status) }
            }
            $requiresAdmin = $false
            if ($record.PSObject.Properties.Name -contains 'RequiresAdmin') { $requiresAdmin = [bool]$record.RequiresAdmin }
            $rows += [pscustomobject]@{
                Id = [string]$record.Id
                Timestamp = [string]$record.Timestamp
                Time = $time
                DisplayAction = Convert-DisplayText ([string]$record.DisplayAction)
                TargetName = [string]$record.TargetName
                Target = [string]$record.Target
                Status = [string]$record.Status
                StatusDisplay = $status
                RequiresAdmin = $requiresAdmin
            }
        } catch { }
    }
    return @($rows | Sort-Object Timestamp -Descending)
}

function Invoke-ControlRequest {
    param($Request,[bool]$RequireAdmin)
    $controlScript = Join-Path $script:Root 'TrackerRadar.Control.ps1'
    if (-not (Test-Path -LiteralPath $controlScript)) { throw 'TrackerRadar.Control.ps1 fehlt.' }
    $requestFolder = Join-Path $script:Data 'control-requests'
    if (-not (Test-Path -LiteralPath $requestFolder)) { New-Item -ItemType Directory -Path $requestFolder -Force | Out-Null }
    $requestId = 'req-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,8))
    $requestPath = Join-Path $requestFolder ($requestId + '.json')
    $responsePath = [IO.Path]::ChangeExtension($requestPath,'.response.json')
    $pointerPath = ''
    Write-JsonFile -Path $requestPath -Value $Request -Depth 8
    $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$controlScript,'-RequestFile',$requestPath)
    try {
        if ($RequireAdmin) {
            $elevatedScript = Join-Path $script:Root 'TrackerRadar.Elevated.ps1'
            if (-not (Test-Path -LiteralPath $elevatedScript -PathType Leaf)) { throw 'TrackerRadar.Elevated.ps1 fehlt.' }
            $pointerPath = Join-Path $requestFolder 'elevated-request.txt'
            [IO.File]::WriteAllText($pointerPath,$requestPath,(New-Object Text.UTF8Encoding($false)))
            $elevatedArguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$elevatedScript)
            $argumentString = ($elevatedArguments | ForEach-Object {
                $value = [string]$_
                if ($value -match '[\s"]') { '"' + $value.Replace('"','\"') + '"' } else { $value }
            }) -join ' '
            try {
                $process = Start-Process powershell.exe -Verb RunAs -ArgumentList $argumentString -Wait -PassThru
            } catch {
                $nativeCode = 0
                try { $nativeCode = [int]$_.Exception.NativeErrorCode } catch { }
                if ($nativeCode -eq 1223 -or $_.Exception.Message -match 'canceled|cancelled|abgebrochen') {
                    throw 'Windows-Abfrage wurde abgebrochen. Es wurde nichts geaendert.'
                }
                throw
            }
        } else {
            $process = Start-Process powershell.exe -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        }
        if (-not (Test-Path -LiteralPath $responsePath)) {
            if ($RequireAdmin -and $process.ExitCode -eq -196608) {
                throw 'Windows-Abfrage wurde abgebrochen oder nicht bestaetigt. Es wurde nichts geaendert.'
            }
            throw "Control-Helper lieferte keine Antwort (Exit $($process.ExitCode))."
        }
        $response = Read-JsonFile $responsePath
        if (-not $response) { throw 'Control-Antwort konnte nicht gelesen werden.' }
        return $response
    } finally {
        Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $responsePath -Force -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($pointerPath)) {
            Remove-Item -LiteralPath $pointerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-BlockInternetButton {
    $item = $activityGrid.SelectedItem
    $script:SelectedBlockState = $null
    if (-not $item) {
        $blockInternetButton.Content = Get-Text 'BlockInternet'
        $blockInternetButton.Tag = 'Block'
        $blockInternetButton.IsEnabled = $false
        $blockInternetButton.ToolTip = Get-Text 'SelectApp'
        return
    }

    $programPath = [string]$item.Path
    if ([string]::IsNullOrWhiteSpace($programPath) -or -not (Test-Path -LiteralPath $programPath -PathType Leaf)) {
        $blockInternetButton.Content = Get-Text 'BlockInternet'
        $blockInternetButton.Tag = 'Block'
        $blockInternetButton.IsEnabled = $false
        $blockInternetButton.ToolTip = Get-Text 'InvalidProgramPath'
        return
    }

    $blockInternetButton.Content = Get-Text 'BlockStateChecking'
    $blockInternetButton.IsEnabled = $false
    $window.Dispatcher.Invoke([action]{}, 'Background')
    try {
        $state = Invoke-ControlRequest -Request ([pscustomobject]@{ Action='GetBlockState'; ProgramPath=$programPath }) -RequireAdmin $false
        if (-not $state -or -not [bool]$state.Ok -or -not [bool]$state.ValidPath) {
            throw (Get-Text 'BlockStateUnknown')
        }
        $script:SelectedBlockState = $state
        if ([bool]$state.Blocked) {
            $blockInternetButton.Content = Get-Text 'UnblockInternet'
            $blockInternetButton.Tag = 'Unblock'
            $blockInternetButton.IsEnabled = [bool]$state.CanUndo
            $blockInternetButton.ToolTip = if ([bool]$state.CanUndo) { Get-Text 'UnblockTitle' } else { Get-Text 'BlockedWithoutUndo' }
        } else {
            $blockInternetButton.Content = Get-Text 'BlockInternet'
            $blockInternetButton.Tag = 'Block'
            $blockInternetButton.IsEnabled = $true
            $blockInternetButton.ToolTip = Get-Text 'BlockTitle'
        }
    } catch {
        $blockInternetButton.Content = Get-Text 'BlockInternet'
        $blockInternetButton.Tag = 'Unknown'
        $blockInternetButton.IsEnabled = $false
        $blockInternetButton.ToolTip = (Get-Text 'BlockStateUnknown') + ' ' + ([string]$_.Exception.Message)
    }
}

$scLabsBitmap = Set-UiImage -Control $scLabsLogo -Path (Join-Path $script:Root 'assets\branding\sclabs-mark.png')
$trackerRadarBitmap = Set-UiImage -Control $trackerRadarLogo -Path (Join-Path $script:Root 'assets\branding\trackerradar-logo.png')
if ($trackerRadarBitmap) { $window.Icon = $trackerRadarBitmap }

function Set-View {
    param([string]$Name)
    $script:CurrentView = $Name
    foreach ($view in @($overviewView,$activitiesView,$findingsView,$historyView,$accessView,$changesView)) { $view.Visibility = 'Collapsed' }
    foreach ($button in @($navOverview,$navActivities,$navFindings,$navHistory,$navAccess,$navChanges)) {
        $button.Background = [System.Windows.Media.Brushes]::Transparent
        $button.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(170,186,196))
        $button.FontWeight = 'Normal'
    }

    switch ($Name) {
        'Activities' { $activitiesView.Visibility='Visible'; $navActivities.Background='#102630'; $navActivities.Foreground='#25D7C0'; $navActivities.FontWeight='SemiBold'; $viewTitle.Text=Get-Text 'ViewActivitiesTitle'; $viewSubtitle.Text=Get-Text 'ViewActivitiesSubtitle' }
        'Findings' { $findingsView.Visibility='Visible'; $navFindings.Background='#102630'; $navFindings.Foreground='#25D7C0'; $navFindings.FontWeight='SemiBold'; $viewTitle.Text=Get-Text 'ViewFindingsTitle'; $viewSubtitle.Text=Get-Text 'ViewFindingsSubtitle' }
        'History' { $historyView.Visibility='Visible'; $navHistory.Background='#102630'; $navHistory.Foreground='#25D7C0'; $navHistory.FontWeight='SemiBold'; $viewTitle.Text=Get-Text 'ViewHistoryTitle'; $viewSubtitle.Text=Get-Text 'ViewHistorySubtitle' }
        'Access' { $accessView.Visibility='Visible'; $navAccess.Background='#102630'; $navAccess.Foreground='#25D7C0'; $navAccess.FontWeight='SemiBold'; $viewTitle.Text=Get-Text 'ViewAccessTitle'; $viewSubtitle.Text=Get-Text 'ViewAccessSubtitle'; Update-AccessView }
        'Changes' { $changesView.Visibility='Visible'; $navChanges.Background='#102630'; $navChanges.Foreground='#25D7C0'; $navChanges.FontWeight='SemiBold'; $viewTitle.Text=Get-Text 'ViewChangesTitle'; $viewSubtitle.Text=Get-Text 'ViewChangesSubtitle' }
        default { $script:CurrentView='Overview'; $overviewView.Visibility='Visible'; $navOverview.Background='#102630'; $navOverview.Foreground='#25D7C0'; $navOverview.FontWeight='SemiBold'; $viewTitle.Text=Get-Text 'ViewOverviewTitle'; $viewSubtitle.Text=Get-Text 'ViewOverviewSubtitle' }
    }
}

function Update-Ui {
    try {
        $scanButton.IsEnabled = $false
        $scanButton.Content = Get-Text 'Scanning'
        $statusText.Text = Get-Text 'StatusLocalScan'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        $window.Dispatcher.Invoke([action]{}, 'Background')

        $snapshot = Get-Snapshot
        $script:LastSnapshot = $snapshot
        $appsCount.Text = [string]$snapshot.ActiveApps
        $newCount.Text = [string]$snapshot.NewCount
        $findingsCount.Text = [string]$snapshot.FindingCount
        Refresh-LocalizedRows
        $snapshot = $null
    } catch {
        $message = Convert-DisplayText ([string]$_.Exception.Message)
        $statusText.Text = Format-Text 'StatusScanFailed' @($message)
        [System.Windows.MessageBox]::Show($message, 'TrackerRadar', 'OK', 'Error') | Out-Null
    } finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
        $scanButton.Content = Get-Text 'ScanNow'
        $scanButton.IsEnabled = $true
        [GC]::Collect(0, [GCCollectionMode]::Optimized)
    }
}

$languageSelector.Add_SelectionChanged({
    if ($script:LanguageChanging) { return }
    $selected = $languageSelector.SelectedItem
    if ($selected -and [string]$selected.Tag -in @('de','en')) { Set-Language -Language ([string]$selected.Tag) -Save $true }
})
function Open-ScLabsPage {
    param([Parameter(Mandatory)][string]$Url)
    $allowedUrls = @(
        'https://sclabs.uk/',
        'https://sclabs.uk/products/malwareradar/',
        'https://sclabs.uk/products/privacyradar/'
    )
    if ($Url -notin $allowedUrls) { return }
    try {
        Start-Process -FilePath $Url
    } catch {
        [System.Windows.MessageBox]::Show((Format-Text 'ExternalLinkError' @($Url)), (Get-Text 'ExternalLinkErrorTitle'), 'OK', 'Error') | Out-Null
    }
}
$scLabsWebsiteLinkText.Add_MouseLeftButtonUp({ Open-ScLabsPage -Url ([string]$scLabsWebsiteLinkText.Tag) })
$footerMalwareRadarLinkText.Add_MouseLeftButtonUp({ Open-ScLabsPage -Url ([string]$footerMalwareRadarLinkText.Tag) })
$footerPrivacyRadarLinkText.Add_MouseLeftButtonUp({ Open-ScLabsPage -Url ([string]$footerPrivacyRadarLinkText.Tag) })
$navOverview.Add_Click({ Set-View 'Overview' })
$navActivities.Add_Click({ Set-View 'Activities' })
$navFindings.Add_Click({ Set-View 'Findings' })
$navHistory.Add_Click({ Set-View 'History' })
$navAccess.Add_Click({ Set-View 'Access' })
$navChanges.Add_Click({ Set-View 'Changes' })
$scanButton.Add_Click({ Update-Ui })
$accessScanButton.Add_Click({
    try { Start-AccessScan } catch { [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$_.Exception.Message)), (Get-Text 'AccessDialogTitle'), 'OK', 'Error') | Out-Null }
})
$reportButton.Add_Click({ $report = Join-Path $script:Data 'latest-scan.json'; if (Test-Path -LiteralPath $report) { Start-Process explorer.exe -ArgumentList @('/select,', $report) } })
$activityGrid.Add_SelectionChanged({ Update-BlockInternetButton })

$blockInternetButton.Add_Click({
    $item = $activityGrid.SelectedItem
    if (-not $item) { [System.Windows.MessageBox]::Show((Get-Text 'SelectApp'), 'TrackerRadar', 'OK', 'Information') | Out-Null; return }
    $programPath = [string]$item.Path
    if ([string]::IsNullOrWhiteSpace($programPath) -or -not (Test-Path -LiteralPath $programPath -PathType Leaf)) { [System.Windows.MessageBox]::Show((Get-Text 'InvalidProgramPath'), 'TrackerRadar', 'OK', 'Warning') | Out-Null; return }

    try {
        $state = Invoke-ControlRequest -Request ([pscustomobject]@{ Action='GetBlockState'; ProgramPath=$programPath }) -RequireAdmin $false
        if (-not $state -or -not [bool]$state.Ok -or -not [bool]$state.ValidPath) { throw (Get-Text 'BlockStateUnknown') }

        if ([bool]$state.Blocked) {
            if (-not [bool]$state.CanUndo -or [string]::IsNullOrWhiteSpace([string]$state.ChangeId)) {
                [System.Windows.MessageBox]::Show((Get-Text 'BlockedWithoutUndo'), (Get-Text 'UnblockTitle'), 'OK', 'Warning') | Out-Null
                Update-BlockInternetButton
                return
            }
            $message = Format-Text 'UnblockPrompt' @($item.App,$programPath)
            if ([System.Windows.MessageBox]::Show($message, (Get-Text 'UnblockTitle'), 'YesNo', 'Question') -ne 'Yes') { return }
            $response = Invoke-ControlRequest -Request ([pscustomobject]@{ Action='UndoChange'; ChangeId=[string]$state.ChangeId }) -RequireAdmin $true
            if (-not [bool]$response.Ok) { throw [string]$response.Error }
            [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$response.Message)), 'TrackerRadar', 'OK', 'Information') | Out-Null
            Update-Ui
            Set-View 'Changes'
            return
        }

        $message = Format-Text 'BlockPrompt' @($item.App,$programPath)
        if ([System.Windows.MessageBox]::Show($message, (Get-Text 'BlockTitle'), 'YesNo', 'Warning') -ne 'Yes') { return }
        $response = Invoke-ControlRequest -Request ([pscustomobject]@{ Action='BlockInternet'; ProgramPath=$programPath }) -RequireAdmin $true
        if (-not [bool]$response.Ok) { throw [string]$response.Error }
        [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$response.Message)), 'TrackerRadar', 'OK', 'Information') | Out-Null
        Update-Ui
        Set-View 'Changes'
    } catch {
        $errorMessage = Convert-DisplayText ([string]$_.Exception.Message)
        $blockedAfterError = $false
        try {
            $check = Invoke-ControlRequest -Request ([pscustomobject]@{ Action='GetBlockState'; ProgramPath=$programPath }) -RequireAdmin $false
            $blockedAfterError = ($check -and [bool]$check.Blocked)
        } catch { }
        $message = if ($blockedAfterError) { (Get-Text 'BlockStateUnknown') + "`n`n" + $errorMessage } else { Format-Text 'BlockFailedNoChange' @($errorMessage) }
        [System.Windows.MessageBox]::Show($message, (Get-Text 'ChangeNotExecuted'), 'OK', 'Error') | Out-Null
        Update-BlockInternetButton
    }
})

$disableStartupButton.Add_Click({
    $item = $findingsGrid.SelectedItem
    if (-not $item) { [System.Windows.MessageBox]::Show((Get-Text 'SelectStartup'), 'TrackerRadar', 'OK', 'Information') | Out-Null; return }
    if (-not ($item.PSObject.Properties.Name -contains 'ActionType') -or [string]$item.ActionType -ne 'DisableStartup') { [System.Windows.MessageBox]::Show((Get-Text 'StartupNotDisableable'), 'TrackerRadar', 'OK', 'Information') | Out-Null; return }
    $location = [string]$item.StartupLocation
    $requiresAdmin = $location.StartsWith('HKLM:',[StringComparison]::OrdinalIgnoreCase) -or $location.StartsWith($env:ProgramData,[StringComparison]::OrdinalIgnoreCase)
    $message = Format-Text 'DisableStartupPrompt' @($item.StartupName,$location,$item.StartupCommand)
    if ([System.Windows.MessageBox]::Show($message, (Get-Text 'DisableStartupTitle'), 'YesNo', 'Warning') -ne 'Yes') { return }
    try {
        $request = [pscustomobject]@{ Action='DisableStartup'; Name=[string]$item.StartupName; Location=$location; Command=[string]$item.StartupCommand }
        $response = Invoke-ControlRequest -Request $request -RequireAdmin $requiresAdmin
        if (-not [bool]$response.Ok) { throw [string]$response.Error }
        [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$response.Message)), 'TrackerRadar', 'OK', 'Information') | Out-Null
        Update-Ui
        Set-View 'Changes'
    } catch { [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$_.Exception.Message)), (Get-Text 'ChangeNotExecuted'), 'OK', 'Error') | Out-Null }
})

$undoChangeButton.Add_Click({
    $item = $changeGrid.SelectedItem
    if (-not $item) { [System.Windows.MessageBox]::Show((Get-Text 'SelectChange'), 'TrackerRadar', 'OK', 'Information') | Out-Null; return }
    if ([string]$item.Status -eq 'Undone') { [System.Windows.MessageBox]::Show((Get-Text 'AlreadyUndone'), 'TrackerRadar', 'OK', 'Information') | Out-Null; return }
    $message = Format-Text 'UndoPrompt' @($item.DisplayAction,$item.TargetName)
    if ([System.Windows.MessageBox]::Show($message, (Get-Text 'UndoTitle'), 'YesNo', 'Question') -ne 'Yes') { return }
    try {
        $response = Invoke-ControlRequest -Request ([pscustomobject]@{ Action='UndoChange'; ChangeId=[string]$item.Id }) -RequireAdmin ([bool]$item.RequiresAdmin)
        if (-not [bool]$response.Ok) { throw [string]$response.Error }
        [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$response.Message)), 'TrackerRadar', 'OK', 'Information') | Out-Null
        Update-Ui
        Set-View 'Changes'
    } catch { [System.Windows.MessageBox]::Show((Convert-DisplayText ([string]$_.Exception.Message)), (Get-Text 'UndoFailed'), 'OK', 'Error') | Out-Null }
})

$changeGrid.Add_MouseDoubleClick({
    $item = $changeGrid.SelectedItem
    if ($item) { [System.Windows.MessageBox]::Show((Format-Text 'ChangeVaultDetails' @($item.Id,$item.DisplayAction,$item.Target,$item.StatusDisplay)), 'Change Vault', 'OK', 'Information') | Out-Null }
})
$showActivity = {
    param($grid)
    $item = $grid.SelectedItem
    if ($item) {
        $text = Format-Text 'ActivityDetails' @($item.App,$item.Target,$item.Provider,$item.Purpose,$item.Address,$item.Port,$item.Pid,$item.Change,$item.FirstSeenDisplay,$item.Path,$item.Reason)
        [System.Windows.MessageBox]::Show($text, (Get-Text 'ActivityDetailsTitle'), 'OK', 'Information') | Out-Null
    }
}
$overviewActivityGrid.Add_MouseDoubleClick({ & $showActivity $overviewActivityGrid })
$activityGrid.Add_MouseDoubleClick({ & $showActivity $activityGrid })
$findingsGrid.Add_MouseDoubleClick({ $item=$findingsGrid.SelectedItem; if ($item) { [System.Windows.MessageBox]::Show("$($item.Summary)`n`n$($item.Detail)", (Get-Text 'FindingDetailsTitle'), 'OK', 'Warning') | Out-Null } })
$overviewFindingsList.Add_MouseDoubleClick({ $item=$overviewFindingsList.SelectedItem; if ($item) { [System.Windows.MessageBox]::Show("$($item.Summary)`n`n$($item.Detail)", (Get-Text 'FindingDetailsTitle'), 'OK', 'Warning') | Out-Null } })
$historyGrid.Add_MouseDoubleClick({ $item=$historyGrid.SelectedItem; if ($item) { $changes=if ([string]::IsNullOrWhiteSpace([string]$item.Changes)) {Get-Text 'NoIndividualChanges'} else {$item.Changes}; [System.Windows.MessageBox]::Show("$($item.Time)`n$($item.Summary)`n`n$changes", (Get-Text 'HistoryDetailsTitle'), 'OK', 'Information') | Out-Null } })
$accessGrid.Add_MouseDoubleClick({ $item=$accessGrid.SelectedItem; if ($item) { [System.Windows.MessageBox]::Show((Format-Text 'AccessDetails' @($item.ProcessName,$item.ProcessId,$item.Folder,$item.Operation,$item.AccessCount,$item.ExecutablePath)), (Get-Text 'AccessDetailsTitle'), 'OK', 'Information') | Out-Null } })

$script:LanguageChanging = $true
$languageSelector.SelectedIndex = if ($script:Language -eq 'en') { 1 } else { 0 }
$script:LanguageChanging = $false
Apply-Language
if ($UiSmokeTest) {
    try {
        $results = @()
        foreach ($name in @('Overview','Activities','Findings','History','Access','Changes')) {
            Set-View $name
            $visibleCount = @($overviewView,$activitiesView,$findingsView,$historyView,$accessView,$changesView | Where-Object { $_.Visibility -eq 'Visible' }).Count
            $results += [pscustomobject]@{ Type='View'; Name=$name; Passed=($visibleCount -eq 1); Detail="$visibleCount visible" }
        }
        $results += [pscustomobject]@{ Type='UiStyle'; Name='language-template'; Passed=($null -ne $languageSelector.Template); Detail=if ($null -ne $languageSelector.Template) { 'custom template loaded' } else { 'missing template' } }
        $results += [pscustomobject]@{ Type='UiStyle'; Name='language-height'; Passed=([double]$languageSelector.Height -eq 52); Detail=[string]$languageSelector.Height }
        $results += [pscustomobject]@{ Type='UiStyle'; Name='scan-height'; Passed=([double]$scanButton.Height -eq 52); Detail=[string]$scanButton.Height }
        $results += [pscustomobject]@{ Type='UiStyle'; Name='sclabs-logo-scale'; Passed=([double]$scLabsLogo.RenderTransform.ScaleX -eq 1.12); Detail=[string]$scLabsLogo.RenderTransform.ScaleX }
        $results += [pscustomobject]@{ Type='UiStyle'; Name='trackerradar-logo-scale'; Passed=([double]$trackerRadarLogo.RenderTransform.ScaleX -eq 1.20); Detail=[string]$trackerRadarLogo.RenderTransform.ScaleX }
        $results += [pscustomobject]@{ Type='ExternalLink'; Name='sclabs-url'; Passed=([string]$scLabsWebsiteLinkText.Tag -eq 'https://sclabs.uk/'); Detail=[string]$scLabsWebsiteLinkText.Tag }
        $results += [pscustomobject]@{ Type='ExternalLink'; Name='malwareradar-url'; Passed=([string]$footerMalwareRadarLinkText.Tag -eq 'https://sclabs.uk/products/malwareradar/'); Detail=[string]$footerMalwareRadarLinkText.Tag }
        $results += [pscustomobject]@{ Type='ExternalLink'; Name='privacyradar-url'; Passed=([string]$footerPrivacyRadarLinkText.Tag -eq 'https://sclabs.uk/products/privacyradar/'); Detail=[string]$footerPrivacyRadarLinkText.Tag }
        $results += [pscustomobject]@{ Type='Footer'; Name='version-inset'; Passed=([double]$footerVersionText.Margin.Right -eq 0 -and [double]$footerVersionText.FontSize -eq 12); Detail=[string]$footerVersionText.Text }
        $results += [pscustomobject]@{ Type='SafeControl'; Name='block-default-disabled'; Passed=(-not [bool]$blockInternetButton.IsEnabled); Detail=[string]$blockInternetButton.IsEnabled }
        $results += [pscustomobject]@{ Type='SafeControl'; Name='block-default-mode'; Passed=([string]$blockInternetButton.Tag -eq 'Block'); Detail=[string]$blockInternetButton.Tag }
        $results += [pscustomobject]@{ Type='SafeControl'; Name='block-default-no-state'; Passed=($null -eq $script:SelectedBlockState); Detail=if($null -eq $script:SelectedBlockState){'none'}else{'unexpected state'} }
        $originalLanguage = $script:Language
        foreach ($language in @('de','en')) {
            Set-Language -Language $language -Save $false
            $expectedOverview = if ($language -eq 'en') { 'Overview' } else { [string](Get-Text 'NavOverview') }
            $expectedProvider = if ($language -eq 'en') { 'PROVIDER' } else { [string](Get-Text 'HeaderProvider') }
            $expectedUnknown = if ($language -eq 'en') { 'Unknown service' } else { [string](Get-Text 'UnknownService') }
            $expectedAccess = if ($language -eq 'en') { 'Start 5-second scan' } else { [string](Get-Text 'AccessStart') }
            $expectedMoreProducts = [string](Get-Text 'MoreProductsTitle')
            $expectedBlock = [string](Get-Text 'BlockInternet')
            $expectedUnblock = [string](Get-Text 'UnblockInternet')
            $results += [pscustomobject]@{ Type='Language'; Name="$language-navigation"; Passed=([string]$navOverview.Content -eq $expectedOverview); Detail=[string]$navOverview.Content }
            $results += [pscustomobject]@{ Type='Language'; Name="$language-provider-header"; Passed=([string]$activityGrid.Columns[2].Header -eq $expectedProvider); Detail=[string]$activityGrid.Columns[2].Header }
            $results += [pscustomobject]@{ Type='Language'; Name="$language-unknown-provider"; Passed=((Convert-DisplayText 'Unbekannter Dienst') -eq $expectedUnknown); Detail=(Convert-DisplayText 'Unbekannter Dienst') }
            $results += [pscustomobject]@{ Type='Language'; Name="$language-access-button"; Passed=([string]$accessScanButton.Content -eq $expectedAccess); Detail=[string]$accessScanButton.Content }
            $results += [pscustomobject]@{ Type='Language'; Name="$language-related-title"; Passed=([string]$moreProductsTitleText.Text -eq $expectedMoreProducts); Detail=[string]$moreProductsTitleText.Text }
            $results += [pscustomobject]@{ Type='SafeControl'; Name="$language-block-label"; Passed=([string]$blockInternetButton.Content -eq $expectedBlock); Detail=[string]$blockInternetButton.Content }
            $results += [pscustomobject]@{ Type='SafeControl'; Name="$language-unblock-label"; Passed=(-not [string]::IsNullOrWhiteSpace($expectedUnblock)); Detail=$expectedUnblock }
            $results += [pscustomobject]@{ Type='Language'; Name="$language-sclabs-link"; Passed=([string]$scLabsWebsiteLinkText.Text -eq 'sclabs.uk'); Detail=[string]$scLabsWebsiteLinkText.Text }
            $results += [pscustomobject]@{ Type='Footer'; Name="$language-malwareradar-link"; Passed=([string]$footerMalwareRadarLinkText.Text -eq 'MalwareRadar'); Detail=[string]$footerMalwareRadarLinkText.Text }
            $results += [pscustomobject]@{ Type='Footer'; Name="$language-privacyradar-link"; Passed=([string]$footerPrivacyRadarLinkText.Text -eq 'PrivacyRadar'); Detail=[string]$footerPrivacyRadarLinkText.Text }
        }
        Set-Language -Language $originalLanguage -Save $false
        $passed = @($results | Where-Object { $_.Passed }).Count
        [pscustomobject]@{ Product='TrackerRadar Alpha'; Version=$script:Version; Passed=$passed; Failed=($results.Count-$passed); Checks=$results } | ConvertTo-Json -Depth 6
        if ($passed -ne $results.Count) { exit 1 }
        exit 0
    } catch {
        [pscustomobject]@{ Product='TrackerRadar Alpha'; Version=$script:Version; Passed=0; Failed=1; Error=$_.Exception.Message } | ConvertTo-Json -Depth 4
        exit 1
    }
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(30)
$timer.Add_Tick({ Update-Ui })
$window.Add_ContentRendered({ Set-View 'Overview'; Update-Ui; $timer.Start() })
$window.Add_Closed({ $timer.Stop() })
[void]$window.ShowDialog()
