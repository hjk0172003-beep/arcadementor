param([string]$ProjectPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Utf8=New-Object System.Text.UTF8Encoding($false,$true)
function Is-Project([string]$P){
 if([string]::IsNullOrWhiteSpace($P)){return $false}
 return (Test-Path -LiteralPath (Join-Path $P 'settings.gradle') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $P 'app/src/main/assets/web/index.html') -PathType Leaf)
}
function Hash([string]$P){return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash}
try{
 if([string]::IsNullOrWhiteSpace($ProjectPath)){
  Add-Type -AssemblyName System.Windows.Forms
  $dlg=New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description='Select the current BattleZone_AndroidStudio project folder.'
  $dlg.ShowNewFolderButton=$false
  if($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){Write-Host 'CANCELLED - no changes made.';exit 2}
  $ProjectPath=$dlg.SelectedPath
 }
 $ProjectPath=$ProjectPath.Trim().Trim('"')
 if(-not(Is-Project $ProjectPath)){throw 'Select the BattleZone_AndroidStudio folder that contains app and settings.gradle.'}
 $ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
 $Web=Join-Path $ProjectPath 'app/src/main/assets/web'
 $Index=Join-Path $Web 'index.html'
 $Target=Join-Path $Web 'bz-paper-tabs.js'
 $Source=Join-Path $PSScriptRoot 'payload/bz-paper-tabs.js'
 if(-not(Test-Path -LiteralPath $Source)){throw 'Extract the whole ZIP before running this updater.'}
 $Original=[IO.File]::ReadAllBytes($Index)
 $Html=$Utf8.GetString($Original)
 if(-not $Html.Contains('id="setup"')){throw 'The game setup screen was not found.'}
 $Tag='<script id="bz-paper-tabs-script" src="bz-paper-tabs.js"></script>'
 if(-not $Html.Contains($Tag)){
  $m=[regex]::Matches($Html,'(?i)</body\s*>')
  if($m.Count -ne 1){throw 'Unexpected index.html structure.'}
  $Html=$Html.Insert($m[0].Index,$Tag+[Environment]::NewLine)
 }
 $NewIndex=$Utf8.GetBytes($Html)
 $NewScript=[IO.File]::ReadAllBytes($Source)
 $stamp=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)
 $backup=Join-Path $ProjectPath ('.paper-tab-backups/'+$stamp)
 New-Item -ItemType Directory -Force -Path $backup|Out-Null
 [IO.File]::WriteAllBytes((Join-Path $backup 'index.html'),$Original)
 if(Test-Path -LiteralPath $Target){Copy-Item -LiteralPath $Target -Destination (Join-Path $backup 'bz-paper-tabs.js') -Force}
 $protected=@{}
 Get-ChildItem -LiteralPath $Web -File | Where-Object{$_.FullName -notin @($Index,$Target)} | ForEach-Object{$protected[$_.FullName]=Hash $_.FullName}
 try{
  [IO.File]::WriteAllBytes($Index,$NewIndex)
  [IO.File]::WriteAllBytes($Target,$NewScript)
  foreach($p in $protected.Keys){if((Hash $p) -ne $protected[$p]){throw 'Another game file changed during the update.'}}
 }catch{
  [IO.File]::WriteAllBytes($Index,$Original)
  if(Test-Path -LiteralPath (Join-Path $backup 'bz-paper-tabs.js')){Copy-Item -LiteralPath (Join-Path $backup 'bz-paper-tabs.js') -Destination $Target -Force}else{Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue}
  throw
 }
 Write-Host 'APPLIED - paper tabs now show only Color 1 and Color 2.' -ForegroundColor Green
 Write-Host ('Project: '+$ProjectPath)
 Write-Host ('Backup: '+$backup)
 Write-Host 'The existing color-selection behavior and all other game logic are preserved.'
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 exit 1
}