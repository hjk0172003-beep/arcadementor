param([string]$ProjectPath = '', [string]$MusicPath = '', [switch]$NonInteractive)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$Utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Is-Project([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ((Test-Path -LiteralPath (Join-Path $Path 'settings.gradle') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/index.html') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/game.js') -PathType Leaf))
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Pick-Project {
    if ($NonInteractive) { throw 'Project path is required.' }
    Add-Type -AssemblyName System.Windows.Forms
    $Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $Dialog.Description = 'Select BattleZone_AndroidStudio (the folder containing app and settings.gradle).'
    $Dialog.ShowNewFolderButton = $false
    try {
        if ($Dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return '' }
        return $Dialog.SelectedPath
    } finally { $Dialog.Dispose() }
}
function Pick-Music {
    if ($NonInteractive) { throw 'WAV music file is required.' }
    Add-Type -AssemblyName System.Windows.Forms
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    $Dialog.Title = 'Select Majestic_Modern_Electronic_Power_BGM.wav'
    $Dialog.Filter = 'WAV music (*.wav)|*.wav'
    $Dialog.FileName = 'Majestic_Modern_Electronic_Power_BGM.wav'
    $Dialog.CheckFileExists = $true
    try {
        if ($Dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return '' }
        return $Dialog.FileName
    } finally { $Dialog.Dispose() }
}

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    foreach ($Candidate in @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), 'C:\BattleZone\BattleZone_AndroidStudio')) {
        if (Is-Project $Candidate) { $ProjectPath = $Candidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = Pick-Project }
}
if ([string]::IsNullOrWhiteSpace($ProjectPath)) { Write-Host 'CANCELLED - nothing changed.'; return }
$ProjectPath = $ProjectPath.Trim().Trim('"')
if (-not (Is-Project $ProjectPath)) { throw 'Not a BattleZone Android Studio project. Nothing changed.' }
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$Web = Join-Path $ProjectPath 'app/src/main/assets/web'
$Index = Join-Path $Web 'index.html'
$TargetScript = Join-Path $Web 'bz-menu-music.js'
$TargetMusic = Join-Path $Web 'bz-menu-music.wav'
$SourceScript = Join-Path $PSScriptRoot 'bz-menu-music.js'
if (-not (Test-Path -LiteralPath $SourceScript -PathType Leaf)) { throw 'Extract the ENTIRE update ZIP first. bz-menu-music.js is missing.' }
$ScriptBytes = [IO.File]::ReadAllBytes($SourceScript)
if (-not $Utf8.GetString($ScriptBytes).Contains('BATTLEZONE_MENU_MUSIC_V2')) { throw 'Unexpected update script. Nothing changed.' }
$OriginalBytes = [IO.File]::ReadAllBytes($Index)
$OriginalHash = Hash $Index
$Html = $Utf8.GetString($OriginalBytes)
$Game = [IO.File]::ReadAllText((Join-Path $Web 'game.js'))
if (-not $Html.Contains('id="setup"') -or -not $Html.Contains('id="range"') -or
    -not $Html.Contains('setupHeader') -or -not $Game.Contains('BattleZoneInput') -or -not $Game.Contains('startGameButton')) {
    throw 'Unexpected game structure. Nothing changed.'
}
$ScriptExisted = Test-Path -LiteralPath $TargetScript -PathType Leaf
if ($ScriptExisted -and -not ([IO.File]::ReadAllText($TargetScript) -match 'BATTLEZONE_MENU_MUSIC_V[12]')) {
    throw 'A different bz-menu-music.js already exists. It was NOT overwritten.'
}
if (-not $ScriptExisted -and (Test-Path -LiteralPath $TargetMusic)) { throw 'A different bz-menu-music.wav already exists. It was NOT overwritten.' }
$Tag = '<script id="bz-menu-music-script" src="bz-menu-music.js"></script>'
$HasTag = $Html.Contains($Tag)
if (-not $HasTag -and $Html.Contains('bz-menu-music')) { throw 'Unknown existing BGM integration. Nothing changed.' }
if ([regex]::Matches($Html, '(?i)</body\s*>').Count -ne 1) { throw 'Unexpected HTML structure. Nothing changed.' }

if ([string]::IsNullOrWhiteSpace($MusicPath)) {
    $Name = 'Majestic_Modern_Electronic_Power_BGM.wav'
    $Candidates = @((Join-Path $PSScriptRoot $Name), (Join-Path (Split-Path $PSScriptRoot -Parent) $Name), (Join-Path $env:USERPROFILE ('Downloads/'+$Name)))
    if ($ScriptExisted) { $Candidates += $TargetMusic }
    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) { $MusicPath = $Candidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($MusicPath)) { $MusicPath = Pick-Music }
}
if ([string]::IsNullOrWhiteSpace($MusicPath)) { Write-Host 'CANCELLED - nothing changed.'; return }
$MusicPath = $MusicPath.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $MusicPath -PathType Leaf)) { throw 'WAV music not found. Nothing changed.' }
if ((Get-Item -LiteralPath $MusicPath).Length -gt 536870912) { throw 'Music is too large. Nothing changed.' }
$MusicBytes = [IO.File]::ReadAllBytes($MusicPath)
if ($MusicBytes.Length -lt 44 -or [Text.Encoding]::ASCII.GetString($MusicBytes,0,4) -ne 'RIFF' -or [Text.Encoding]::ASCII.GetString($MusicBytes,8,4) -ne 'WAVE') {
    throw 'Select the original WAV music file. Nothing changed.'
}
$MusicHash = Hash $MusicPath
if ($HasTag -and $ScriptExisted -and (Test-Path -LiteralPath $TargetMusic) -and (Hash $TargetScript) -eq (Hash $SourceScript) -and (Hash $TargetMusic) -eq $MusicHash) {
    Write-Host 'ALREADY APPLIED - rebuild the APK.' -ForegroundColor Green
    return
}
if (-not $HasTag) {
    $Match = [regex]::Match($Html, '(?i)</body\s*>')
    $NewLine = if ($Html.Contains("`r`n")) { "`r`n" } else { "`n" }
    $Html = $Html.Insert($Match.Index, $Tag+$NewLine)
}
$NewIndexBytes = $Utf8.GetBytes($Html)
$Protected = @{}
Get-ChildItem -LiteralPath $Web -File -Recurse | ForEach-Object {
    if ($_.FullName -notin @($Index,$TargetScript,$TargetMusic)) { $Protected[$_.FullName] = Hash $_.FullName }
}
$Stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
$Backup = Join-Path $ProjectPath ('.menu-bgm-backups/'+$Stamp)
New-Item -ItemType Directory -Path $Backup -Force | Out-Null
$Plan = @(
    @{Path=$TargetMusic;Bytes=$MusicBytes},
    @{Path=$TargetScript;Bytes=$ScriptBytes},
    @{Path=$Index;Bytes=$NewIndexBytes}
)
$Written = New-Object 'System.Collections.Generic.List[object]'
foreach ($Item in $Plan) {
    $Item.Existed = Test-Path -LiteralPath $Item.Path -PathType Leaf
    $Item.Backup = Join-Path $Backup ([IO.Path]::GetFileName($Item.Path))
    $Item.Temp = $Item.Path+'.'+$Stamp+'.tmp'
    if ($Item.Existed) { Copy-Item -LiteralPath $Item.Path -Destination $Item.Backup }
}
try {
    foreach ($Item in $Plan) { [IO.File]::WriteAllBytes($Item.Temp, $Item.Bytes) }
    if ((Hash $Index) -ne $OriginalHash) { throw 'index.html changed during installation. Close the editor and retry.' }
    foreach ($Item in $Plan) {
        if ($Item.Existed) {
            $AtomicBackup = $Item.Backup+'.atomic'
            [IO.File]::Replace($Item.Temp,$Item.Path,$AtomicBackup)
        } else { [IO.File]::Move($Item.Temp,$Item.Path) }
        $Written.Add($Item)
    }
    foreach ($Path in $Protected.Keys) { if ((Hash $Path) -ne $Protected[$Path]) { throw 'Another original file changed during installation.' } }
    if ((Hash $TargetMusic) -ne $MusicHash -or (Hash $TargetScript) -ne (Hash $SourceScript)) { throw 'Verification failed.' }
} catch {
    foreach ($Item in $Written) {
        if ($Item.Existed) { Copy-Item -LiteralPath $Item.Backup -Destination $Item.Path -Force }
        else { Remove-Item -LiteralPath $Item.Path -ErrorAction SilentlyContinue }
    }
    throw
} finally {
    foreach ($Item in $Plan) { Remove-Item -LiteralPath $Item.Temp -ErrorAction SilentlyContinue }
}
Write-Host ''
Write-Host 'APPLIED - menu-only BGM and ON/OFF added.' -ForegroundColor Green
Write-Host ('Original files backed up: '+$Backup)
Write-Host 'game.js, target input, timers, score, voice, start beep and signing settings were NOT replaced.'
Write-Host 'Next: run BUILD_DEBUG_APK.cmd in your existing project.'
