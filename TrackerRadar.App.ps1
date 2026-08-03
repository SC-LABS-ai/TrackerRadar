param(
    [switch]$SelfTest,
    [switch]$ExportOnly,
    [switch]$UiSmokeTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Version = '0.3.0-alpha'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Data = Join-Path $script:Root 'data'
$script:State = Join-Path $script:Data 'state'
$script:History = Join-Path $script:Data 'history'
foreach ($folder in @($script:Data, $script:State, $script:History)) {
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
            }
        } elseif ($BaselineExists -and $entry.Change -eq 'Neu') {
            $result += [pscustomobject]@{
                App = $entry.Name
                Score = 2
                Level = 'Neu'
                Summary = "$($entry.Name): neuer Autostart wurde entdeckt."
                Detail = "$($entry.Location)`n$($entry.Command)"
            }
        } elseif ($BaselineExists -and $entry.Change -eq 'Geaendert') {
            $result += [pscustomobject]@{
                App = $entry.Name
                Score = 3
                Level = 'Geaendert'
                Summary = "$($entry.Name): bestehender Autostart wurde veraendert."
                Detail = "$($entry.Location)`n$($entry.Command)"
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
            'Datei-Lesezugriffe werden in dieser Alpha noch nicht vollstaendig erfasst'
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
        Title="TrackerRadar 0.3 Alpha | SC LABS" Width="1180" Height="720" MinWidth="960" MinHeight="620"
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
                        <Border Width="44" Height="44" CornerRadius="9" Background="#0B1924" BorderBrush="#284657" BorderThickness="1" Padding="3"><Image x:Name="ScLabsLogo" Stretch="Uniform"/></Border>
                        <StackPanel Margin="10,6,0,0"><TextBlock Text="SC LABS" FontSize="16" FontWeight="Bold"/><TextBlock Text="PRODUCT SERIES" FontSize="9" Foreground="#718B99"/></StackPanel>
                    </StackPanel>
                    <Border Margin="0,22,0,0" Height="132" CornerRadius="12" Background="#06101A" BorderBrush="#234455" BorderThickness="1" ClipToBounds="True"><Image x:Name="TrackerRadarLogo" Stretch="Uniform"/></Border>
                    <TextBlock Text="Sieh, was Programme wirklich tun." Margin="0,10,0,0" Foreground="#8EA2AF" TextWrapping="Wrap"/>
                </StackPanel>
                <StackPanel Grid.Row="1" Margin="0,30,0,0">
                    <Button x:Name="NavOverview" Style="{StaticResource NavButton}" Content="Uebersicht"/>
                    <Button x:Name="NavActivities" Style="{StaticResource NavButton}" Content="Aktivitaeten"/>
                    <Button x:Name="NavFindings" Style="{StaticResource NavButton}" Content="Befunde"/>
                    <Button x:Name="NavHistory" Style="{StaticResource NavButton}" Content="Verlauf"/>
                </StackPanel>
                <Border Grid.Row="3" Background="#0E211D" BorderBrush="#1C523F" BorderThickness="1" CornerRadius="12" Padding="13">
                    <StackPanel><TextBlock Text="LOKAL UND PRIVAT" Foreground="{StaticResource Green}" FontWeight="SemiBold"/><TextBlock Text="Keine Cloud. Keine Telemetrie." Foreground="#8FA8A0" Margin="0,5,0,0" FontSize="12"/></StackPanel>
                </Border>
            </Grid>
        </Border>

        <Grid Grid.Column="1" Margin="27,21,27,18">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel><TextBlock x:Name="ViewTitle" Text="Uebersicht" FontSize="27" FontWeight="SemiBold"/><TextBlock x:Name="ViewSubtitle" Text="Neue Aktivitaeten und wichtige Aenderungen auf einen Blick." Foreground="#91A5B2" Margin="0,5,0,0"/></StackPanel>
                <Button x:Name="ScanButton" Grid.Column="1" Content="Jetzt pruefen" MinWidth="130" Height="60"/>
            </Grid>

            <Grid Grid.Row="1" Margin="0,20,0,0">
                <Grid x:Name="OverviewView">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <Grid Margin="0,0,0,18">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17"><StackPanel><TextBlock Text="Internetaktive Apps" Foreground="#92A6B2"/><TextBlock x:Name="AppsCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Accent}" Margin="0,4,0,0"/></StackPanel></Border>
                        <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17"><StackPanel><TextBlock Text="Neu entdeckt" Foreground="#92A6B2"/><TextBlock x:Name="NewCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Amber}" Margin="0,4,0,0"/></StackPanel></Border>
                        <Border Grid.Column="4" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17"><StackPanel><TextBlock Text="Befunde" Foreground="#92A6B2"/><TextBlock x:Name="FindingsCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Red}" Margin="0,4,0,0"/><TextBlock x:Name="CriticalHint" Text="0 kritisch" FontSize="11" Foreground="#8DA1AD"/></StackPanel></Border>
                    </Grid>
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="1.55*"/><ColumnDefinition Width="17"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                            <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                                <StackPanel Margin="17,14,17,11"><TextBlock Text="Aktuelle Aktivitaeten" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Ziele werden aus dem lokalen DNS-Cache erklaert" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                                <DataGrid x:Name="OverviewActivityGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.15*"/><DataGridTextColumn Header="ZIEL" Binding="{Binding Target}" Width="1.5*"/><DataGridTextColumn Header="STATUS" Binding="{Binding Change}" Width="105"/></DataGrid.Columns></DataGrid>
                            </Grid>
                        </Border>
                        <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                            <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <StackPanel Margin="17,14,17,11"><TextBlock Text="Wichtigste Befunde" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Gebuedelt statt Warnungsflut" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                                <ListBox x:Name="OverviewFindingsList" Grid.Row="1" Background="Transparent" BorderThickness="0" Foreground="#ECF3F7" DisplayMemberPath="Summary" Padding="10"/>
                                <Button x:Name="ReportButton" Grid.Row="2" Content="Lokalen Bericht oeffnen" Margin="15"/>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>

                <Border x:Name="ActivitiesView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock Text="Alle aktiven Internetverbindungen" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Domain, Anbieter, IP-Adresse und erster Erkennungszeitpunkt" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="ActivityGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.1*"/><DataGridTextColumn Header="ZIEL" Binding="{Binding Target}" Width="1.35*"/><DataGridTextColumn Header="ANBIETER" Binding="{Binding Provider}" Width="1.15*"/><DataGridTextColumn Header="IP" Binding="{Binding Address}" Width="1.05*"/><DataGridTextColumn Header="PORT" Binding="{Binding Port}" Width="60"/><DataGridTextColumn Header="STATUS" Binding="{Binding Change}" Width="100"/><DataGridTextColumn Header="ERSTMALS" Binding="{Binding FirstSeenDisplay}" Width="105"/></DataGrid.Columns></DataGrid>
                    </Grid>
                </Border>

                <Border x:Name="FindingsView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock Text="Befunde und Systemaenderungen" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Neue oder veraenderte Autostarts und auffaelliges Prozessverhalten" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="FindingsGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="STUFE" Binding="{Binding Level}" Width="95"/><DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.0*"/><DataGridTextColumn Header="BEGRUENDUNG" Binding="{Binding Summary}" Width="2.8*"/><DataGridTextColumn Header="PUNKTE" Binding="{Binding Score}" Width="70"/></DataGrid.Columns></DataGrid>
                    </Grid>
                </Border>

                <Border x:Name="HistoryView" Visibility="Collapsed" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11"><TextBlock Text="Lokaler 7-Tage-Verlauf" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Es wird nur bei Aenderungen oder spaetestens alle 15 Minuten gespeichert" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/></StackPanel>
                        <DataGrid x:Name="HistoryGrid" Grid.Row="1" AlternationCount="2"><DataGrid.Columns><DataGridTextColumn Header="ZEIT" Binding="{Binding Time}" Width="135"/><DataGridTextColumn Header="APPS" Binding="{Binding Apps}" Width="60"/><DataGridTextColumn Header="VERBINDUNGEN" Binding="{Binding Connections}" Width="105"/><DataGridTextColumn Header="NEU" Binding="{Binding New}" Width="55"/><DataGridTextColumn Header="BEFUNDE" Binding="{Binding Findings}" Width="70"/><DataGridTextColumn Header="ZUSAMMENFASSUNG" Binding="{Binding Summary}" Width="2.5*"/></DataGrid.Columns></DataGrid>
                    </Grid>
                </Border>
            </Grid>

            <Grid Grid.Row="2" Margin="0,13,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock x:Name="StatusText" Text="Bereit" Foreground="#8DA1AD"/><TextBlock Grid.Column="1" Text="TrackerRadar 0.3 Alpha · SC LABS" Foreground="#627985"/></Grid>
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
$overviewView = $window.FindName('OverviewView')
$activitiesView = $window.FindName('ActivitiesView')
$findingsView = $window.FindName('FindingsView')
$historyView = $window.FindName('HistoryView')

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

$scLabsBitmap = Set-UiImage -Control $scLabsLogo -Path (Join-Path $script:Root 'assets\branding\sclabs-mark.png')
$trackerRadarBitmap = Set-UiImage -Control $trackerRadarLogo -Path (Join-Path $script:Root 'assets\branding\trackerradar-logo.png')
if ($trackerRadarBitmap) { $window.Icon = $trackerRadarBitmap }

function Set-View {
    param([string]$Name)
    foreach ($view in @($overviewView,$activitiesView,$findingsView,$historyView)) { $view.Visibility = 'Collapsed' }
    foreach ($button in @($navOverview,$navActivities,$navFindings,$navHistory)) {
        $button.Background = [System.Windows.Media.Brushes]::Transparent
        $button.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(170,186,196))
        $button.FontWeight = 'Normal'
    }

    switch ($Name) {
        'Activities' { $activitiesView.Visibility='Visible'; $navActivities.Background='#102630'; $navActivities.Foreground='#25D7C0'; $navActivities.FontWeight='SemiBold'; $viewTitle.Text='Aktivitaeten'; $viewSubtitle.Text='Alle aktuellen Ziele mit Anbieter, IP und erstem Erkennungszeitpunkt.' }
        'Findings' { $findingsView.Visibility='Visible'; $navFindings.Background='#102630'; $navFindings.Foreground='#25D7C0'; $navFindings.FontWeight='SemiBold'; $viewTitle.Text='Befunde'; $viewSubtitle.Text='Nur neue, veraenderte oder technisch auffaellige Aktivitaeten.' }
        'History' { $historyView.Visibility='Visible'; $navHistory.Background='#102630'; $navHistory.Foreground='#25D7C0'; $navHistory.FontWeight='SemiBold'; $viewTitle.Text='Verlauf'; $viewSubtitle.Text='Lokal gespeicherte Aenderungen der letzten sieben Tage.' }
        default { $overviewView.Visibility='Visible'; $navOverview.Background='#102630'; $navOverview.Foreground='#25D7C0'; $navOverview.FontWeight='SemiBold'; $viewTitle.Text='Uebersicht'; $viewSubtitle.Text='Neue Aktivitaeten und wichtige Aenderungen auf einen Blick.' }
    }
}

function Update-Ui {
    try {
        $scanButton.IsEnabled = $false
        $scanButton.Content = 'Pruefe ...'
        $statusText.Text = 'Lokale Auswertung laeuft ...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        $window.Dispatcher.Invoke([action]{}, 'Background')

        $snapshot = Get-Snapshot
        $overviewActivityGrid.ItemsSource = @($snapshot.Activities | Select-Object -First 15)
        $overviewFindingsList.ItemsSource = @($snapshot.Findings | Select-Object -First 8)
        $activityGrid.ItemsSource = @($snapshot.Activities)
        $findingsGrid.ItemsSource = @($snapshot.Findings)
        $historyGrid.ItemsSource = @($snapshot.History)
        $appsCount.Text = [string]$snapshot.ActiveApps
        $newCount.Text = [string]$snapshot.NewCount
        $findingsCount.Text = [string]$snapshot.FindingCount
        $criticalHint.Text = "$($snapshot.CriticalCount) kritisch"

        if (-not $snapshot.BaselineExists) {
            $statusText.Text = "Baseline erstellt | $($snapshot.ExternalConnections) Verbindung(en) | $($snapshot.DurationMs) ms"
        } else {
            $statusText.Text = "Letzte Pruefung: $(Get-Date -Format 'HH:mm:ss') | $($snapshot.ExternalConnections) Verbindung(en) | $($snapshot.NewCount) neu | $($snapshot.DurationMs) ms"
        }
        $snapshot = $null
    } catch {
        $statusText.Text = "Pruefung fehlgeschlagen: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'TrackerRadar', 'OK', 'Error') | Out-Null
    } finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
        $scanButton.Content = 'Jetzt pruefen'
        $scanButton.IsEnabled = $true
        [GC]::Collect(0, [GCCollectionMode]::Optimized)
    }
}

$navOverview.Add_Click({ Set-View 'Overview' })
$navActivities.Add_Click({ Set-View 'Activities' })
$navFindings.Add_Click({ Set-View 'Findings' })
$navHistory.Add_Click({ Set-View 'History' })
$scanButton.Add_Click({ Update-Ui })
$reportButton.Add_Click({ $report = Join-Path $script:Data 'latest-scan.json'; if (Test-Path -LiteralPath $report) { Start-Process explorer.exe -ArgumentList @('/select,', $report) } })

$showActivity = {
    param($grid)
    $item = $grid.SelectedItem
    if ($item) {
        $text = "App: $($item.App)`nZiel: $($item.Target)`nAnbieter: $($item.Provider)`nZweck: $($item.Purpose)`nIP: $($item.Address):$($item.Port)`nPID: $($item.Pid)`nStatus: $($item.Change)`nErstmals erkannt: $($item.FirstSeenDisplay)`nPfad: $($item.Path)`n`n$($item.Reason)"
        [System.Windows.MessageBox]::Show($text, 'Aktivitaetsdetails', 'OK', 'Information') | Out-Null
    }
}
$overviewActivityGrid.Add_MouseDoubleClick({ & $showActivity $overviewActivityGrid })
$activityGrid.Add_MouseDoubleClick({ & $showActivity $activityGrid })
$findingsGrid.Add_MouseDoubleClick({ $item=$findingsGrid.SelectedItem; if ($item) { [System.Windows.MessageBox]::Show("$($item.Summary)`n`n$($item.Detail)", 'Befunddetails', 'OK', 'Warning') | Out-Null } })
$overviewFindingsList.Add_MouseDoubleClick({ $item=$overviewFindingsList.SelectedItem; if ($item) { [System.Windows.MessageBox]::Show("$($item.Summary)`n`n$($item.Detail)", 'Befunddetails', 'OK', 'Warning') | Out-Null } })
$historyGrid.Add_MouseDoubleClick({ $item=$historyGrid.SelectedItem; if ($item) { $changes=if ([string]::IsNullOrWhiteSpace([string]$item.Changes)) {'Keine Einzelveraenderungen gespeichert.'} else {$item.Changes}; [System.Windows.MessageBox]::Show("$($item.Time)`n$($item.Summary)`n`n$changes", 'Verlaufsdetails', 'OK', 'Information') | Out-Null } })

if ($UiSmokeTest) {
    try {
        $results = @()
        foreach ($name in @('Overview','Activities','Findings','History')) {
            Set-View $name
            $visibleCount = @($overviewView,$activitiesView,$findingsView,$historyView | Where-Object { $_.Visibility -eq 'Visible' }).Count
            $results += [pscustomobject]@{ View=$name; Passed=($visibleCount -eq 1); VisibleCount=$visibleCount }
        }
        $passed = @($results | Where-Object { $_.Passed }).Count
        [pscustomobject]@{ Product='TrackerRadar Alpha'; Version=$script:Version; Passed=$passed; Failed=($results.Count-$passed); Views=$results } | ConvertTo-Json -Depth 5
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
