$ErrorActionPreference='Stop'
$Root=Join-Path ([IO.Path]::GetTempPath()) ('bz-bgm-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root | Out-Null
$Installer=(Resolve-Path (Join-Path $PSScriptRoot '../menu-bgm/APPLY_BGM.ps1')).Path
$Results=New-Object System.Collections.Generic.List[object]
function Check([bool]$Ok,[string]$Name){if(-not $Ok){throw $Name};$Results.Add(@{name=$Name;passed=$true})}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Run-Install([string]$Project,[string]$Music){
 $Id=[Guid]::NewGuid().ToString('N');$Out=Join-Path $Root ($Id+'.out');$Err=Join-Path $Root ($Id+'.err')
 $Args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$Installer+'"'),'-ProjectPath',('"'+$Project+'"'),'-MusicPath',('"'+$Music+'"'))
 $Process=Start-Process -FilePath 'powershell.exe' -ArgumentList $Args -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $Out -RedirectStandardError $Err
 $Result=@{Code=$Process.ExitCode;Out=[IO.File]::ReadAllText($Out);Err=[IO.File]::ReadAllText($Err)}
 if($Result.Code -ne 0){Write-Host $Result.Err}
 return $Result
}
$Music=Join-Path $Root 'my supplied song.wav'
$Bytes=New-Object byte[] 8844
[Text.Encoding]::ASCII.GetBytes('RIFF').CopyTo($Bytes,0);[BitConverter]::GetBytes([uint32]8836).CopyTo($Bytes,4)
[Text.Encoding]::ASCII.GetBytes('WAVEfmt ').CopyTo($Bytes,8);[BitConverter]::GetBytes([uint32]16).CopyTo($Bytes,16)
[BitConverter]::GetBytes([uint16]1).CopyTo($Bytes,20);[BitConverter]::GetBytes([uint16]1).CopyTo($Bytes,22)
[BitConverter]::GetBytes([uint32]22000).CopyTo($Bytes,24);[BitConverter]::GetBytes([uint32]44000).CopyTo($Bytes,28)
[BitConverter]::GetBytes([uint16]2).CopyTo($Bytes,32);[BitConverter]::GetBytes([uint16]16).CopyTo($Bytes,34)
[Text.Encoding]::ASCII.GetBytes('data').CopyTo($Bytes,36);[BitConverter]::GetBytes([uint32]8800).CopyTo($Bytes,40)
[IO.File]::WriteAllBytes($Music,$Bytes)
foreach($Bom in @($false,$true)){
 $Project=Join-Path $Root ('project with spaces '+$Bom);$Web=Join-Path $Project 'app/src/main/assets/web';New-Item -ItemType Directory -Path $Web -Force|Out-Null
 $Encoding=New-Object System.Text.UTF8Encoding($Bom)
 $Original='<html><body><div id="setup"><header class="setupHeader"></header><button id="enterRange"></button></div><div id="range"><button id="startGameButton"></button></div><div id="modal"></div></body></html>'
 [IO.File]::WriteAllText((Join-Path $Web 'index.html'),$Original,$Encoding)
 [IO.File]::WriteAllText((Join-Path $Web 'game.js'),'window.BattleZoneInput={}; // original timer, scoring and target logic',$Encoding)
 [IO.File]::WriteAllText((Join-Path $Project 'settings.gradle'),'rootProject.name="Untouched"',$Encoding)
 [IO.File]::WriteAllText((Join-Path $Project 'keystore.properties'),'local=test-only',$Encoding)
 [IO.File]::WriteAllText((Join-Path $Web 'sounds.js'),'original start beep and firing/timeout sounds',$Encoding)
 [IO.File]::WriteAllText((Join-Path $Web 'ui-button-sound.js'),'existing chosen firing button feedback',$Encoding)
 [IO.File]::WriteAllText((Join-Path $Web 'app.css'),'body{background:#123456}',$Encoding)
 $Hashes=@{};Get-ChildItem -LiteralPath $Project -File -Recurse|ForEach-Object{$Hashes[$_.FullName]=Hash $_.FullName}
 $Index=Join-Path $Web 'index.html';$r=Run-Install $Project $Music;Check ($r.Code -eq 0) ('Install succeeds with UTF8 BOM='+$Bom)
 $New=[IO.File]::ReadAllText($Index);Check ($New.Replace('<script id="bz-menu-bgm" src="menu-bgm.js"></script>'+"`n",'') -eq $Original) 'Only one script tag inserted in index'
 foreach($Path in $Hashes.Keys){if($Path -ne $Index){Check ((Hash $Path) -eq $Hashes[$Path]) ('Unchanged: '+[IO.Path]::GetFileName($Path))}}
 Check ((Hash (Join-Path $Web 'mode-selection-bgm.wav')) -eq (Hash $Music)) 'WAV copied byte-for-byte'
 $Backups=@(Get-ChildItem -LiteralPath (Join-Path $Project '.bgm-backups') -Directory);Check ($Backups.Count -eq 1) 'Backup created exactly once'
 Check ((Hash (Join-Path $Backups[0].FullName 'index.html')) -eq $Hashes[$Index]) 'Original HTML backed up byte-for-byte'
 $InstalledHash=Hash $Index;$r=Run-Install $Project $Music;Check ($r.Code -eq 0 -and $r.Out.Contains('ALREADY APPLIED')) 'Reapply recognized'
 Check ((Hash $Index) -eq $InstalledHash) 'Repeated install leaves HTML unchanged'
 $Invalid=Join-Path $Root 'not-audio.wav';[IO.File]::WriteAllText($Invalid,'not audio')
 $r=Run-Install $Project $Invalid;Check ($r.Code -ne 0) 'Invalid WAV refused'
 Check ((Hash $Index) -eq $InstalledHash) 'Rejected update preserves working project'
}
New-Item -ItemType Directory -Path 'test-results' -Force|Out-Null
@{scope='Disposable fixture project and generated test WAV, not user project';checks=$Results}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath 'test-results/windows.json' -Encoding UTF8
Write-Host ('BGM installer checks passed: '+$Results.Count)
exit 0
