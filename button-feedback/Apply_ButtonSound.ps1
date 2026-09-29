param([string]$ProjectPath = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Test-Project([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ((Test-Path -LiteralPath (Join-Path $Path 'settings.gradle') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/index.html') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/game.js') -PathType Leaf))
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    foreach ($candidate in @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), 'C:\BattleZone\BattleZone_AndroidStudio')) {
        if (Test-Project $candidate) { $ProjectPath = $candidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Host 'Android Studio project folder (the folder containing settings.gradle):'
        $ProjectPath = Read-Host
    }
}
$ProjectPath = $ProjectPath.Trim().Trim('"')
if (-not (Test-Project $ProjectPath)) {
    throw 'Project not found. Select the BattleZone_AndroidStudio folder containing app and settings.gradle. Nothing was changed.'
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$Web = Join-Path $ProjectPath 'app/src/main/assets/web'
$Index = Join-Path $Web 'index.html'
$Game = Join-Path $Web 'game.js'
$Source = Join-Path $PSScriptRoot 'ui-button-sound.js'
$Target = Join-Path $Web 'ui-button-sound.js'
$Marker = 'BattleZone button confirmation audio (isolated add-on)'
$Utf8 = New-Object System.Text.UTF8Encoding($false, $true)
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw 'Extract the entire update ZIP first. ui-button-sound.js is missing.' }
$NewScript = [IO.File]::ReadAllBytes($Source)
$ScriptText = $Utf8.GetString($NewScript)
if (-not $ScriptText.Contains($Marker)) { throw 'Invalid update file. Nothing was changed.' }
$OriginalBytes = [IO.File]::ReadAllBytes($Index)
$OriginalHash = Hash $Index
$Html = $Utf8.GetString($OriginalBytes)
$GameText = [IO.File]::ReadAllText($Game)
if (-not $Html.Contains('id="stage"') -or -not $GameText.Contains('BattleZoneInput') -or -not $GameText.Contains('startGameButton')) {
    throw 'This is not the expected BattleZone project. Nothing was changed.'
}
$HasTag = $Html.Contains('id="bz-button-feedback"')
if ($HasTag -and (Test-Path -LiteralPath $Target)) {
    if ((Hash $Target) -eq (Hash $Source)) {
        Write-Host 'ALREADY APPLIED - button sound is already installed.' -ForegroundColor Green
        Write-Host ('Project: ' + $ProjectPath)
        Write-Host 'Next: rebuild with gradlew.bat :app:assembleDebug'
        exit 0
    }
}
if ((Test-Path -LiteralPath $Target) -and -not ([IO.File]::ReadAllText($Target).Contains($Marker))) {
    throw 'A different ui-button-sound.js already exists. Nothing was changed.'
}
if (-not $HasTag) {
    $Matches = [regex]::Matches($Html, '(?i)</body\s*>')
    if ($Matches.Count -ne 1) { throw 'Unexpected index.html structure. Nothing was changed.' }
    $NewLine = if ($Html.Contains("`r`n")) { "`r`n" } else { "`n" }
    $Tag = '<script id="bz-button-feedback" src="ui-button-sound.js"></script>' + $NewLine
    $Html = $Html.Insert($Matches[0].Index, $Tag)
}
$NewIndexBytes = $Utf8.GetBytes($Html)
$Protected = @{}
Get-ChildItem -LiteralPath $Web -File -Recurse | Where-Object { $_.FullName -ne $Index -and $_.FullName -ne $Target } | ForEach-Object {
    $Protected[$_.FullName] = Hash $_.FullName
}
$Stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
$Backup = Join-Path $ProjectPath ('.button-sound-backups/' + $Stamp)
New-Item -ItemType Directory -Path $Backup -Force | Out-Null
[IO.File]::WriteAllBytes((Join-Path $Backup 'index.html'), $OriginalBytes)
$HadScript = Test-Path -LiteralPath $Target -PathType Leaf
if ($HadScript) { Copy-Item -LiteralPath $Target -Destination (Join-Path $Backup 'ui-button-sound.js') }
$IndexTemp = $Index + '.' + $Stamp + '.tmp'
$ScriptTemp = $Target + '.' + $Stamp + '.tmp'
$IndexWritten = $false
$ScriptWritten = $false
try {
    [IO.File]::WriteAllBytes($IndexTemp, $NewIndexBytes)
    [IO.File]::WriteAllBytes($ScriptTemp, $NewScript)
    if ((Hash $Index) -ne $OriginalHash) { throw 'index.html changed while updating. Please close the editor and retry.' }
    if ($HadScript) { [IO.File]::Replace($ScriptTemp, $Target, $null) } else { [IO.File]::Move($ScriptTemp, $Target) }
    $ScriptWritten = $true
    [IO.File]::Replace($IndexTemp, $Index, $null)
    $IndexWritten = $true
    foreach ($Path in $Protected.Keys) {
        if ((Hash $Path) -ne $Protected[$Path]) { throw 'Another original web file changed during installation. Update rolled back.' }
    }
    if ((Hash $Target) -ne (Hash $Source)) { throw 'Update verification failed.' }
} catch {
    if ($IndexWritten) { [IO.File]::WriteAllBytes($Index, $OriginalBytes) }
    if ($ScriptWritten) {
        if ($HadScript) { Copy-Item -LiteralPath (Join-Path $Backup 'ui-button-sound.js') -Destination $Target -Force }
        else { Remove-Item -LiteralPath $Target -ErrorAction SilentlyContinue }
    }
    throw
} finally {
    Remove-Item -LiteralPath $IndexTemp, $ScriptTemp -ErrorAction SilentlyContinue
}
Write-Host ''
Write-Host 'APPLIED - button confirmation sound added.' -ForegroundColor Green
Write-Host ('Project: ' + $ProjectPath)
Write-Host ('Original backup: ' + $Backup)
Write-Host 'Game logic, graphics, voices, effects, Gradle and signing settings were not replaced.'
Write-Host ''
Write-Host 'Next: rebuild with gradlew.bat :app:assembleDebug'
