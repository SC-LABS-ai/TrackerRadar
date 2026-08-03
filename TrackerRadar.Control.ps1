param(
    [string]$RequestFile,
    [switch]$SelfTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Data = Join-Path $script:Root 'data'
$script:Changes = Join-Path $script:Data 'changes'
$script:DisabledStartup = Join-Path $script:Data 'disabled-startup'
$script:ControlTemp = Join-Path $script:Data 'control-requests'
foreach ($folder in @($script:Data,$script:Changes,$script:DisabledStartup,$script:ControlTemp)) {
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function New-ChangeId {
    return ('chg-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,8)))
}

function Get-ShortHash {
    param([string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Value)
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')
        return $hash.Substring(0,12)
    } finally { $sha.Dispose() }
}

function Write-JsonFile {
    param([string]$Path,$Value,[int]$Depth=8)
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
}

function Save-ChangeRecord {
    param($Record)
    $path = Join-Path $script:Changes ($Record.Id + '.json')
    Write-JsonFile -Path $path -Value $Record -Depth 10
    return $path
}

function Get-ChangeRecords {
    $records = @()
    foreach ($file in Get-ChildItem -LiteralPath $script:Changes -Filter '*.json' -File -ErrorAction SilentlyContinue) {
        try { $records += Read-JsonFile $file.FullName } catch { }
    }
    return @($records | Sort-Object Timestamp -Descending)
}

function Resolve-RegistryLocation {
    param([string]$Location)
    if ($Location -match '^HKCU:\\(.+)$') { return 'Registry::HKEY_CURRENT_USER\' + $Matches[1] }
    if ($Location -match '^HKLM:\\(.+)$') { return 'Registry::HKEY_LOCAL_MACHINE\' + $Matches[1] }
    throw "Nicht unterstuetzter Registry-Pfad: $Location"
}

function Invoke-Netsh {
    param([string[]]$Arguments)
    $output = & netsh.exe @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "netsh fehlgeschlagen (Exit $code): $($output -join ' ')" }
    return ($output -join [Environment]::NewLine)
}

function Get-FirewallRuleSnapshot {
    param([string]$RuleName)
    $output = & netsh.exe advfirewall firewall show rule name="$RuleName" verbose 2>&1
    $code = $LASTEXITCODE
    $text = ($output -join [Environment]::NewLine)
    $notFound = $text -match 'No rules match|Keine Regeln|Es wurden keine Regeln'
    return [pscustomobject]@{
        Exists = ($code -eq 0 -and -not $notFound)
        ExitCode = $code
        Text = $text
    }
}

function Apply-BlockInternet {
    param($Request)
    $programPath = [string]$Request.ProgramPath
    if ([string]::IsNullOrWhiteSpace($programPath) -or -not (Test-Path -LiteralPath $programPath -PathType Leaf)) {
        throw 'Der Programmpfad ist nicht vorhanden oder ungueltig.'
    }

    $id = if ($Request.ChangeId) { [string]$Request.ChangeId } else { New-ChangeId }
    $hash = Get-ShortHash $programPath.ToLowerInvariant()
    $ruleName = "SC LABS TrackerRadar Block $hash"
    $existing = Get-FirewallRuleSnapshot $ruleName
    if ($existing.Exists) {
        throw "Eine TrackerRadar-Regel fuer dieses Programm existiert bereits: $ruleName"
    }
    if (-not (Test-IsAdministrator)) { throw 'Administratorrechte sind fuer die Firewall-Regel erforderlich.' }

    $record = [pscustomobject]@{
        Id = $id
        Timestamp = (Get-Date).ToString('o')
        Action = 'BlockInternet'
        DisplayAction = 'Internetzugriff blockiert'
        Target = $programPath
        TargetName = [IO.Path]::GetFileName($programPath)
        Status = 'Pending'
        RequiresAdmin = $true
        Undo = [pscustomobject]@{ Type='FirewallRule'; RuleName=$ruleName }
        Evidence = [pscustomobject]@{ RuleName=$ruleName; Netsh=''; Verified=$false }
    }
    $recordPath = Save-ChangeRecord $record
    try {
        $netshOutput = Invoke-Netsh @('advfirewall','firewall','add','rule',"name=$ruleName",'dir=out','action=block',"program=$programPath",'enable=yes','profile=any')
        $verified = Get-FirewallRuleSnapshot $ruleName
        if (-not $verified.Exists -or $verified.Text.IndexOf($programPath,[StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw 'Die Windows-Firewall-Regel konnte nach dem Anlegen nicht eindeutig bestaetigt werden.'
        }
        $record.Status = 'Applied'
        $record.Evidence.Netsh = $netshOutput
        $record.Evidence.Verified = $true
        Save-ChangeRecord $record | Out-Null
        return [pscustomobject]@{ Ok=$true; ChangeId=$id; RecordPath=$recordPath; Message="Internetzugriff fuer $($record.TargetName) blockiert und verifiziert." }
    } catch {
        try {
            $remaining = Get-FirewallRuleSnapshot $ruleName
            if ($remaining.Exists) { Invoke-Netsh @('advfirewall','firewall','delete','rule',"name=$ruleName") | Out-Null }
        } catch { }
        $record.Status = 'Failed'
        $record | Add-Member -NotePropertyName Error -NotePropertyValue $_.Exception.Message -Force
        Save-ChangeRecord $record | Out-Null
        throw
    }
}

function Apply-DisableStartup {
    param($Request)
    $name = [string]$Request.Name
    $location = [string]$Request.Location
    $command = [string]$Request.Command
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($location)) { throw 'Autostartname oder Speicherort fehlt.' }

    $id = if ($Request.ChangeId) { [string]$Request.ChangeId } else { New-ChangeId }
    $requiresAdmin = $location.StartsWith('HKLM:',[StringComparison]::OrdinalIgnoreCase) -or $location.StartsWith($env:ProgramData,[StringComparison]::OrdinalIgnoreCase)
    if ($requiresAdmin -and -not (Test-IsAdministrator)) { throw 'Administratorrechte sind fuer diesen Autostart erforderlich.' }

    $undo = $null
    $evidence = $null
    if ($location -match '^HK(CU|LM):\\') {
        $registryPath = Resolve-RegistryLocation $location
        if (-not (Test-Path -LiteralPath $registryPath)) { throw "Registry-Pfad nicht vorhanden: $location" }
        $registryKey = Get-Item -LiteralPath $registryPath -ErrorAction Stop
        $valueKind = $registryKey.GetValueKind($name).ToString()
        $originalValue = $registryKey.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $originalValue) { throw "Registry-Wert nicht vorhanden: $name" }
        $undo = [pscustomobject]@{ Type='RegistryValue'; Location=$location; Name=$name; Value=$originalValue; ValueKind=$valueKind }
        $evidence = [pscustomobject]@{ Location=$location; Name=$name; Value=$originalValue; ValueKind=$valueKind }
    } else {
        $sourcePath = $command
        if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw 'Die Autostartdatei ist nicht vorhanden.'
        }
        $disabledFolder = Join-Path $script:DisabledStartup $id
        $disabledPath = Join-Path $disabledFolder ([IO.Path]::GetFileName($sourcePath))
        $undo = [pscustomobject]@{ Type='StartupFile'; OriginalPath=$sourcePath; DisabledPath=$disabledPath }
        $evidence = [pscustomobject]@{ OriginalPath=$sourcePath; DisabledPath=$disabledPath }
    }

    $record = [pscustomobject]@{
        Id = $id
        Timestamp = (Get-Date).ToString('o')
        Action = 'DisableStartup'
        DisplayAction = 'Autostart deaktiviert'
        Target = $location
        TargetName = $name
        Status = 'Pending'
        RequiresAdmin = $requiresAdmin
        Undo = $undo
        Evidence = $evidence
    }
    $recordPath = Save-ChangeRecord $record

    try {
        if ([string]$undo.Type -eq 'RegistryValue') {
            $registryPath = Resolve-RegistryLocation $location
            Remove-ItemProperty -LiteralPath $registryPath -Name $name -ErrorAction Stop
        } else {
            $disabledFolder = Split-Path -Parent ([string]$undo.DisabledPath)
            New-Item -ItemType Directory -Path $disabledFolder -Force | Out-Null
            Move-Item -LiteralPath ([string]$undo.OriginalPath) -Destination ([string]$undo.DisabledPath) -Force
        }
        $record.Status = 'Applied'
        Save-ChangeRecord $record | Out-Null
        return [pscustomobject]@{ Ok=$true; ChangeId=$id; RecordPath=$recordPath; Message="Autostart $name deaktiviert." }
    } catch {
        $record.Status = 'Failed'
        $record | Add-Member -NotePropertyName Error -NotePropertyValue $_.Exception.Message -Force
        Save-ChangeRecord $record | Out-Null
        throw
    }
}

function Undo-Change {
    param($Request)
    $changeId = [string]$Request.ChangeId
    if ([string]::IsNullOrWhiteSpace($changeId)) { throw 'ChangeId fehlt.' }
    $recordPath = Join-Path $script:Changes ($changeId + '.json')
    $record = Read-JsonFile $recordPath
    if (-not $record) { throw "Aenderung nicht gefunden: $changeId" }
    if ([string]$record.Status -eq 'Undone') { return [pscustomobject]@{ Ok=$true; ChangeId=$changeId; Message='Aenderung war bereits rueckgaengig gemacht.' } }

    $undoType = [string]$record.Undo.Type
    switch ($undoType) {
        'FirewallRule' {
            if (-not (Test-IsAdministrator)) { throw 'Administratorrechte sind zum Entfernen der Firewall-Regel erforderlich.' }
            $ruleName = [string]$record.Undo.RuleName
            $before = Get-FirewallRuleSnapshot $ruleName
            if ($before.Exists) {
                Invoke-Netsh @('advfirewall','firewall','delete','rule',"name=$ruleName") | Out-Null
            }
            $after = Get-FirewallRuleSnapshot $ruleName
            if ($after.Exists) { throw 'Die Firewall-Regel ist nach der Ruecknahme weiterhin vorhanden.' }
        }
        'RegistryValue' {
            $location = [string]$record.Undo.Location
            $requiresAdmin = $location.StartsWith('HKLM:',[StringComparison]::OrdinalIgnoreCase)
            if ($requiresAdmin -and -not (Test-IsAdministrator)) { throw 'Administratorrechte sind zum Wiederherstellen dieses Autostarts erforderlich.' }
            $registryPath = Resolve-RegistryLocation $location
            if (-not (Test-Path -LiteralPath $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
            $valueKind = if ($record.Undo.PSObject.Properties.Name -contains 'ValueKind') { [string]$record.Undo.ValueKind } else { 'String' }
            $propertyType = switch ($valueKind) {
                'ExpandString' { 'ExpandString' }
                'MultiString' { 'MultiString' }
                'Binary' { 'Binary' }
                'DWord' { 'DWord' }
                'QWord' { 'QWord' }
                default { 'String' }
            }
            $restoreValue = $record.Undo.Value
            New-ItemProperty -LiteralPath $registryPath -Name ([string]$record.Undo.Name) -Value $restoreValue -PropertyType $propertyType -Force | Out-Null
        }
        'StartupFile' {
            $originalPath = [string]$record.Undo.OriginalPath
            $disabledPath = [string]$record.Undo.DisabledPath
            $requiresAdmin = $originalPath.StartsWith($env:ProgramData,[StringComparison]::OrdinalIgnoreCase)
            if ($requiresAdmin -and -not (Test-IsAdministrator)) { throw 'Administratorrechte sind zum Wiederherstellen dieser Autostartdatei erforderlich.' }
            if (-not (Test-Path -LiteralPath $disabledPath -PathType Leaf)) { throw 'Gesicherte Autostartdatei fehlt.' }
            $parent = Split-Path -Parent $originalPath
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Move-Item -LiteralPath $disabledPath -Destination $originalPath -Force
        }
        default { throw "Unbekannter Undo-Typ: $undoType" }
    }

    $record.Status = 'Undone'
    if ($record.PSObject.Properties.Name -contains 'UndoneAt') {
        $record.UndoneAt = (Get-Date).ToString('o')
    } else {
        $record | Add-Member -NotePropertyName UndoneAt -NotePropertyValue ((Get-Date).ToString('o'))
    }
    Save-ChangeRecord $record | Out-Null
    return [pscustomobject]@{ Ok=$true; ChangeId=$changeId; Message="Aenderung $changeId wurde rueckgaengig gemacht." }
}

function Invoke-ControlRequest {
    param($Request)
    switch ([string]$Request.Action) {
        'BlockInternet' { return Apply-BlockInternet $Request }
        'DisableStartup' { return Apply-DisableStartup $Request }
        'UndoChange' { return Undo-Change $Request }
        'ListChanges' { return [pscustomobject]@{ Ok=$true; Changes=@(Get-ChangeRecords) } }
        default { throw "Unbekannte Aktion: $($Request.Action)" }
    }
}

function Invoke-SelfTest {
    $checks = @()
    $checks += [pscustomobject]@{ Name='netsh'; Passed=[bool](Get-Command netsh.exe -ErrorAction SilentlyContinue); Detail='Windows Firewall CLI' }
    $checks += [pscustomobject]@{ Name='ChangeVault'; Passed=(Test-Path -LiteralPath $script:Changes); Detail=$script:Changes }
    $checks += [pscustomobject]@{ Name='AdminDetection'; Passed=$true; Detail=[string](Test-IsAdministrator) }
    $ruleName = 'SC LABS TrackerRadar Block ' + (Get-ShortHash 'C:\Test\app.exe')
    $checks += [pscustomobject]@{ Name='RuleName'; Passed=($ruleName.Length -lt 100); Detail=$ruleName }
    $missingRule = Get-FirewallRuleSnapshot ('SC LABS TrackerRadar SelfTest ' + [guid]::NewGuid().ToString('N'))
    $checks += [pscustomobject]@{ Name='FirewallLookup'; Passed=(-not $missingRule.Exists); Detail='Nicht vorhandene Regel korrekt erkannt' }

    $testRoot = Join-Path $script:ControlTemp ('selftest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    try {
        $original = Join-Path $testRoot 'test-startup.lnk'
        Set-Content -LiteralPath $original -Value 'TrackerRadar control test' -Encoding UTF8
        $request = [pscustomobject]@{ Action='DisableStartup'; Name='TrackerRadarControlTest'; Location=$testRoot; Command=$original; ChangeId=('test-' + [guid]::NewGuid().ToString('N')) }
        $apply = Apply-DisableStartup $request
        $disabled = -not (Test-Path -LiteralPath $original)
        $undo = Undo-Change ([pscustomobject]@{ ChangeId=$apply.ChangeId })
        $restored = Test-Path -LiteralPath $original
        $checks += [pscustomobject]@{ Name='FileStartupDisable'; Passed=$disabled; Detail=$apply.ChangeId }
        $checks += [pscustomobject]@{ Name='FileStartupUndo'; Passed=$restored; Detail=$undo.Message }
        Remove-Item -LiteralPath (Join-Path $script:Changes ($apply.ChangeId + '.json')) -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $script:DisabledStartup $apply.ChangeId) -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $registryTestPath = 'HKCU:\Software\SC LABS\TrackerRadar\SelfTest'
    $registryTestName = 'TrackerRadarControlRegistryTest'
    $registryTestValue = '%TEMP%\TrackerRadarControlTest.exe'
    $registryChangeId = 'test-' + [guid]::NewGuid().ToString('N')
    try {
        if (-not (Test-Path -LiteralPath $registryTestPath)) { New-Item -Path $registryTestPath -Force | Out-Null }
        New-ItemProperty -LiteralPath $registryTestPath -Name $registryTestName -Value $registryTestValue -PropertyType ExpandString -Force | Out-Null
        $request = [pscustomobject]@{ Action='DisableStartup'; Name=$registryTestName; Location=$registryTestPath; Command=$registryTestValue; ChangeId=$registryChangeId }
        $applyRegistry = Apply-DisableStartup $request
        $registryDisabled = $false
        try { Get-ItemProperty -LiteralPath $registryTestPath -Name $registryTestName -ErrorAction Stop | Out-Null } catch { $registryDisabled = $true }
        $undoRegistry = Undo-Change ([pscustomobject]@{ ChangeId=$applyRegistry.ChangeId })
        $registryKey = Get-Item -LiteralPath $registryTestPath -ErrorAction Stop
        $restoredKind = $registryKey.GetValueKind($registryTestName).ToString()
        $restoredValue = $registryKey.GetValue($registryTestName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $registryRestored = ($restoredKind -eq 'ExpandString' -and [string]$restoredValue -eq $registryTestValue)
        $checks += [pscustomobject]@{ Name='RegistryStartupDisable'; Passed=$registryDisabled; Detail=$applyRegistry.ChangeId }
        $checks += [pscustomobject]@{ Name='RegistryStartupUndo'; Passed=$registryRestored; Detail="$restoredKind | $restoredValue" }
        Remove-Item -LiteralPath (Join-Path $script:Changes ($applyRegistry.ChangeId + '.json')) -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -LiteralPath $registryTestPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $result = [pscustomobject]@{ Product='TrackerRadar Control'; Version='0.4.1-alpha'; Passed=@($checks | Where-Object {$_.Passed}).Count; Failed=@($checks | Where-Object {-not $_.Passed}).Count; Checks=$checks }
    $result | ConvertTo-Json -Depth 6
    if ($result.Failed -gt 0) { exit 1 }
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if ([string]::IsNullOrWhiteSpace($RequestFile)) { throw 'RequestFile fehlt.' }
$request = Read-JsonFile $RequestFile
$responsePath = [IO.Path]::ChangeExtension($RequestFile,'.response.json')
try {
    $response = Invoke-ControlRequest $request
    Write-JsonFile -Path $responsePath -Value $response -Depth 10
    $response | ConvertTo-Json -Depth 10
    exit 0
} catch {
    $response = [pscustomobject]@{ Ok=$false; Error=$_.Exception.Message; Action=[string]$request.Action }
    Write-JsonFile -Path $responsePath -Value $response -Depth 6
    $response | ConvertTo-Json -Depth 6
    exit 1
}
