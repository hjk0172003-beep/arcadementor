$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Temp=Join-Path ([IO.Path]::GetTempPath()) ('bz-brand-'+[guid]::NewGuid().ToString('N'))
$Utf8=New-Object System.Text.UTF8Encoding($false)
$Checks=New-Object System.Collections.Generic.List[string]
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$Checks.Add($Name)}
function Put([string]$P,[string]$Text){New-Item -ItemType Directory -Path (Split-Path $P -Parent) -Force | Out-Null;[IO.File]::WriteAllText($P,$Text,$Utf8)}
function Hash([string]$P){return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash}
function Fixture([string]$Name){
 $p=Join-Path $Temp $Name;$w=Join-Path $p 'app/src/main/assets/web'
 Put (Join-Path $p 'settings.gradle') 'preserve-gradle'
 Put (Join-Path $p 'app/build.gradle') 'preserve-version-and-signing'
 Put (Join-Path $p 'keystore.properties') 'preserve-existing-private-signing-settings'
 Put (Join-Path $w 'game.js') 'window.BattleZoneInput={}; // preserve timers, zero visual, score and startGate'
 Put (Join-Path $w 'audio-data.js') 'original-selected-start-beep-and-score-audio'
 Put (Join-Path $w 'timeout-audio.js') 'original-timeout'
 Put (Join-Path $w 'ui-button-sound.js') 'original-chosen-shot-effect-feedback'
 Put (Join-Path $w 'bz-menu-music.wav') 'existing-user-music-placeholder'
 Put (Join-Path $w 'bz-menu-music.js') '/* BATTLEZONE_MENU_MUSIC_V2 */'
 Put (Join-Path $w 'splash-data.js') 'const BZ_SPLASH_IMAGE="old-image";'
 Put (Join-Path $w 'index.html') '<html><body><section id="setup"><div class="settingRow"><button data-decimal="off">OFF</button></div></section><section id="splash"></section><script src="bz-menu-music.js"></script></body></html>'
 Put (Join-Path $p 'app/src/main/AndroidManifest.xml') '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Battle Zone" android:icon="@drawable/ic_launcher" android:allowBackup="false"><activity android:name=".MainActivity" android:screenOrientation="sensorLandscape" /></application></manifest>'
 return $p
}
try{
 $p=Fixture 'project with spaces';$w=Join-Path $p 'app/src/main/assets/web';$Protected=@{}
 foreach($rel in @('settings.gradle','app/build.gradle','keystore.properties','app/src/main/assets/web/game.js','app/src/main/assets/web/audio-data.js','app/src/main/assets/web/timeout-audio.js','app/src/main/assets/web/ui-button-sound.js','app/src/main/assets/web/bz-menu-music.wav')){$f=Join-Path $p $rel;$Protected[$f]=Hash $f}
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $p -NoPrompt
 Check ($LASTEXITCODE -eq 0) 'Windows apply succeeds'
 foreach($f in $Protected.Keys){Check ((Hash $f) -eq $Protected[$f]) ('Preserved '+$f.Substring($p.Length))}
 $html=[IO.File]::ReadAllText((Join-Path $w 'index.html'))
 Check (([regex]::Matches($html,'src="bz-menu-music.js"')).Count -eq 1) 'One music script'
 Check (([regex]::Matches($html,'src="bz-brand-menus.js"')).Count -eq 1) 'One presentation script'
 $m=[xml][IO.File]::ReadAllText((Join-Path $p 'app/src/main/AndroidManifest.xml'))
 Check ($m.manifest.application.GetAttribute('icon','http://schemas.android.com/apk/res/android') -eq '@mipmap/bz_launcher') 'Launcher icon replaced'
 Check ($m.manifest.application.GetAttribute('roundIcon','http://schemas.android.com/apk/res/android') -eq '@mipmap/bz_launcher') 'Round icon set'
 Check ($m.manifest.application.GetAttribute('allowBackup','http://schemas.android.com/apk/res/android') -eq 'false') 'Other manifest attributes preserved'
 Check ($m.manifest.application.activity.GetAttribute('screenOrientation','http://schemas.android.com/apk/res/android') -eq 'sensorLandscape') 'Orientation unchanged'
 Check (Test-Path (Join-Path $p 'app/src/main/res/mipmap-anydpi-v26/bz_launcher.xml')) 'Adaptive resources copied'
 $before=Hash (Join-Path $w 'index.html')
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $p -NoPrompt
 Check ($LASTEXITCODE -eq 0) 'Repeated apply succeeds'
 Check ((Hash (Join-Path $w 'index.html')) -eq $before) 'Repeated apply is byte-idempotent'
 Check (@(Get-ChildItem -LiteralPath (Join-Path $p '.brand-menu-backups') -Directory).Count -eq 1) 'No extra backup on unchanged repeat'
 $bad=Fixture 'unexpected';Put (Join-Path $bad 'app/src/main/assets/web/game.js') 'unrelated game'
 $before=Hash (Join-Path $bad 'app/src/main/assets/web/index.html')
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Apply_Update.ps1') -ProjectPath $bad -NoPrompt
 Check ($LASTEXITCODE -ne 0) 'Unrecognized project rejected'
 Check ((Hash (Join-Path $bad 'app/src/main/assets/web/index.html')) -eq $before) 'Rejected project not modified'
 $dir=Join-Path $Root 'verification';New-Item -ItemType Directory -Path $dir -Force | Out-Null
 @{scope='Windows PowerShell 5.1; compatible synthetic project, not user APK';passed=$Checks.Count;checks=$Checks}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $dir 'windows.json') -Encoding UTF8
 Write-Host ('WINDOWS CHECKS PASSED: '+$Checks.Count)
 $global:LASTEXITCODE=0
 exit 0
}catch{Write-Error $_;exit 1}
