param([string]$ProjectPath='', [switch]$NoPrompt)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Utf8=New-Object System.Text.UTF8Encoding($false,$true)
function Hash([string]$P){return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash}
function BytesHash([byte[]]$B){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($B))).Replace('-','')}finally{$sha.Dispose()}}
function IsProject([string]$P){
 if([string]::IsNullOrWhiteSpace($P)){return $false}
 return ((Test-Path -LiteralPath (Join-Path $P 'settings.gradle') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $P 'app/src/main/assets/web/game.js') -PathType Leaf))
}
function FunctionSpan([string]$Code){
 $hits=[regex]::Matches($Code,'(?m)^[ \t]*function[ \t]+drawMarks[ \t]*\(([^\r\n)]*)\)[ \t]*\{')
 if($hits.Count -ne 1){throw 'Expected exactly one drawMarks function. Nothing was changed.'}
 $m=$hits[0];$argsText=$m.Groups[1].Value -replace '\s',''
 if($argsText -ne 'c,a,cx,cy,scale,numbers=true,selected=null'){
  throw 'The drawing function has a different interface. Nothing was changed. Send your game.js for a matching update.'
 }
 $open=$m.Index+$m.Length-1;$depth=1;$quote=0;$lineComment=$false;$blockComment=$false
 for($i=$open+1;$i -lt $Code.Length;$i++){
  $v=[int][char]$Code[$i];$next=0;if($i+1 -lt $Code.Length){$next=[int][char]$Code[$i+1]}
  if($lineComment){if($v -eq 10 -or $v -eq 13){$lineComment=$false};continue}
  if($blockComment){if($v -eq 42 -and $next -eq 47){$blockComment=$false;$i++};continue}
  if($quote -ne 0){if($v -eq 92){$i++;continue};if($v -eq $quote){$quote=0};continue}
  if($v -eq 47 -and $next -eq 47){$lineComment=$true;$i++;continue}
  if($v -eq 47 -and $next -eq 42){$blockComment=$true;$i++;continue}
  if($v -eq 39 -or $v -eq 34 -or $v -eq 96){$quote=$v;continue}
  if($v -eq 123){$depth++}
  if($v -eq 125){$depth--;if($depth -eq 0){return @{Start=$m.Index;Length=$i-$m.Index+1}}}
 }
 throw 'Could not find the end of drawMarks. Nothing was changed.'
}
try{
 if([string]::IsNullOrWhiteSpace($ProjectPath)){
  if($NoPrompt){throw 'ProjectPath is required for a noninteractive update.'}
  Add-Type -AssemblyName System.Windows.Forms
  $picker=New-Object System.Windows.Forms.FolderBrowserDialog
  $picker.Description='Select your CURRENT BattleZone_AndroidStudio folder (contains app and settings.gradle).'
  $picker.ShowNewFolderButton=$false
  $picker.SelectedPath=[Environment]::GetFolderPath('Desktop')
  if($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){Write-Host 'CANCELLED - nothing was changed.';exit 2}
  $ProjectPath=$picker.SelectedPath
 }
 $ProjectPath=$ProjectPath.Trim().Trim('"')
 if(-not (IsProject $ProjectPath)){throw 'Project folder not found. Select the folder with app and settings.gradle.'}
 $ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
 $Web=Join-Path $ProjectPath 'app/src/main/assets/web';$Game=Join-Path $Web 'game.js'
 $Payload=Join-Path $PSScriptRoot 'payload/drawMarks.js'
 if(-not (Test-Path -LiteralPath $Payload)){throw 'Extract the entire update ZIP first. payload/drawMarks.js is missing.'}
 $Original=[IO.File]::ReadAllBytes($Game);$OriginalHash=BytesHash $Original;$Code=$Utf8.GetString($Original)
 if(-not $Code.Contains('BattleZoneInput') -or -not $Code.Contains('function isImpact(') -or -not $Code.Contains('function circle(')){
  throw 'This is not the expected BattleZone drawing engine. Nothing was changed.'
 }
 $span=FunctionSpan $Code
 $NewFunction=$Utf8.GetString([IO.File]::ReadAllBytes($Payload)).Trim()
 if(-not $NewFunction.Contains('BZ_SMALL_IMPACT_V1')){throw 'Invalid update payload.'}
 $payloadSpan=FunctionSpan $NewFunction
 if($payloadSpan.Start -ne 0 -or $payloadSpan.Length -ne $NewFunction.Length){throw 'Unexpected content outside drawing function.'}
 $newline=if($Code.Contains("`r`n")){"`r`n"}else{"`n"}
 $NewFunction=[regex]::Replace($NewFunction,"`r?`n",$newline)
 $prefix=$Code.Substring(0,$span.Start);$suffix=$Code.Substring($span.Start+$span.Length)
 $Updated=$prefix+$NewFunction+$suffix
 $UpdatedBytes=$Utf8.GetBytes($Updated)
 if((BytesHash $UpdatedBytes) -eq $OriginalHash){Write-Host 'ALREADY APPLIED - rebuild the APK from this project.' -ForegroundColor Green;Write-Host $ProjectPath;exit 0}
 # Verify that the new file differs exclusively inside the one drawing function.
 $newSpan=FunctionSpan $Updated
 if($Updated.Substring(0,$newSpan.Start) -cne $prefix -or $Updated.Substring($newSpan.Start+$newSpan.Length) -cne $suffix){throw 'Function-boundary check failed. Nothing was changed.'}
 $Protected=@{}
 Get-ChildItem -LiteralPath $Web -File -Recurse | Where-Object {$_.FullName -ne $Game} | ForEach-Object {$Protected[$_.FullName]=Hash $_.FullName}
 foreach($rel in @('app/build.gradle','settings.gradle','gradle.properties','keystore.properties','app/src/main/AndroidManifest.xml')){
  $p=Join-Path $ProjectPath $rel;if(Test-Path -LiteralPath $p){$Protected[$p]=Hash $p}
 }
 $stamp=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)
 $backup=Join-Path $ProjectPath ('.shot-size-backups/'+$stamp)
 New-Item -ItemType Directory -Path $backup -Force | Out-Null
 [IO.File]::WriteAllBytes((Join-Path $backup 'game.js'),$Original)
 $temp=$Game+'.'+$stamp+'.tmp';$written=$false
 try{
  [IO.File]::WriteAllBytes($temp,$UpdatedBytes)
  if((Hash $Game) -ne $OriginalHash){throw 'The game file changed during installation. Close the editor and retry.'}
  [IO.File]::Replace($temp,$Game,(Join-Path $backup 'game.atomic.bak'));$written=$true
  if((Hash $Game) -ne (BytesHash $UpdatedBytes)){throw 'Write verification failed.'}
  foreach($p in $Protected.Keys){if((Hash $p) -ne $Protected[$p]){throw 'Another file changed while updating. The drawing change was rolled back.'}}
 }catch{
  if($written){[IO.File]::WriteAllBytes($Game,$Original)}
  throw
 }finally{Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue}
 [IO.File]::WriteAllText((Join-Path $backup 'verification.txt'),('ONLY drawMarks changed.'+"`r`n"+'Before SHA256: '+$OriginalHash+"`r`n"+'After SHA256: '+(Hash $Game)+"`r`n"+'Other checked files unchanged: '+$Protected.Count),$Utf8)
 Write-Host 'APPLIED - small target-scale markers and numbers.' -ForegroundColor Green
 Write-Host ('Project: '+$ProjectPath)
 Write-Host ('Backup: '+$backup)
 Write-Host 'ONLY the drawMarks function changed. All other game functions and files are unchanged.'
 Write-Host 'Next: run BUILD_DEBUG_APK.cmd in this same project and install the newly built APK.'
 exit 0
}catch{Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red;exit 1}
