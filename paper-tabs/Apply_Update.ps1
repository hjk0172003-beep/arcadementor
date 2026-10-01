param([string]$ProjectPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Utf8=New-Object System.Text.UTF8Encoding($false,$true)

function Is-Project([string]$P){
 if([string]::IsNullOrWhiteSpace($P)){return $false}
 return (Test-Path -LiteralPath (Join-Path $P 'settings.gradle') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $P 'app/src/main/assets/web/index.html') -PathType Leaf)
}
function Hash([string]$P){return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash}

try{
 if([string]::IsNullOrWhiteSpace($ProjectPath)){
  Add-Type -AssemblyName System.Windows.Forms
  $dlg=New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description='지금 APK를 만드는 BattleZone_AndroidStudio 폴더를 선택하세요.'
  $dlg.ShowNewFolderButton=$false
  if($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){Write-Host 'CANCELLED - 아무것도 변경하지 않았습니다.';exit 2}
  $ProjectPath=$dlg.SelectedPath
 }
 $ProjectPath=$ProjectPath.Trim().Trim('"')
 if(-not(Is-Project $ProjectPath)){throw 'app 폴더와 settings.gradle이 있는 BattleZone_AndroidStudio 폴더를 선택하세요.'}
 $ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
 $Web=Join-Path $ProjectPath 'app/src/main/assets/web'
 $Index=Join-Path $Web 'index.html'
 $Target=Join-Path $Web 'bz-paper-tabs.js'
 $Source=Join-Path $PSScriptRoot 'payload/bz-paper-tabs.js'
 if(-not(Test-Path -LiteralPath $Source)){throw 'ZIP 전체를 압축 해제한 뒤 다시 실행하세요.'}
 $Original=[IO.File]::ReadAllBytes($Index)
 $Html=$Utf8.GetString($Original)
 if(-not $Html.Contains('id="setup"')){throw '게임 메뉴 구조를 확인할 수 없습니다.'}
 $Tag='<script id="bz-paper-tabs-script" src="bz-paper-tabs.js"></script>'
 if(-not $Html.Contains($Tag)){
  $m=[regex]::Matches($Html,'(?i)</body\s*>')
  if($m.Count -ne 1){throw 'index.html 구조가 예상과 다릅니다.'}
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
  foreach($p in $protected.Keys){if((Hash $p) -ne $protected[$p]){throw '다른 게임 파일 변경이 감지되었습니다.'}}
 }catch{
  [IO.File]::WriteAllBytes($Index,$Original)
  if(Test-Path -LiteralPath (Join-Path $backup 'bz-paper-tabs.js')){Copy-Item -LiteralPath (Join-Path $backup 'bz-paper-tabs.js') -Destination $Target -Force}else{Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue}
  throw
 }
 Write-Host 'APPLIED - 흰색 삭제 / 색상 1 / 색상 2로 정리 완료.' -ForegroundColor Green
 Write-Host ('Project: '+$ProjectPath)
 Write-Host ('Backup: '+$backup)
 Write-Host '기존 표적 색상 기능과 다른 게임 기능은 그대로 유지합니다.'
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 exit 1
}