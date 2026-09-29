$ErrorActionPreference='Stop'
$Root=Join-Path ([IO.Path]::GetTempPath()) ('bz-range-'+[Guid]::NewGuid().ToString('N'))
$Package=(Resolve-Path (Join-Path $PSScriptRoot '../range-update')).Path
Copy-Item (Join-Path $PSScriptRoot '../button-feedback/ui-button-sound.js') (Join-Path $Package 'ui-button-sound.js') -Force
$Utf8=New-Object System.Text.UTF8Encoding($false)
$Results=New-Object System.Collections.Generic.List[object]
function Check($Test,[string]$Label){if(-not $Test){throw $Label};$Results.Add(@{label=$Label;passed=$true})}
function SHA([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
$Html=@'
<!doctype html><html><body><div id="stage">
<div class="settingLabel">Total <span>step</span></div><div class="stepper"><button id="totalNone">None</button><button id="totalMinus">-</button><output id="totalValue">None</output><button id="totalPlus">+</button></div>
<div class="settingLabel">Shot <span>step</span></div><div class="stepper"><button id="shotNone">None</button><button id="shotMinus">-</button><output id="shotValue">None</output><button id="shotPlus">+</button></div>
<button id="startGameButton">START</button><button id="liveResult">Result</button><div id="setupSfxBlock">Effects unchanged</div>
<div class="timerRow"><span>Total <b id="totalClock">None</b></span><span>Shot <b id="shotClock">None</b></span></div>
<canvas id="target"></canvas></div></body></html>
'@
# A standalone contract fixture, not the user's full game or assets.
$Game=@'
'use strict';
let now=0;const performance={now:()=>now};let lastTime=0;
let phase='range',settings={mode:'pistol',limit:10,shotLimit:5,totalLimit:30},session=null;
let events=[],bindings=[];const clone=x=>JSON.parse(JSON.stringify(x));
function $(id){throw Error('Removed timer control was accessed: '+id);}
function clock(t){return t;}function selectStyle(){}function remaining(){return 0;}
function effect(k){events.push(k);}function toast(t){events.push(t);}function bind(id,fn){bindings.push(id);}
function renderSetup(){
 $('totalValue').textContent=clock(settings.totalLimit);$('shotValue').textContent=clock(settings.shotLimit);selectStyle($('totalNone'),!settings.totalLimit);selectStyle($('shotNone'),!settings.shotLimit);
}
function startRange(){
 const sessionConfig=clone(settings);if(sessionConfig.mode==='zero'){sessionConfig.voice='off';}
 session={config:sessionConfig,started:true,ended:false,paused:false,elapsed:0,shotElapsed:0,shotExpired:false,shots:[]};lastTime=now;
}
function renderClocks(){if(!session)return;$('totalClock').textContent=remaining(session.config.totalLimit,session.elapsed);$('shotClock').textContent=remaining(session.config.shotLimit,session.shotElapsed);$('shotClock').style.color=session.shotExpired?'red':'';}
function advance(){const at=performance.now(),dt=Math.min(3600,Math.max(0,(at-lastTime)/1000));lastTime=at;if(!session?.started||session.ended||session.paused)return;
 session.elapsed+=dt;session.shotElapsed+=dt;if(session.config.shotLimit&&session.shotElapsed>=session.config.shotLimit&&!session.shotExpired){session.shotExpired=true;effect('timeout');toast('timeout');}
 if(session.config.totalLimit&&session.elapsed>=session.config.totalLimit){finishSession('time ended');}
}
function finishSession(message){session.ended=true;events.push(message);}
function receiveHit(x,y){if(!session||!session.started||session.ended||session.paused)return false;session.shots.push({n:session.shots.length+1,time:session.elapsed,x,y});if(session.config.limit&&session.shots.length>=session.config.limit)finishSession('shot count');return true;}
function inputCoordinateUnchanged(x,y){return {x:x-7,y:y-9};}
for(const [id,key,step] of [['totalMinus','totalLimit',-30],['totalPlus','totalLimit',30],['shotMinus','shotLimit',-5],['shotPlus','shotLimit',5]])bind(id,()=>{settings[key]=Math.max(0,settings[key]+step);renderSetup();});
bind('totalNone',()=>{settings.totalLimit=0;renderSetup();});bind('shotNone',()=>{settings.shotLimit=0;renderSetup();});
bind('startGameButton',()=>{});bind('liveResult',()=>{});
const BattleZoneInput={hit:receiveHit};
'@
function Make-Fixture([string]$Name,[bool]$Bom){
 $Project=Join-Path $Root $Name;$Web=Join-Path $Project 'app/src/main/assets/web'
 New-Item -ItemType Directory -Path $Web -Force|Out-Null
 $Enc=New-Object System.Text.UTF8Encoding($Bom)
 [IO.File]::WriteAllText((Join-Path $Project 'settings.gradle'),'do not change build',$Enc)
 [IO.File]::WriteAllText((Join-Path $Project 'signing.properties'),'do not change signing',$Enc)
 [IO.File]::WriteAllText((Join-Path $Web 'index.html'),$Html.Replace("`n","`r`n"),$Enc)
 [IO.File]::WriteAllText((Join-Path $Web 'game.js'),$Game.Replace("`n","`r`n"),$Enc)
 [IO.File]::WriteAllText((Join-Path $Web 'app.css'),'preserve CSS',$Enc)
 [IO.File]::WriteAllBytes((Join-Path $Web 'voice.mp3'),[byte[]](7,8,9,10))
 return $Project
}
function Apply([string]$Project){
 $Old=$ErrorActionPreference
 try{$ErrorActionPreference='Continue';& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Package 'Apply_Update.ps1') -ProjectPath $Project 2>&1 | ForEach-Object {Write-Host $_};$Code=$LASTEXITCODE}
 finally{$ErrorActionPreference=$Old};return $Code
}
try{
 New-Item -ItemType Directory -Path 'test-results' -Force|Out-Null
 foreach($Bom in @($false,$true)){
  $Project=Make-Fixture ('with spaces '+$Bom) $Bom;$Web=Join-Path $Project 'app/src/main/assets/web'
  $OldIndex=SHA (Join-Path $Web 'index.html');$OldGame=SHA (Join-Path $Web 'game.js')
  $Protected=@{}
  foreach($Rel in @('settings.gradle','signing.properties','app/src/main/assets/web/app.css','app/src/main/assets/web/voice.mp3')){$Protected[$Rel]=SHA (Join-Path $Project $Rel)}
  $Code=Apply $Project;Check ($Code -eq 0) ('Combined update applied; BOM='+$Bom)
  $NewHtml=[IO.File]::ReadAllText((Join-Path $Web 'index.html'));$NewGame=[IO.File]::ReadAllText((Join-Path $Web 'game.js'))
  foreach($Id in @('totalNone','totalMinus','totalPlus','totalValue','shotNone','shotMinus','shotPlus','shotValue','totalClock','shotClock')){Check (-not $NewHtml.Contains('id="'+$Id+'"')) ('Removed visible '+$Id+'; BOM='+$Bom)}
  Check ($NewHtml.Contains('id="bz-button-feedback"')) ('Button sound included; BOM='+$Bom)
  Check ($NewHtml.Contains('id="startGameButton"')) ('START remains; BOM='+$Bom)
  Check ($NewHtml.Contains('id="setupSfxBlock"')) ('Shot effects UI remains; BOM='+$Bom)
  Check ($NewGame.Contains('function inputCoordinateUnchanged(x,y){return {x:x-7,y:y-9};}')) ('Input code preserved; BOM='+$Bom)
  Check (-not $NewGame.Contains("effect('timeout')")) ('Timeout branch removed; BOM='+$Bom)
  Check ($NewGame.Contains('session.elapsed+=dt')) ('Record timestamps preserved; BOM='+$Bom)
  foreach($Rel in $Protected.Keys){Check ((SHA (Join-Path $Project $Rel)) -eq $Protected[$Rel]) ('Unrelated file preserved: '+$Rel+'; BOM='+$Bom)}
  $Backup=@(Get-ChildItem -LiteralPath (Join-Path $Project '.range-update-backups') -Directory)
  Check ($Backup.Count -eq 1) ('Original backed up; BOM='+$Bom)
  Check ((SHA (Join-Path $Backup[0].FullName 'index.html')) -eq $OldIndex) ('HTML backup exact; BOM='+$Bom)
  Check ((SHA (Join-Path $Backup[0].FullName 'game.js')) -eq $OldGame) ('JS backup exact; BOM='+$Bom)
  $OnceIndex=SHA (Join-Path $Web 'index.html');$OnceGame=SHA (Join-Path $Web 'game.js')
  $Code=Apply $Project;Check ($Code -eq 0) ('Second install succeeds; BOM='+$Bom)
  Check ((SHA (Join-Path $Web 'index.html')) -eq $OnceIndex) ('No duplicate HTML patch; BOM='+$Bom)
  Check ((SHA (Join-Path $Web 'game.js')) -eq $OnceGame) ('No duplicate JS patch; BOM='+$Bom)
  if(-not $Bom){Copy-Item (Join-Path $Web 'game.js') 'test-results/patched-fixture.js';Copy-Item (Join-Path $Web 'index.html') 'test-results/patched-fixture.html'}
 }
 $Project=Make-Fixture 'unexpected source' $false;$Web=Join-Path $Project 'app/src/main/assets/web'
 [IO.File]::WriteAllText((Join-Path $Web 'game.js'),$Game.Replace('function renderClocks()','function unexpectedClock()'),$Utf8)
 $Before=SHA (Join-Path $Web 'index.html');$BeforeGame=SHA (Join-Path $Web 'game.js')
 $Code=Apply $Project;Check ($Code -ne 0) 'Unexpected source is rejected'
 Check ((SHA (Join-Path $Web 'index.html')) -eq $Before) 'Rejected source leaves HTML unchanged'
 Check ((SHA (Join-Path $Web 'game.js')) -eq $BeforeGame) 'Rejected source leaves JS unchanged'
 Check (-not (Test-Path (Join-Path $Web 'ui-button-sound.js'))) 'No partial addon on refusal'
 @{scope='Windows PowerShell installer and synthetic timer contract; not a full game APK test';passed=$Results.Count;results=$Results}|ConvertTo-Json -Depth 10|Set-Content 'test-results/installer.json' -Encoding UTF8
 Write-Host ('PASSED: '+$Results.Count)
}finally{Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue}
$global:LASTEXITCODE=0
exit 0
