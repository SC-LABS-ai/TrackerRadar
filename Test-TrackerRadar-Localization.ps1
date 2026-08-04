$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$module = Join-Path $root 'TrackerRadar.Localization.ps1'
$dePath = Join-Path $root 'locales\de.json'
$enPath = Join-Path $root 'locales\en.json'
$testData = Join-Path $root 'data\localization-selftest'
if (Test-Path -LiteralPath $testData) { Remove-Item -LiteralPath $testData -Recurse -Force }
New-Item -ItemType Directory -Path $testData -Force | Out-Null

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop) } catch { return $null }
}
function Write-JsonFile {
    param([string]$Path,$Value,[int]$Depth=8)
    [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth $Depth),(New-Object Text.UTF8Encoding($false)))
}

$checks = @()
try {
    $checks += [pscustomobject]@{ Name='LocalizationModule'; Passed=(Test-Path -LiteralPath $module -PathType Leaf); Detail=$module }
    $checks += [pscustomobject]@{ Name='GermanLocale'; Passed=(Test-Path -LiteralPath $dePath -PathType Leaf); Detail=$dePath }
    $checks += [pscustomobject]@{ Name='EnglishLocale'; Passed=(Test-Path -LiteralPath $enPath -PathType Leaf); Detail=$enPath }
    if (-not (@($checks | Where-Object { -not $_.Passed }).Count -eq 0)) { throw 'Localization files are incomplete.' }

    $de = Read-JsonFile $dePath
    $en = Read-JsonFile $enPath
    $deKeys = @($de.PSObject.Properties.Name | Sort-Object)
    $enKeys = @($en.PSObject.Properties.Name | Sort-Object)
    $checks += [pscustomobject]@{ Name='ParallelKeys'; Passed=(($deKeys -join '|') -eq ($enKeys -join '|')); Detail="$($deKeys.Count) German / $($enKeys.Count) English" }
    $checks += [pscustomobject]@{ Name='GermanUnicode'; Passed=(([int][char]([string]$de.NavOverview)[0] -eq 220) -and ([int][char]([string]$de.NavChanges)[0] -eq 196)); Detail='Übersicht / Änderungen' }

    . $module
    Initialize-TrackerRadarLocalization -Root $root -Data $testData
    $checks += [pscustomobject]@{ Name='GermanDefault'; Passed=($script:Language -eq 'de' -and [int][char](Get-Text 'NavOverview')[0] -eq 220); Detail=(Get-Text 'NavOverview') }
    Set-TrackerRadarLanguage -Language en -Save $true
    Initialize-TrackerRadarLocalization -Root $root -Data $testData
    $checks += [pscustomobject]@{ Name='EnglishPersistence'; Passed=($script:Language -eq 'en' -and (Get-Text 'NavOverview') -eq 'Overview'); Detail=(Get-Text 'NavOverview') }
    $checks += [pscustomobject]@{ Name='DisplayTranslation'; Passed=((Convert-DisplayText 'Unbekannter Dienst') -eq 'Unknown service'); Detail=(Convert-DisplayText 'Unbekannter Dienst') }
} finally {
    Remove-Item -LiteralPath $testData -Recurse -Force -ErrorAction SilentlyContinue
}

$result = [pscustomobject]@{
    Product='TrackerRadar Localization'
    Version='0.5.1-alpha'
    Passed=@($checks | Where-Object { $_.Passed }).Count
    Failed=@($checks | Where-Object { -not $_.Passed }).Count
    Checks=$checks
}
$result | ConvertTo-Json -Depth 6
if ($result.Failed -gt 0) { exit 1 }
