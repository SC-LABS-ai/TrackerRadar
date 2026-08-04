Set-StrictMode -Version 2.0

function Initialize-TrackerRadarLocalization {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Data)
    $script:LocaleRoot = Join-Path $Root 'locales'
    $script:UiSettingsPath = Join-Path $Data 'ui-settings.json'
    $script:Language = 'de'
    $script:Locale = $null
    $settings = Read-JsonFile $script:UiSettingsPath
    if ($settings -and [string]$settings.Language -in @('de','en')) { $script:Language = [string]$settings.Language }
    $script:Locale = Get-TrackerRadarLocale $script:Language
}

function Get-TrackerRadarLocale {
    param([ValidateSet('de','en')][string]$Language)
    $path = Join-Path $script:LocaleRoot ($Language + '.json')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Locale file missing: $path" }
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
}

function Get-Text {
    param([Parameter(Mandatory)][string]$Key)
    if ($null -eq $script:Locale) { return $Key }
    $property = $script:Locale.PSObject.Properties[$Key]
    if ($null -eq $property) { return $Key }
    return [string]$property.Value
}

function Format-Text {
    param([Parameter(Mandatory)][string]$Key,[object[]]$Values)
    return [string]::Format((Get-Text $Key),$Values)
}

function Set-TrackerRadarLanguage {
    param([ValidateSet('de','en')][string]$Language,[bool]$Save=$true)
    $script:Language = $Language
    $script:Locale = Get-TrackerRadarLocale $Language
    if ($Save) { Write-JsonFile -Path $script:UiSettingsPath -Value ([pscustomobject]@{ Language=$Language }) -Depth 3 }
}

function Convert-DisplayText {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return [string]$Text }
    switch -Exact ($Text) {
        'Unbekannter Dienst' { return (Get-Text 'UnknownService') }
        'Verschluesselte Webverbindung' { return (Get-Text 'PurposeEncryptedWeb') }
        'Webverbindung' { return (Get-Text 'PurposeWeb') }
        'KI-Cloud-Dienst' { return (Get-Text 'PurposeAICloud') }
        'Microsoft- oder Windows-Onlinedienst' { return (Get-Text 'PurposeMicrosoftOnline') }
        'Google-Onlinedienst' { return (Get-Text 'PurposeGoogleOnline') }
        'Cloud- oder Inhaltsdienst' { return (Get-Text 'PurposeCloudContent') }
        'Netzwerk- oder Inhaltsdienst' { return (Get-Text 'PurposeNetworkContent') }
        'Inhaltsauslieferung' { return (Get-Text 'PurposeContentDelivery') }
        'Software- oder Entwicklungsdienst' { return (Get-Text 'PurposeSoftwareDevelopment') }
        'Cloud-Synchronisierung' { return (Get-Text 'PurposeCloudSync') }
        'Apple-Onlinedienst' { return (Get-Text 'PurposeAppleOnline') }
        'Aktive externe Verbindung' { return (Get-Text 'ReasonActiveConnection') }
        'Baseline' { return (Get-Text 'ChangeBaseline') }
        'Neu' { return (Get-Text 'ChangeNew') }
        'Wieder aktiv' { return (Get-Text 'ChangeReactivated') }
        'Aktiv' { return (Get-Text 'ChangeActive') }
        'Bekannt' { return (Get-Text 'ChangeKnown') }
        'Geaendert' { return (Get-Text 'ChangeChanged') }
        'Neu entdeckt' { return (Get-Text 'StatusNewDetected') }
        'Erlaubt' { return (Get-Text 'StatusAllowed') }
        'Kritisch' { return (Get-Text 'StatusCritical') }
        'Verdaechtig' { return (Get-Text 'StatusSuspicious') }
        'Pruefen' { return (Get-Text 'StatusReview') }
        'Info' { return (Get-Text 'StatusInfo') }
        'Geoeffnet' { return (Get-Text 'AccessOpened') }
        'Ordner durchsucht' { return (Get-Text 'AccessDirectory') }
        'Dokumente' { return (Get-Text 'FolderDocuments') }
        'Desktop' { return (Get-Text 'FolderDesktop') }
        'Downloads' { return (Get-Text 'FolderDownloads') }
        'OneDrive' { return (Get-Text 'FolderOneDrive') }
        'Edge-Profil' { return (Get-Text 'FolderEdge') }
        'Chrome-Profil' { return (Get-Text 'FolderChrome') }
        'Internetzugriff blockiert' { return (Get-Text 'ActionInternetBlocked') }
        'Autostart deaktiviert' { return (Get-Text 'ActionStartupDisabled') }
    }
    if ($Text -match '^Netzwerkdienst auf Port (\d+)$') { return (Format-Text 'PurposeNetworkPort' @($Matches[1])) }
    if ($script:Language -eq 'de') { return $Text }
    $value = $Text
    $replacements = [ordered]@{
        'Start aus einem ungewoehnlichen Ordner' = 'Started from an unusual folder'
        'Script- oder Systemwerkzeug mit Internetzugriff' = 'Script or system tool with internet access'
        'Programmpfad konnte nicht bestaetigt werden' = 'Executable path could not be confirmed'
        'viele gleichzeitige Verbindungen' = 'many simultaneous connections'
        'Autostart aus einem ungewoehnlichen Ordner.' = 'Startup entry from an unusual folder.'
        'neuer Autostart wurde entdeckt.' = 'new startup entry detected.'
        'bestehender Autostart wurde veraendert.' = 'existing startup entry changed.'
        'Autostart ist nicht mehr vorhanden.' = 'startup entry is no longer present.'
        'Aktuell keine externen TCP-Verbindungen erkannt.' = 'No external TCP connections currently detected.'
        'Dies ist eine Momentaufnahme.' = 'This is a point-in-time snapshot.'
        'Keine Einzelveraenderungen gespeichert.' = 'No individual changes were stored.'
        'Internetzugriff fuer ' = 'Internet access for '
        ' blockiert und verifiziert.' = ' blocked and verified.'
        'Autostart ' = 'Startup entry '
        ' deaktiviert.' = ' disabled.'
        'Aenderung war bereits rueckgaengig gemacht.' = 'The change had already been undone.'
        ' wurde rueckgaengig gemacht.' = ' was undone.'
    }
    foreach ($entry in $replacements.GetEnumerator()) { $value = $value.Replace([string]$entry.Key,[string]$entry.Value) }
    if ($value -match '^(\d+) Apps, (\d+) Verbindungen, (\d+) neu, (\d+) Befunde$') {
        return "$($Matches[1]) apps, $($Matches[2]) connections, $($Matches[3]) new, $($Matches[4]) findings"
    }
    return $value
}

function Convert-ActivityRows {
    param([object[]]$Rows)
    return @($Rows | ForEach-Object {
        [pscustomobject]@{
            Key=$_.Key; App=$_.App; Pid=$_.Pid; Target=$_.Target; Domain=$_.Domain; Address=$_.Address
            Provider=(Convert-DisplayText ([string]$_.Provider)); Purpose=(Convert-DisplayText ([string]$_.Purpose))
            Port=$_.Port; Path=$_.Path; FirstSeen=$_.FirstSeen; FirstSeenDisplay=$_.FirstSeenDisplay
            Change=(Convert-DisplayText ([string]$_.Change)); Status=(Convert-DisplayText ([string]$_.Status))
            Risk=$_.Risk; Reason=(Convert-DisplayText ([string]$_.Reason))
        }
    })
}

function Convert-FindingRows {
    param([object[]]$Rows)
    return @($Rows | ForEach-Object {
        $copy = [ordered]@{}
        foreach ($property in $_.PSObject.Properties) { $copy[$property.Name] = $property.Value }
        $copy['Level'] = Convert-DisplayText ([string]$_.Level)
        $copy['Summary'] = Convert-DisplayText ([string]$_.Summary)
        $copy['Detail'] = Convert-DisplayText ([string]$_.Detail)
        [pscustomobject]$copy
    })
}

function Convert-HistoryRows {
    param([object[]]$Rows)
    return @($Rows | ForEach-Object {
        [pscustomobject]@{
            Timestamp=$_.Timestamp; Time=$_.Time; Apps=$_.Apps; Connections=$_.Connections; New=$_.New; Findings=$_.Findings
            Summary=(Convert-DisplayText ([string]$_.Summary)); Changes=(Convert-DisplayText ([string]$_.Changes))
        }
    })
}

function Convert-AccessRows {
    param([object[]]$Rows)
    return @($Rows | ForEach-Object {
        [pscustomobject]@{
            ProcessName=$_.ProcessName; ProcessId=$_.ProcessId; ExecutablePath=$_.ExecutablePath
            Folder=(Convert-DisplayText ([string]$_.Folder)); Operation=(Convert-DisplayText ([string]$_.Operation)); AccessCount=$_.AccessCount
        }
    })
}
