$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$temp=Join-Path ([IO.Path]::GetTempPath()) ('bz-paper-tabs-'+[guid]::NewGuid().ToString('N'))
$p=Join-Path $temp 'BattleZone_AndroidStudio'
$web=Join-Path $p 'app/src/main/assets/web'
New-Item -ItemType Directory -Force -Path $web|Out-Null
Set-Content -LiteralPath (Join-Path $p 'settings.gradle') -Value 'rootProject.name="Test"' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $web 'index.html') -Value '<html><body><section id="setup"></section></body></html>' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $web 'game.js') -Value 'const sentinel="unchanged";' -Encoding UTF8
$before=(Get-FileHash -LiteralPath (Join-Path $web 'game.js')).Hash
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Apply_Update.ps1') -ProjectPath $p
if($LASTEXITCODE -ne 0){throw 'apply failed'}
if(-not(Test-Path -LiteralPath (Join-Path $web 'bz-paper-tabs.js'))){throw 'js missing'}
$html=Get-Content -LiteralPath (Join-Path $web 'index.html') -Raw
if($html -notmatch 'bz-paper-tabs.js'){throw 'script tag missing'}
$after=(Get-FileHash -LiteralPath (Join-Path $web 'game.js')).Hash
if($before -ne $after){throw 'game.js changed'}
Write-Host 'PASS'