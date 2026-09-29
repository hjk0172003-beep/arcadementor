param([string]$ProjectPath='', [switch]$NoPrompt)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Utf8=New-Object System.Text.UTF8Encoding($false,$true)
function Is-Project([string]$P) {
 if([string]::IsNullOrWhiteSpace($P)){return $false}
 return ((Test-Path -LiteralPath (Join-Path $P 'settings.gradle')) -and (Test-Path -LiteralPath (Join-Path $P 'app/src/main/assets/web/game.js')) -and (Test-Path -LiteralPath (Join-Path $P 'app/src/main/AndroidManifest.xml')))
}
function Hash([string]$P){return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash}
function BytesHash([byte[]]$B){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($B))).Replace('-','')}finally{$sha.Dispose()}}
function Add-Script([string]$Html,[string]$Name,[string]$Id) {
 $pattern='<script\b[^>]*\bsrc\s*=\s*["''](?:\./)?'+[regex]::Escape($Name)+'(?:\?[^"'']*)?["''][^>]*>\s*</script>'
 $tag='<script id="'+$Id+'" src="'+$Name+'"></script>'
 $hits=[regex]::Matches($Html,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
 if($hits.Count -eq 1 -and $hits[0].Value -ceq $tag){return $Html}
 if($hits.Count -gt 0){$Html=[regex]::Replace($Html,$pattern,'',[Text.RegularExpressions.RegexOptions]::IgnoreCase)}
 $ends=[regex]::Matches($Html,'</body\s*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
 if($ends.Count -ne 1){throw 'Unexpected index.html structure. No changes made.'}
 return $Html.Insert($ends[0].Index,$tag+"`r`n")
}
function Set-AppAttribute([string]$Tag,[string]$Name,[string]$Value) {
 $pattern='\s+android:'+ [regex]::Escape($Name)+'\s*=\s*("[^"]*"|''[^'']*'')'
 if([regex]::Matches($Tag,$pattern).Count -gt 1){throw 'Duplicate Android application attribute.'}
 $new=' android:'+ $Name+'="'+$Value+'"'
 if([regex]::IsMatch($Tag,$pattern)){return [regex]::Replace($Tag,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m)$new})}
 return $Tag.Insert($Tag.LastIndexOf('>'),$new)
}
try {
 if([string]::IsNullOrWhiteSpace($ProjectPath)){
  foreach($p in @('C:\BattleZone\BattleZone_AndroidStudio',$PSScriptRoot,(Split-Path $PSScriptRoot -Parent))){if(Is-Project $p){$ProjectPath=$p;break}}
 }
 if([string]::IsNullOrWhiteSpace($ProjectPath) -and -not $NoPrompt){$ProjectPath=Read-Host 'Project folder (contains app and settings.gradle)'}
 $ProjectPath=$ProjectPath.Trim().Trim('"')
 if(-not (Is-Project $ProjectPath)){throw 'Project not found. Select BattleZone_AndroidStudio. Nothing was changed.'}
 $ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
 $Main=Join-Path $ProjectPath 'app/src/main';$Web=Join-Path $Main 'assets/web'
 $Payload=Join-Path $PSScriptRoot 'payload'
 $Index=Join-Path $Web 'index.html';$Manifest=Join-Path $Main 'AndroidManifest.xml'
 $Html=$Utf8.GetString([IO.File]::ReadAllBytes($Index))
 $Game=[IO.File]::ReadAllText((Join-Path $Web 'game.js'))
 if(-not $Html.Contains('id="setup"') -or -not $Html.Contains('id="splash"') -or -not $Html.Contains('data-decimal') -or -not $Game.Contains('BattleZoneInput')){throw 'Unexpected game layout. Nothing was changed.'}
 foreach($n in @('bz-menu-music.js','bz-brand-menus.js','splash-data.js','bz-clean-splash.png','bz-app-icon.png')){if(-not(Test-Path -LiteralPath (Join-Path $Payload $n))){throw ('Missing update file: '+$n+'. Extract the entire ZIP first.')}}
 foreach($n in @('bz-menu-music.js','bz-brand-menus.js')){
  $dest=Join-Path $Web $n
  if(Test-Path -LiteralPath $dest){$old=[IO.File]::ReadAllText($dest);if($n -eq 'bz-menu-music.js' -and $old -notmatch 'BATTLEZONE_MENU_MUSIC|BZMenuMusicInstalled'){throw 'Different background music controller found. Nothing changed.'};if($n -eq 'bz-brand-menus.js' -and $old -notmatch 'BATTLEZONE_BRAND_MENUS'){throw 'Different menu extension found. Nothing changed.'}}
 }
 $Planned=@{}
 $Html=Add-Script $Html 'bz-menu-music.js' 'bz-menu-music-script'
 $Html=Add-Script $Html 'bz-brand-menus.js' 'bz-brand-menus-script'
 $Planned[$Index]=$Utf8.GetBytes($Html)
 foreach($n in @('bz-menu-music.js','bz-brand-menus.js','splash-data.js')){$Planned[(Join-Path $Web $n)]=[IO.File]::ReadAllBytes((Join-Path $Payload $n))}
 $Music=Join-Path $Web 'bz-menu-music.wav'
 if(-not(Test-Path -LiteralPath $Music)){
  $source=''
  foreach($p in @((Join-Path $PSScriptRoot 'music/Majestic_Modern_Electronic_Power_BGM.wav'),(Join-Path $env:USERPROFILE 'Downloads/Majestic_Modern_Electronic_Power_BGM.wav'))){if(Test-Path -LiteralPath $p){$source=$p;break}}
  if(-not $source -and -not $NoPrompt){
   Add-Type -AssemblyName System.Windows.Forms
   $picker=New-Object System.Windows.Forms.OpenFileDialog
   $picker.Title='Select your existing background music WAV';$picker.Filter='WAV music (*.wav)|*.wav';$picker.FileName='Majestic_Modern_Electronic_Power_BGM.wav'
   if($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){throw 'Cancelled. Nothing was changed.'}
   $source=$picker.FileName
  }
  if(-not $source){throw 'Existing bz-menu-music.wav is missing. Install your BGM first. Nothing was changed.'}
  $b=[IO.File]::ReadAllBytes($source)
  if($b.Length -lt 44 -or [Text.Encoding]::ASCII.GetString($b,0,4) -ne 'RIFF' -or [Text.Encoding]::ASCII.GetString($b,8,4) -ne 'WAVE'){throw 'Invalid WAV. Nothing was changed.'}
  $Planned[$Music]=$b
 }
 $ManifestText=$Utf8.GetString([IO.File]::ReadAllBytes($Manifest));$xml=[xml]$ManifestText
 $apps=[regex]::Matches($ManifestText,'<application\b[^>]*>',[Text.RegularExpressions.RegexOptions]::Singleline)
 if($apps.Count -ne 1){throw 'Unexpected AndroidManifest.xml. Nothing was changed.'}
 $tag=Set-AppAttribute $apps[0].Value 'icon' '@mipmap/bz_launcher'
 $tag=Set-AppAttribute $tag 'roundIcon' '@mipmap/bz_launcher'
 $ManifestText=$ManifestText.Remove($apps[0].Index,$apps[0].Length).Insert($apps[0].Index,$tag)
 $check=[xml]$ManifestText
 $Planned[$Manifest]=$Utf8.GetBytes($ManifestText)
 $Res=(Resolve-Path -LiteralPath (Join-Path $Payload 'res')).Path
 Get-ChildItem -LiteralPath $Res -File -Recurse | ForEach-Object {
  $rel=$_.FullName.Substring($Res.Length).TrimStart([char[]]'\/')
  $Planned[(Join-Path (Join-Path $Main 'res') $rel)]=[IO.File]::ReadAllBytes($_.FullName)
 }
 $changed=@($Planned.Keys | Where-Object { -not(Test-Path -LiteralPath $_) -or (Hash $_) -ne (BytesHash $Planned[$_]) })
 if($changed.Count -eq 0){Write-Host 'ALREADY APPLIED - rebuild the APK.' -ForegroundColor Green;exit 0}
 # Protect the game, its audio, user BGM and build/signing settings.
 $Protected=@{}
 Get-ChildItem -LiteralPath $Web -File -Recurse | Where-Object {-not $Planned.ContainsKey($_.FullName)} | ForEach-Object {$Protected[$_.FullName]=Hash $_.FullName}
 foreach($rel in @('app/build.gradle','gradle.properties','settings.gradle','keystore.properties')){$p=Join-Path $ProjectPath $rel;if(Test-Path -LiteralPath $p){$Protected[$p]=Hash $p}}
 $Stamp=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)
 $Backup=Join-Path $ProjectPath ('.brand-menu-backups/'+$Stamp)
 New-Item -ItemType Directory -Path $Backup -Force | Out-Null
 $Original=@{};$Completed=New-Object System.Collections.Generic.List[string]
 foreach($p in $changed){
  if(Test-Path -LiteralPath $p){$Original[$p]=[IO.File]::ReadAllBytes($p);$rel=$p.Substring($ProjectPath.Length).TrimStart([char[]]'\/');$bp=Join-Path $Backup $rel;New-Item -ItemType Directory -Path (Split-Path $bp -Parent) -Force | Out-Null;[IO.File]::WriteAllBytes($bp,$Original[$p])}
 }
 try {
  foreach($p in $changed){
   New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
   $temp=$p+'.'+$Stamp+'.tmp';[IO.File]::WriteAllBytes($temp,$Planned[$p])
   if(Test-Path -LiteralPath $p){
    if(-not $Original.ContainsKey($p) -or (Hash $p) -ne (BytesHash $Original[$p])){throw 'A file changed during installation. Please close the editor and retry.'}
    [IO.File]::Replace($temp,$p,(Join-Path $Backup ([guid]::NewGuid().ToString('N')+'.atomic.bak')))
   }else{[IO.File]::Move($temp,$p)}
   $Completed.Add($p)
  }
  foreach($p in $Protected.Keys){if((Hash $p) -ne $Protected[$p]){throw 'An original game file changed during installation.'}}
  foreach($p in $changed){if((Hash $p) -ne (BytesHash $Planned[$p])){throw 'Write verification failed.'}}
 }catch{
  foreach($p in $Completed){if($Original.ContainsKey($p)){[IO.File]::WriteAllBytes($p,$Original[$p])}else{Remove-Item -LiteralPath $p -ErrorAction SilentlyContinue}}
  throw
 }
 Write-Host 'APPLIED - menus, loading and launcher icon updated.' -ForegroundColor Green
 Write-Host ('Project: '+$ProjectPath)
 Write-Host ('Backup: '+$Backup)
 Write-Host 'Game rules, timing, hit detection, shot sounds, music file and signing settings preserved.'
 Write-Host 'Run BUILD_DEBUG_APK.cmd in your existing project, then install the new APK.'
 exit 0
}catch{Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red;exit 1}
