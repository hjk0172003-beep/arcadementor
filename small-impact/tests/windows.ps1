$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Temp=Join-Path ([IO.Path]::GetTempPath()) ('bz-small-'+[guid]::NewGuid().ToString('N'))
$Utf8=New-Object System.Text.UTF8Encoding($false)
$Results=New-Object System.Collections.Generic.List[string]
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$Results.Add($Name)}
function Put([string]$P,[string]$Text){New-Item -ItemType Directory -Force -Path (Split-Path $P -Parent)|Out-Null;[IO.File]::WriteAllText($P,$Text,$Utf8)}
function Hash([string]$P){return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash}
$prefix=@'
'use strict';
const preferences={paperColor:'kruger2',music:true,shotLimit:5};
function isImpact(p){return !!p&&!p.timeout&&Number.isFinite(p.x)&&Number.isFinite(p.y);}
function circle(c,x,y,r,fill,stroke,width=1){/* unchanged helper */}
'@
$old=@'
function drawMarks(c,a,cx,cy,scale,numbers=true,selected=null){
 // This is an oversized compatible drawing fixture, not the user's game.
 for(const p of a){if(!isImpact(p))continue;const x=cx+p.x*scale,y=cy+p.y*scale;
  circle(c,x,y,22,'#11151b','#ffffff',2);
  if(numbers){c.font=`900 ${30}px sans-serif`;c.fillText(String(p.n),x,y);}
  const braces='literal } and {'; /* { ignore } */
 }
}
'@
$suffix=@'
function canvasTarget(canvas,mode,shots,thumb=false){return 'preserved';}
function scoreAt(x,y){return x+y;}
function localPoint(e){return {x:e.clientX,y:e.clientY};}
window.BattleZoneInput={hit:function(e){return e;}};
const timingAndAudio='unchanged';
'@
try{
 foreach($crlf in @($false,$true)){
  foreach($bom in @($false,$true)){
   $p=Join-Path $Temp ('project with spaces '+$crlf+' '+$bom);$w=Join-Path $p 'app/src/main/assets/web'
   Put (Join-Path $p 'settings.gradle') 'original gradle';Put (Join-Path $p 'app/build.gradle') 'version 27';Put (Join-Path $p 'keystore.properties') 'test sentinel do not replace'
   foreach($f in @('index.html','audio-data.js','splash-data.js','timeout-audio.js','bz-menu-music.js','bz-menu-music.wav','app.css','ui-button-sound.js')){Put (Join-Path $w $f) ('keep '+$f)}
   $newline=if($crlf){"`r`n"}else{"`n"}
   $head=[regex]::Replace($prefix.TrimEnd(),"`r?`n",$newline)+$newline
   $tail=$newline+[regex]::Replace($suffix.TrimEnd(),"`r?`n",$newline)+$newline
   $body=[regex]::Replace($old.Trim(),"`r?`n",$newline)
   $text=$head+$body+$tail
   if($bom){$text=[char]0xfeff+$text;$head=[char]0xfeff+$head}
   $g=Join-Path $w 'game.js';[IO.File]::WriteAllBytes($g,$Utf8.GetBytes($text));$original=Hash $g
   $protected=@{};Get-ChildItem -LiteralPath $p -File -Recurse|Where-Object{$_.FullName -ne $g}|ForEach-Object{$protected[$_.FullName]=Hash $_.FullName}
   & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $p -NoPrompt
   Check ($LASTEXITCODE -eq 0) ('Apply succeeds CRLF='+$crlf+' BOM='+$bom)
   $result=$Utf8.GetString([IO.File]::ReadAllBytes($g))
   Check ($result.StartsWith($head,[StringComparison]::Ordinal)) 'Prefix preserved exactly'
   Check ($result.EndsWith($tail,[StringComparison]::Ordinal)) 'Suffix preserved exactly'
   foreach($f in $protected.Keys){Check ((Hash $f)-eq $protected[$f]) ('Other file unchanged: '+[IO.Path]::GetFileName($f))}
   Check ($result.Contains('BZ_SMALL_IMPACT_V1')) 'New small drawing installed'
   Check (-not $result.Contains('oversized compatible drawing fixture')) 'Old oversized drawing removed'
   $backup=@(Get-ChildItem (Join-Path $p '.shot-size-backups') -Directory)
   Check ($backup.Count -eq 1) 'One backup created'
   Check ((Hash (Join-Path $backup[0].FullName 'game.js')) -eq $original) 'Backup is byte-identical to original'
   $after=Hash $g
   & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $p -NoPrompt
   Check ($LASTEXITCODE -eq 0) 'Idempotent repeated apply succeeds'
   Check ((Hash $g) -eq $after) 'Repeated apply keeps bytes'
   Check (@(Get-ChildItem (Join-Path $p '.shot-size-backups') -Directory).Count -eq 1) 'Repeat does not create a new backup'
   & node --check $g
   Check ($LASTEXITCODE -eq 0) 'Patched complete fixture JS syntax valid'
  }
 }
 # Refuse a three-argument function instead of breaking the seven-argument engine.
 Put $g ($prefix+"`nfunction drawMarks(c,a,numbers){return;} `n"+$suffix)
 $before=Hash $g
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $p -NoPrompt
 Check ($LASTEXITCODE -ne 0) 'Different drawing interface rejected'
 Check ((Hash $g) -eq $before) 'Rejected file left unchanged'
 Put $g ($prefix+"`n"+$old+"`n"+$old+"`n"+$suffix)
 $before=Hash $g
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $p -NoPrompt
 Check ($LASTEXITCODE -ne 0) 'Duplicate function rejected'
 Check ((Hash $g) -eq $before) 'Ambiguous file left unchanged'
 $out=Join-Path $Root 'verification';New-Item -ItemType Directory -Path $out -Force|Out-Null
 @{scope='Windows PowerShell 5.1 on synthetic compatible projects; not a full game APK test';passed=$Results.Count;checks=$Results}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $out 'windows.json') -Encoding UTF8
 Write-Host ('WINDOWS CHECKS PASSED: '+$Results.Count)
 $global:LASTEXITCODE=0;exit 0
}catch{Write-Host $_ -ForegroundColor Red;exit 1}
