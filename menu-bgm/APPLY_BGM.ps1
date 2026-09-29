param([string]$ProjectPath = '', [string]$MusicPath = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Test-Project([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ((Test-Path -LiteralPath (Join-Path $Path 'settings.gradle') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/index.html') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/game.js') -PathType Leaf))
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
$Utf8 = New-Object System.Text.UTF8Encoding($false, $true)
$SourceScript = Join-Path $PSScriptRoot 'menu-bgm.js'
if (-not (Test-Path -LiteralPath $SourceScript -PathType Leaf)) { throw 'Extract the entire update ZIP first. menu-bgm.js is missing. Nothing was changed.' }
if (-not ([IO.File]::ReadAllText($SourceScript).Contains('BattleZone menu-only BGM (isolated add-on'))) { throw 'Invalid update script. Nothing was changed.' }
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    foreach ($Candidate in @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), 'C:\BattleZone\BattleZone_AndroidStudio')) {
        if (Test-Project $Candidate) { $ProjectPath = $Candidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Host 'Enter the project folder containing app, gradlew.bat and settings.gradle:'
        $ProjectPath = Read-Host
    }
}
$ProjectPath = $ProjectPath.Trim().Trim('"')
if (-not (Test-Project $ProjectPath)) { throw 'BattleZone Android Studio project was not found. Nothing was changed.' }
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$Web = Join-Path $ProjectPath 'app/src/main/assets/web'
$Index = Join-Path $Web 'index.html'
$Game = Join-Path $Web 'game.js'
$TargetScript = Join-Path $Web 'menu-bgm.js'
$TargetMusic = Join-Path $Web 'mode-selection-bgm.wav'
$OriginalIndexBytes = [IO.File]::ReadAllBytes($Index)
$OriginalIndexHash = Hash $Index
$Html = $Utf8.GetString($OriginalIndexBytes)
$GameText = [IO.File]::ReadAllText($Game)
foreach ($Id in @('setup','range','modal','enterRange','startGameButton')) {
    if (-not $Html.Contains('id="'+$Id+'"')) { throw ('Unsupported project structure: '+$Id+'. Nothing was changed.') }
}
if (-not $Html.Contains('setupHeader') -or -not $GameText.Contains('BattleZoneInput')) { throw 'This is not the expected BattleZone project. Nothing was changed.' }
$ScriptMarker = 'BattleZone menu-only BGM (isolated add-on'
if ((Test-Path -LiteralPath $TargetScript) -and -not ([IO.File]::ReadAllText($TargetScript).Contains($ScriptMarker))) {
    throw 'An unrelated menu-bgm.js file already exists. Nothing was changed.'
}
$Tag = '<script id="bz-menu-bgm" src="menu-bgm.js"></script>'
$TagCount = [regex]::Matches($Html, 'id="bz-menu-bgm"').Count
if ($TagCount -gt 1 -or ($TagCount -eq 1 -and -not $Html.Contains($Tag))) { throw 'Unrecognized BGM installation. Nothing was changed.' }
if ($TagCount -eq 0 -and (Test-Path -LiteralPath $TargetMusic)) { throw 'An unrelated mode-selection-bgm.wav already exists. Nothing was changed.' }
if ($TagCount -eq 0) {
    $Ends = [regex]::Matches($Html, '(?i)</body\s*>')
    if ($Ends.Count -ne 1) { throw 'Unexpected HTML structure. Nothing was changed.' }
    $Newline = if ($Html.Contains("`r`n")) { "`r`n" } else { "`n" }
    $Html = $Html.Insert($Ends[0].Index, $Tag + $Newline)
}
$OriginalMusicName = 'Majestic_Modern_Electronic_Power_BGM.wav'
if ([string]::IsNullOrWhiteSpace($MusicPath)) {
    $Candidates = @((Join-Path $PSScriptRoot $OriginalMusicName), (Join-Path $env:USERPROFILE ('Downloads/'+$OriginalMusicName)), (Join-Path $env:USERPROFILE ('Desktop/'+$OriginalMusicName)))
    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) { $MusicPath = $Candidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($MusicPath)) {
        Add-Type -AssemblyName System.Windows.Forms
        $Dialog = New-Object System.Windows.Forms.OpenFileDialog
        $Dialog.Title = 'Select the background music WAV you supplied'
        $Dialog.Filter = 'WAV audio (*.wav)|*.wav'
        $Dialog.FileName = $OriginalMusicName
        if ($Dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { $Dialog.Dispose(); Write-Host 'CANCELLED - nothing was changed.'; exit 2 }
        $MusicPath = $Dialog.FileName
        $Dialog.Dispose()
    }
}
$MusicPath = $MusicPath.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $MusicPath -PathType Leaf)) { throw 'The background music file was not found. Nothing was changed.' }
$MusicPath = (Resolve-Path -LiteralPath $MusicPath).Path
$Stream = [IO.File]::OpenRead($MusicPath)
try {
    $Header = New-Object byte[] 12
    if ($Stream.Length -lt 44 -or $Stream.Read($Header,0,12) -ne 12 -or
        [Text.Encoding]::ASCII.GetString($Header,8,4) -ne 'WAVE' -or
        @('RIFF','RF64') -notcontains [Text.Encoding]::ASCII.GetString($Header,0,4)) { throw 'Please select a valid WAV file. Nothing was changed.' }
} finally { $Stream.Dispose() }
$MusicHash = Hash $MusicPath
$ScriptHash = Hash $SourceScript
if ($TagCount -eq 1 -and (Test-Path -LiteralPath $TargetScript) -and (Test-Path -LiteralPath $TargetMusic)) {
    if ((Hash $TargetScript) -eq $ScriptHash -and (Hash $TargetMusic) -eq $MusicHash) {
        Write-Host 'ALREADY APPLIED - rebuild the APK from your existing project.' -ForegroundColor Green
        exit 0
    }
}
$Protected = @{}
Get-ChildItem -LiteralPath $Web -File -Recurse | Where-Object { $_.FullName -ne $Index -and $_.FullName -ne $TargetScript -and $_.FullName -ne $TargetMusic } | ForEach-Object { $Protected[$_.FullName] = Hash $_.FullName }
$Stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$Backup = Join-Path $ProjectPath ('.bgm-backups/'+$Stamp)
New-Item -ItemType Directory -Path $Backup -Force | Out-Null
$Changes = @(
    @{Path=$TargetMusic; Source=$MusicPath; Bytes=$null; Applied=$false},
    @{Path=$TargetScript; Source=$SourceScript; Bytes=$null; Applied=$false},
    @{Path=$Index; Source=$null; Bytes=$Utf8.GetBytes($Html); Applied=$false}
)
foreach ($Change in $Changes) {
    $Change.HadFile = Test-Path -LiteralPath $Change.Path -PathType Leaf
    $Change.Temp = $Change.Path + '.' + $Stamp + '.tmp'
    $Change.Backup = Join-Path $Backup ([IO.Path]::GetFileName($Change.Path))
    if ($Change.HadFile) { Copy-Item -LiteralPath $Change.Path -Destination $Change.Backup; $Change.OldHash = Hash $Change.Path }
}
try {
    foreach ($Change in $Changes) {
        if ($null -ne $Change.Bytes) { [IO.File]::WriteAllBytes($Change.Temp, $Change.Bytes) }
        else { Copy-Item -LiteralPath $Change.Source -Destination $Change.Temp }
    }
    if ((Hash $Index) -ne $OriginalIndexHash -or (Hash $Changes[0].Temp) -ne $MusicHash -or (Hash $Changes[1].Temp) -ne $ScriptHash) { throw 'Files changed during update. Nothing was installed.' }
    foreach ($Change in $Changes) {
        if ($Change.HadFile) {
            if ((Hash $Change.Path) -ne $Change.OldHash) { throw 'A destination file changed during update.' }
            [IO.File]::Replace($Change.Temp, $Change.Path, ($Change.Backup+'.atomic'))
        } else { [IO.File]::Move($Change.Temp, $Change.Path) }
        $Change.Applied = $true
    }
    foreach ($Path in $Protected.Keys) { if ((Hash $Path) -ne $Protected[$Path]) { throw 'An original game file changed during update.' } }
    if ((Hash $TargetMusic) -ne $MusicHash -or (Hash $TargetScript) -ne $ScriptHash) { throw 'Installed file verification failed.' }
    @{Update='menu-bgm-1';MusicSHA256=$MusicHash;ProtectedOriginalFiles=$Protected.Count;ChangedFiles=@('index.html','menu-bgm.js','mode-selection-bgm.wav')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Backup 'verification.json') -Encoding UTF8
} catch {
    foreach ($Change in $Changes) {
        if ($Change.Applied) {
            if ($Change.HadFile) { Copy-Item -LiteralPath $Change.Backup -Destination $Change.Path -Force }
            else { Remove-Item -LiteralPath $Change.Path -ErrorAction SilentlyContinue }
        }
    }
    throw
} finally {
    foreach ($Change in $Changes) { Remove-Item -LiteralPath $Change.Temp -ErrorAction SilentlyContinue }
}
Write-Host ''
Write-Host 'APPLIED - menu-only background music and ON/OFF added.' -ForegroundColor Green
Write-Host ('Project: '+$ProjectPath)
Write-Host ('Backup: '+$Backup)
Write-Host 'The WAV was copied unchanged. game.js, effects, timers, input and Android build files were not replaced.'
Write-Host 'Next: run BUILD_DEBUG_APK.cmd from your existing project.'
