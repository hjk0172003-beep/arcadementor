$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Installer=(Resolve-Path (Join-Path $PSScriptRoot '../menu-bgm-update/Apply_MenuBGM.ps1')).Path
$Root=Join-Path ([IO.Path]::GetTempPath()) ('bz-menu-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root | Out-Null
$Results=New-Object 'System.Collections.Generic.List[object]'
function Check($Value,[string]$Label) {if(-not $Value){throw $Label};$Results.Add(@{test=$Label;passed=$true})}
function Digest([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Run-Installer([string]$Project,[string]$Music){
 $Previous=$ErrorActionPreference;$ErrorActionPreference='Continue'
 $Output=& powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $Installer -ProjectPath $Project -MusicPath $Music -NonInteractive 2>&1
 $Code=$LASTEXITCODE;$ErrorActionPreference=$Previous
 Write-Host ($Output | Out-String)
 return $Code
}
function Fixture([string]$Name,[bool]$Bom){
 $P=Join-Path $Root $Name;$W=Join-Path $P 'app/src/main/assets/web'
 New-Item -ItemType Directory -Path $W -Force | Out-Null
 $E=New-Object System.Text.UTF8Encoding($Bom)
 [IO.File]::WriteAllText((Join-Path $P 'settings.gradle'),'original gradle',$E)
 [IO.File]::WriteAllText((Join-Path $W 'index.html'),"<!doctype html>`r`n<div id=`"setup`" class=`"setupHeader`"></div><div id=`"range`"></div>`r`n</body>",$E)
 [IO.File]::WriteAllText((Join-Path $W 'game.js'),'/* BattleZoneInput startGameButton timers and scores stay unchanged */',$E)
 foreach($F in @('app.css','ui-button-sound.js','sounds.js','start-audio.js')){[IO.File]::WriteAllText((Join-Path $W $F),('unchanged '+$F),$E)}
 return $P
}
$Music=Join-Path $Root 'original music.wav'
$Bytes=New-Object byte[] 48
[Array]::Copy([Text.Encoding]::ASCII.GetBytes('RIFF'),0,$Bytes,0,4)
[Array]::Copy([Text.Encoding]::ASCII.GetBytes('WAVE'),0,$Bytes,8,4)
[IO.File]::WriteAllBytes($Music,$Bytes)
try {
 foreach($Bom in @($false,$true)){
  $P=Fixture ('project with spaces '+$Bom+' '+[char]0xAC00) $Bom
  $W=Join-Path $P 'app/src/main/assets/web';$Index=Join-Path $W 'index.html'
  $Original=Digest $Index;$OriginalHtml=[Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($Index))
  $Before=@{};Get-ChildItem $W -File | Where-Object {$_.Name -ne 'index.html'} | ForEach-Object {$Before[$_.FullName]=Digest $_.FullName}
  $Gradle=Digest (Join-Path $P 'settings.gradle')
  Check ((Run-Installer $P $Music) -eq 0) ('Apply succeeds, BOM='+$Bom)
  foreach($F in $Before.Keys){Check ((Digest $F) -eq $Before[$F]) ('Original preserved: '+[IO.Path]::GetFileName($F)+' BOM='+$Bom)}
  Check ((Digest (Join-Path $P 'settings.gradle')) -eq $Gradle) ('Gradle untouched BOM='+$Bom)
  Check ((Digest (Join-Path $W 'bz-menu-music.wav')) -eq (Digest $Music)) ('WAV exact bytes BOM='+$Bom)
  $Html=[Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($Index))
  $Tag='<script id="bz-menu-music-script" src="bz-menu-music.js"></script>'
  Check ([regex]::Matches($Html,'id="bz-menu-music-script"').Count -eq 1) ('One script tag BOM='+$Bom)
  Check ($Html.Replace($Tag+"`r`n",'') -ceq $OriginalHtml) ('Only script connection changed BOM='+$Bom)
  $Backup=Get-ChildItem (Join-Path $P '.menu-bgm-backups') -Directory | Select-Object -First 1
  Check ((Digest (Join-Path $Backup.FullName 'index.html')) -eq $Original) ('Backup original bytes BOM='+$Bom)
  $Patched=Digest $Index
  Check ((Run-Installer $P $Music) -eq 0) ('Repeat succeeds BOM='+$Bom)
  Check ((Digest $Index) -eq $Patched) ('Repeat no mutation BOM='+$Bom)
  Check (@(Get-ChildItem (Join-Path $P '.menu-bgm-backups') -Directory).Count -eq 1) ('Repeat no duplicate backup BOM='+$Bom)
  [IO.File]::WriteAllText((Join-Path $W 'bz-menu-music.js'),'/* BATTLEZONE_MENU_MUSIC_V1 */')
  Check ((Run-Installer $P $Music) -eq 0) ('Previous pasted V1 script upgrades BOM='+$Bom)
  Check ([IO.File]::ReadAllText((Join-Path $W 'bz-menu-music.js')).Contains('BATTLEZONE_MENU_MUSIC_V2')) ('V2 installed BOM='+$Bom)
 }
 $P=Fixture 'wrong project' $false;$W=Join-Path $P 'app/src/main/assets/web'
 [IO.File]::WriteAllText((Join-Path $W 'game.js'),'different app');$Before=Digest (Join-Path $W 'index.html')
 Check ((Run-Installer $P $Music) -ne 0) 'Reject different game'
 Check ((Digest (Join-Path $W 'index.html')) -eq $Before) 'Different game index untouched'
 $P=Fixture 'file collision' $false;$W=Join-Path $P 'app/src/main/assets/web';$Before=Digest (Join-Path $W 'index.html')
 [IO.File]::WriteAllText((Join-Path $W 'bz-menu-music.js'),'my custom file')
 Check ((Run-Installer $P $Music) -ne 0) 'Reject unknown same-name script'
 Check ([IO.File]::ReadAllText((Join-Path $W 'bz-menu-music.js')) -ceq 'my custom file') 'Unknown script untouched'
 Check ((Digest (Join-Path $W 'index.html')) -eq $Before) 'Collision index untouched'
 $P=Fixture 'invalid wave' $false;$W=Join-Path $P 'app/src/main/assets/web';$Before=Digest (Join-Path $W 'index.html')
 $Bad=Join-Path $Root 'bad.wav';[IO.File]::WriteAllText($Bad,'not audio')
 Check ((Run-Installer $P $Bad) -ne 0) 'Reject invalid WAV'
 Check ((Digest (Join-Path $W 'index.html')) -eq $Before) 'Invalid WAV index untouched'
 New-Item -ItemType Directory -Path 'test-results' -Force | Out-Null
 $Results | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 'test-results/windows.json'
 Write-Host ('WINDOWS INSTALLER CHECKS PASSED: '+$Results.Count)
 $global:LASTEXITCODE=0
} finally {Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue}
