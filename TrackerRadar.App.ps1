param(
    [switch]$SelfTest,
    [switch]$ExportOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Data = Join-Path $script:Root 'data'
if (-not (Test-Path -LiteralPath $script:Data)) {
    New-Item -ItemType Directory -Path $script:Data | Out-Null
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

function Get-ExternalConnections {
    param([hashtable]$ProcessMap)

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
        $result += [pscustomobject]@{
            App = if ($proc) { $proc.Name } else { 'Unbekannt' }
            Pid = $pidValue
            Target = $address
            Port = $port
            Path = if ($proc) { $proc.Path } else { '' }
            Status = 'Erlaubt'
            Risk = 0
            Reason = 'Aktive externe Verbindung'
        }
    }
    return @($result)
}

function Get-StartupEntries {
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
                $result += [pscustomobject]@{
                    Name = [string]$property.Name
                    Command = $command
                    Location = $location
                    Suspicious = (Test-SuspiciousPath $command)
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
            $result += [pscustomobject]@{
                Name = $file.BaseName
                Command = $file.FullName
                Location = $folder
                Suspicious = (Test-SuspiciousPath $file.FullName)
            }
        }
    }
    return @($result)
}

function Get-Findings {
    param([object[]]$Connections, [object[]]$StartupEntries)

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

    foreach ($entry in $StartupEntries | Where-Object { $_.Suspicious }) {
        $result += [pscustomobject]@{
            App = $entry.Name
            Score = 5
            Level = 'Verdaechtig'
            Summary = "$($entry.Name): Autostart aus einem ungewoehnlichen Ordner."
            Detail = $entry.Command
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

    return @($result | Sort-Object Score -Descending | Select-Object -First 8)
}

function Get-Snapshot {
    $started = Get-Date
    $processes = Get-ProcessMap
    $connections = @(Get-ExternalConnections -ProcessMap $processes)
    $startups = @(Get-StartupEntries)
    $findings = @(Get-Findings -Connections $connections -StartupEntries $startups)

    foreach ($connection in $connections) {
        $finding = $findings | Where-Object { $_.App -eq $connection.App -and $_.Score -gt 0 } | Select-Object -First 1
        if ($finding) {
            $connection.Risk = [int]$finding.Score
            $connection.Status = [string]$finding.Level
            $connection.Reason = [string]$finding.Summary
        }
    }

    $snapshot = [pscustomobject]@{
        Product = 'TrackerRadar Alpha'
        Version = '0.2.2-alpha'
        Timestamp = (Get-Date).ToString('o')
        DurationMs = [int]((Get-Date) - $started).TotalMilliseconds
        ExternalConnections = $connections.Count
        ActiveApps = @($connections | Select-Object -ExpandProperty Pid -Unique).Count
        StartupEntries = $startups.Count
        FindingCount = @($findings | Where-Object { $_.Score -gt 0 }).Count
        CriticalCount = @($findings | Where-Object { $_.Score -ge 7 }).Count
        Activities = @($connections | Sort-Object @{Expression='Risk';Descending=$true}, @{Expression='App';Descending=$false} | Select-Object -First 25)
        Findings = $findings
        Startup = $startups
        Limitations = @(
            'Momentaufnahme aktiver externer TCP-Verbindungen',
            'Keine Entschluesselung von HTTPS-Inhalten',
            'Datei-Lesezugriffe werden in dieser Alpha noch nicht vollstaendig erfasst'
        )
    }

    $snapshot | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $script:Data 'latest-scan.json') -Encoding UTF8
    return $snapshot
}

function Invoke-SelfTest {
    $checks = @()
    $checks += [pscustomobject]@{ Name='PowerShell'; Passed=($PSVersionTable.PSVersion.Major -ge 5); Detail=$PSVersionTable.PSVersion.ToString() }
    $checks += [pscustomobject]@{ Name='netstat'; Passed=[bool](Get-Command netstat.exe -ErrorAction SilentlyContinue); Detail='Windows-Netzwerkerfassung' }
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $checks += [pscustomobject]@{ Name='WPF'; Passed=$true; Detail='PresentationFramework geladen' }
    } catch {
        $checks += [pscustomobject]@{ Name='WPF'; Passed=$false; Detail=$_.Exception.Message }
    }
    try {
        $snapshot = Get-Snapshot
        $checks += [pscustomobject]@{ Name='Live-Snapshot'; Passed=$true; Detail="$($snapshot.ExternalConnections) Verbindung(en), $($snapshot.DurationMs) ms" }
        $checks += [pscustomobject]@{ Name='Bericht'; Passed=(Test-Path -LiteralPath (Join-Path $script:Data 'latest-scan.json')); Detail=(Join-Path $script:Data 'latest-scan.json') }
    } catch {
        $checks += [pscustomobject]@{ Name='Live-Snapshot'; Passed=$false; Detail=$_.Exception.Message }
    }
    $result = [pscustomobject]@{
        Product='TrackerRadar Alpha'
        Timestamp=(Get-Date).ToString('o')
        Passed=@($checks | Where-Object { $_.Passed }).Count
        Failed=@($checks | Where-Object { -not $_.Passed }).Count
        Checks=$checks
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:Data 'self-test.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 5
    if ($result.Failed -gt 0) { exit 1 }
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if ($ExportOnly) {
    Get-Snapshot | ConvertTo-Json -Depth 7
    exit 0
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TrackerRadar 0.2.2 Alpha | SC LABS" Width="1180" Height="720" MinWidth="960" MinHeight="620"
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
                        <Border x:Name="ButtonChrome"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="11"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonChrome" Property="Background" Value="#174A47"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ButtonChrome" Property="Background" Value="#0D2E2C"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonChrome" Property="Opacity" Value="0.55"/>
                            </Trigger>
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
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#112731"/>
            <Setter Property="Foreground" Value="#92A8B4"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="BorderBrush" Value="#1B3442"/>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="9,7"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="205"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border Grid.Column="0" Background="#08141D" BorderBrush="#18303D" BorderThickness="0,0,1,0">
            <Grid Margin="20">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel>
                    <StackPanel Orientation="Horizontal">
                        <Border Width="44" Height="44" CornerRadius="9" Background="#0B1924" BorderBrush="#284657" BorderThickness="1" Padding="3">
                            <Image x:Name="ScLabsLogo" Stretch="Uniform"/>
                        </Border>
                        <StackPanel Margin="10,6,0,0">
                            <TextBlock Text="SC LABS" FontSize="16" FontWeight="Bold" Foreground="#ECF3F7"/>
                            <TextBlock Text="PRODUCT SERIES" FontSize="9" Foreground="#718B99"/>
                        </StackPanel>
                    </StackPanel>
                    <Border Margin="0,22,0,0" Height="132" CornerRadius="12" Background="#06101A" BorderBrush="#234455" BorderThickness="1" Padding="0" ClipToBounds="True">
                        <Image x:Name="TrackerRadarLogo" Stretch="Uniform" Margin="0"/>
                    </Border>
                    <TextBlock Text="Sieh, was Programme wirklich tun." Margin="0,10,0,0" Foreground="#8EA2AF" TextWrapping="Wrap"/>
                </StackPanel>
                <StackPanel Grid.Row="1" Margin="0,34,0,0">
                    <Border Background="#102630" CornerRadius="10" Padding="12">
                        <TextBlock Text="Uebersicht" FontWeight="SemiBold" Foreground="{StaticResource Accent}"/>
                    </Border>
                    <TextBlock Text="Aktivitaeten" Margin="12,20,0,0" Foreground="#AABAC4"/>
                    <TextBlock Text="Befunde" Margin="12,18,0,0" Foreground="#AABAC4"/>
                    <TextBlock Text="Verlauf" Margin="12,18,0,0" Foreground="#AABAC4"/>
                </StackPanel>
                <Border Grid.Row="3" Background="#0E211D" BorderBrush="#1C523F" BorderThickness="1" CornerRadius="12" Padding="13">
                    <StackPanel>
                        <TextBlock Text="LOKAL UND PRIVAT" Foreground="{StaticResource Green}" FontWeight="SemiBold"/>
                        <TextBlock Text="Keine Cloud. Keine Telemetrie." Foreground="#8FA8A0" Margin="0,5,0,0" FontSize="12"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <Grid Grid.Column="1" Margin="27,21,27,18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock x:Name="Headline" Text="Dein System wird beobachtet." FontSize="27" FontWeight="SemiBold"/>
                    <TextBlock Text="Read-only: TrackerRadar veraendert nichts." Foreground="#91A5B2" Margin="0,5,0,0"/>
                </StackPanel>
                <Button x:Name="ScanButton" Grid.Column="1" Content="Jetzt pruefen" MinWidth="130" Height="60"/>
            </Grid>

            <Grid Grid.Row="1" Margin="0,22,0,18">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/><ColumnDefinition Width="14"/>
                    <ColumnDefinition Width="*"/><ColumnDefinition Width="14"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17">
                    <StackPanel><TextBlock Text="Internetaktive Apps" Foreground="#92A6B2"/><TextBlock x:Name="AppsCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Accent}" Margin="0,4,0,0"/></StackPanel>
                </Border>
                <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17">
                    <StackPanel><TextBlock Text="Zu pruefen" Foreground="#92A6B2"/><TextBlock x:Name="FindingsCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Amber}" Margin="0,4,0,0"/></StackPanel>
                </Border>
                <Border Grid.Column="4" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" Padding="17">
                    <StackPanel><TextBlock Text="Kritisch" Foreground="#92A6B2"/><TextBlock x:Name="CriticalCount" Text="-" FontSize="29" FontWeight="SemiBold" Foreground="{StaticResource Red}" Margin="0,4,0,0"/></StackPanel>
                </Border>
            </Grid>

            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions><ColumnDefinition Width="1.55*"/><ColumnDefinition Width="17"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
                <Border Grid.Column="0" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11">
                            <TextBlock Text="Aktive Internetverbindungen" FontSize="18" FontWeight="SemiBold"/>
                            <TextBlock Text="Aktuelle externe TCP-Verbindungen" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/>
                        </StackPanel>
                        <DataGrid x:Name="ActivityGrid" Grid.Row="1" AlternationCount="2">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="APP" Binding="{Binding App}" Width="1.2*"/>
                                <DataGridTextColumn Header="ZIEL" Binding="{Binding Target}" Width="1.5*"/>
                                <DataGridTextColumn Header="PORT" Binding="{Binding Port}" Width="65"/>
                                <DataGridTextColumn Header="STATUS" Binding="{Binding Status}" Width="95"/>
                            </DataGrid.Columns>
                        </DataGrid>
                    </Grid>
                </Border>
                <Border Grid.Column="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <StackPanel Margin="17,14,17,11">
                            <TextBlock Text="Wichtigste Befunde" FontSize="18" FontWeight="SemiBold"/>
                            <TextBlock Text="Gebuedelt statt Warnungsflut" Foreground="#8399A6" FontSize="12" Margin="0,3,0,0"/>
                        </StackPanel>
                        <ListBox x:Name="FindingsList" Grid.Row="1" Background="Transparent" BorderThickness="0" Foreground="#ECF3F7" DisplayMemberPath="Summary" Padding="10"/>
                        <Button x:Name="ReportButton" Grid.Row="2" Content="Lokalen Bericht oeffnen" Margin="15"/>
                    </Grid>
                </Border>
            </Grid>

            <Grid Grid.Row="3" Margin="0,13,0,0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <TextBlock x:Name="StatusText" Text="Bereit" Foreground="#8DA1AD"/>
                <TextBlock Grid.Column="1" Text="TrackerRadar 0.2.2 Alpha · SC LABS" Foreground="#627985"/>
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
$activityGrid = $window.FindName('ActivityGrid')
$findingsList = $window.FindName('FindingsList')
$appsCount = $window.FindName('AppsCount')
$findingsCount = $window.FindName('FindingsCount')
$criticalCount = $window.FindName('CriticalCount')
$statusText = $window.FindName('StatusText')
$headline = $window.FindName('Headline')
$scLabsLogo = $window.FindName('ScLabsLogo')
$trackerRadarLogo = $window.FindName('TrackerRadarLogo')

function Set-UiImage {
    param(
        [Parameter(Mandatory)]$Control,
        [Parameter(Mandatory)][string]$Path
    )
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

function Update-Ui {
    try {
        $scanButton.IsEnabled = $false
        $scanButton.Content = 'Pruefe ...'
        $statusText.Text = 'Lokale Auswertung laeuft ...'
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        $window.Dispatcher.Invoke([action]{}, 'Background')

        $snapshot = Get-Snapshot
        $activityGrid.ItemsSource = @($snapshot.Activities)
        $findingsList.ItemsSource = @($snapshot.Findings)
        $appsCount.Text = [string]$snapshot.ActiveApps
        $findingsCount.Text = [string]$snapshot.FindingCount
        $criticalCount.Text = [string]$snapshot.CriticalCount
        if ($snapshot.CriticalCount -gt 0) {
            $headline.Text = 'Eine Aktivitaet braucht deine Aufmerksamkeit.'
        } elseif ($snapshot.FindingCount -gt 0) {
            $headline.Text = 'Einige Aktivitaeten solltest du pruefen.'
        } else {
            $headline.Text = 'Aktuell nichts Auffaelliges erkannt.'
        }
        $statusText.Text = "Letzte Pruefung: $(Get-Date -Format 'HH:mm:ss') | $($snapshot.ExternalConnections) Verbindung(en) | $($snapshot.DurationMs) ms"
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

$scanButton.Add_Click({ Update-Ui })
$reportButton.Add_Click({
    $report = Join-Path $script:Data 'latest-scan.json'
    if (Test-Path -LiteralPath $report) { Start-Process explorer.exe -ArgumentList @('/select,', $report) }
})
$activityGrid.Add_MouseDoubleClick({
    $item = $activityGrid.SelectedItem
    if ($item) {
        $text = "App: $($item.App)`nPID: $($item.Pid)`nZiel: $($item.Target):$($item.Port)`nPfad: $($item.Path)`nStatus: $($item.Status)`n`n$($item.Reason)"
        [System.Windows.MessageBox]::Show($text, 'Aktivitaetsdetails', 'OK', 'Information') | Out-Null
    }
})
$findingsList.Add_MouseDoubleClick({
    $item = $findingsList.SelectedItem
    if ($item) { [System.Windows.MessageBox]::Show("$($item.Summary)`n`n$($item.Detail)", 'Befunddetails', 'OK', 'Warning') | Out-Null }
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(20)
$timer.Add_Tick({ Update-Ui })
$window.Add_ContentRendered({ Update-Ui; $timer.Start() })
$window.Add_Closed({ $timer.Stop() })
[void]$window.ShowDialog()
