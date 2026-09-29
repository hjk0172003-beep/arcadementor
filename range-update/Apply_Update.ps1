param([string]$ProjectPath = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'Transform_Project.ps1')
function Test-Project([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ((Test-Path -LiteralPath (Join-Path $Path 'settings.gradle') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/index.html') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'app/src/main/assets/web/game.js') -PathType Leaf))
}
function SHA([string]$File) { return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash }
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    foreach ($Candidate in @($PSScriptRoot,(Split-Path $PSScriptRoot -Parent),'C:\BattleZone\BattleZone_AndroidStudio')) {
        if (Test-Project $Candidate) { $ProjectPath=$Candidate;break }
    }
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Host 'Enter the project folder containing settings.gradle and app:'
        $ProjectPath=Read-Host
    }
}
$ProjectPath=$ProjectPath.Trim().Trim('"')
if (-not (Test-Project $ProjectPath)) { throw 'Project not found. Nothing was changed.' }
$ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
$Web=Join-Path $ProjectPath 'app/src/main/assets/web'
$Index=Join-Path $Web 'index.html'
$Game=Join-Path $Web 'game.js'
$Ui=Join-Path $Web 'ui-button-sound.js'
$UiSource=Join-Path $PSScriptRoot 'ui-button-sound.js'
if (-not (Test-Path -LiteralPath $UiSource)) { throw 'Extract the entire update ZIP first. ui-button-sound.js is missing.' }
$Utf8=New-Object System.Text.UTF8Encoding($false,$true)
$Original=@{}
foreach ($File in @($Index,$Game,$Ui)) { if (Test-Path -LiteralPath $File) { $Original[$File]=[IO.File]::ReadAllBytes($File) } }
$GameText=$Utf8.GetString($Original[$Game]);$Html=$Utf8.GetString($Original[$Index])
$UiText=[IO.File]::ReadAllText($UiSource)
$UiMarker='BattleZone button confirmation audio (isolated add-on)'
if (-not $UiText.Contains($UiMarker)) { throw 'Invalid sound add-on. Nothing was changed.' }
if ($Original.ContainsKey($Ui) -and -not $Utf8.GetString($Original[$Ui]).Contains($UiMarker)) { throw 'An unknown ui-button-sound.js already exists. Nothing was changed.' }
$Plan=Get-BattleZoneUpdate $Html $GameText
$NewFiles=@{}
$NewFiles[$Index]=$Utf8.GetBytes($Plan.Html)
$NewFiles[$Game]=$Utf8.GetBytes($Plan.Game)
$NewFiles[$Ui]=[IO.File]::ReadAllBytes($UiSource)
$AllSame=$true
foreach($File in $NewFiles.Keys) {
    if (-not $Original.ContainsKey($File) -or [Convert]::ToBase64String($NewFiles[$File]) -cne [Convert]::ToBase64String($Original[$File])) { $AllSame=$false }
}
if ($AllSame) { Write-Host 'ALREADY APPLIED - timers removed and button sound installed.' -ForegroundColor Green;exit 0 }
$Hashes=@{}
Get-ChildItem -LiteralPath $Web -File -Recurse | ForEach-Object { $Hashes[$_.FullName]=SHA $_.FullName }
$Stamp=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
$Backup=Join-Path $ProjectPath ('.range-update-backups/'+$Stamp)
New-Item -ItemType Directory -Path $Backup -Force | Out-Null
foreach($File in $Original.Keys) { [IO.File]::WriteAllBytes((Join-Path $Backup ([IO.Path]::GetFileName($File))),$Original[$File]) }
$Written=New-Object System.Collections.Generic.List[string]
$Temps=New-Object System.Collections.Generic.List[string]
try {
    foreach($File in @($Ui,$Game,$Index)) {
        if ($Hashes.ContainsKey($File) -and (SHA $File) -ne $Hashes[$File]) { throw 'A source file changed during installation. Close the editor and retry.' }
        if (-not $Hashes.ContainsKey($File) -and (Test-Path -LiteralPath $File)) { throw 'An unexpected file appeared during installation.' }
        $Temp=$File+'.'+$Stamp+'.tmp';$Temps.Add($Temp)
        [IO.File]::WriteAllBytes($Temp,$NewFiles[$File])
        if (Test-Path -LiteralPath $File) {
            [IO.File]::Replace($Temp,$File,(Join-Path $Backup ('replaced-'+[IO.Path]::GetFileName($File))))
        } else { [IO.File]::Move($Temp,$File) }
        $Written.Add($File)
    }
    foreach($File in $Hashes.Keys) {
        if (-not $NewFiles.ContainsKey($File) -and (SHA $File) -ne $Hashes[$File]) { throw 'An unrelated web asset changed during installation.' }
    }
    foreach($File in $NewFiles.Keys) {
        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($File)) -cne [Convert]::ToBase64String($NewFiles[$File])) { throw 'Written file verification failed.' }
    }
} catch {
    foreach($File in $Written) {
        if ($Original.ContainsKey($File)) { [IO.File]::WriteAllBytes($File,$Original[$File]) }
        else { Remove-Item -LiteralPath $File -ErrorAction SilentlyContinue }
    }
    throw
} finally {
    foreach($File in $Temps) { Remove-Item -LiteralPath $File -ErrorAction SilentlyContinue }
}
Write-Host ''
Write-Host 'APPLIED - both time limits removed; button sound added.' -ForegroundColor Green
Write-Host ('Project: '+$ProjectPath)
Write-Host ('Original backup: '+$Backup)
Write-Host 'No timeout voice, zero-score penalty, or time-based match end.'
Write-Host 'Original design, scoring, input fixes, audio assets and Android build/signing settings are preserved.'
Write-Host 'Rebuild your APK using your existing BUILD_DEBUG_APK.cmd or gradlew.bat :app:assembleDebug.'
