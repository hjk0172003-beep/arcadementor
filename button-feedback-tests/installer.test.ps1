$ErrorActionPreference = 'Stop'
$Source = (Resolve-Path (Join-Path $PSScriptRoot '../button-feedback')).Path
$Root = Join-Path ([IO.Path]::GetTempPath()) ('bz-button-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root | Out-Null
$Results = New-Object System.Collections.Generic.List[object]
function Assert-True($Condition,[string]$Message) { if (-not $Condition) { throw $Message }; $Results.Add(@{label=$Message;passed=$true}) }
function SHA([string]$File) { return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash }
function Fixture([string]$Name, [bool]$Bom=$false) {
    $Project=Join-Path $Root $Name
    $Web=Join-Path $Project 'app/src/main/assets/web'
    New-Item -ItemType Directory -Path $Web -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $Project 'settings.gradle'),'// fixture')
    [IO.File]::WriteAllText((Join-Path $Project 'signing.properties'),'fixture-key-do-not-change')
    $Utf=New-Object System.Text.UTF8Encoding($Bom)
    $Html="<!doctype html>`r`n<html><body><div id=`"stage`"></div><script src=`"game.js`"></script></body></html>`r`n"
    [IO.File]::WriteAllText((Join-Path $Web 'index.html'),$Html,$Utf)
    [IO.File]::WriteAllText((Join-Path $Web 'game.js'),'/* Test fixture only. BattleZoneInput startGameButton */',$Utf)
    [IO.File]::WriteAllBytes((Join-Path $Web 'voice.mp3'),[byte[]](1,3,5,7,9,11,13))
    return $Project
}
function Apply([string]$Project) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Source 'Apply_ButtonSound.ps1') -ProjectPath $Project 2>&1 | ForEach-Object { Write-Host $_ }
    return $LASTEXITCODE
}
try {
    foreach($WithBom in @($false,$true)) {
        $Project=Fixture ('project with spaces '+$WithBom) $WithBom
        $Web=Join-Path $Project 'app/src/main/assets/web'
        $Index=Join-Path $Web 'index.html'
        $IndexBefore=SHA $Index
        $GameBefore=SHA (Join-Path $Web 'game.js')
        $AudioBefore=SHA (Join-Path $Web 'voice.mp3')
        $SigningBefore=SHA (Join-Path $Project 'signing.properties')
        $Original=[IO.File]::ReadAllText($Index)
        $Code=Apply $Project
        Assert-True ($Code -eq 0) ('Apply succeeds; BOM='+$WithBom)
        $New=[IO.File]::ReadAllText($Index)
        $Tag='<script id="bz-button-feedback" src="ui-button-sound.js"></script>'+"`r`n"
        Assert-True ($New.Replace($Tag,'') -ceq $Original) ('Only one additive script tag changes index; BOM='+$WithBom)
        Assert-True ((SHA (Join-Path $Web 'game.js')) -eq $GameBefore) ('Game JS unchanged; BOM='+$WithBom)
        Assert-True ((SHA (Join-Path $Web 'voice.mp3')) -eq $AudioBefore) ('Audio asset unchanged; BOM='+$WithBom)
        Assert-True ((SHA (Join-Path $Project 'signing.properties')) -eq $SigningBefore) ('Signing metadata unchanged; BOM='+$WithBom)
        Assert-True ((SHA (Join-Path $Web 'ui-button-sound.js')) -eq (SHA (Join-Path $Source 'ui-button-sound.js'))) ('Add-on copied exactly; BOM='+$WithBom)
        $Backups=@(Get-ChildItem -LiteralPath (Join-Path $Project '.button-sound-backups') -Directory)
        Assert-True ($Backups.Count -eq 1) ('Automatic original backup created; BOM='+$WithBom)
        Assert-True ((SHA (Join-Path $Backups[0].FullName 'index.html')) -eq $IndexBefore) ('Backup bytes unchanged; BOM='+$WithBom)
        $AfterHash=SHA $Index
        $Code=Apply $Project
        Assert-True ($Code -eq 0) ('Second installation safely succeeds; BOM='+$WithBom)
        Assert-True ((SHA $Index) -eq $AfterHash) ('No duplicate install or tag; BOM='+$WithBom)
    }
    $Project=Fixture 'incompatible'
    $Game=Join-Path $Project 'app/src/main/assets/web/game.js'
    [IO.File]::WriteAllText($Game,'Different application')
    $Index=Join-Path $Project 'app/src/main/assets/web/index.html'
    $Before=SHA $Index
    $Code=Apply $Project
    Assert-True ($Code -ne 0) 'Incompatible game is refused'
    Assert-True ((SHA $Index) -eq $Before) 'Incompatible game is not modified'
    $Project=Fixture 'collision'
    $Web=Join-Path $Project 'app/src/main/assets/web'
    [IO.File]::WriteAllText((Join-Path $Web 'ui-button-sound.js'),'Unknown existing file')
    $Before=SHA (Join-Path $Web 'index.html')
    $Code=Apply $Project
    Assert-True ($Code -ne 0) 'Unknown existing add-on is refused'
    Assert-True ((SHA (Join-Path $Web 'index.html')) -eq $Before) 'Collision leaves index unchanged'
    Assert-True ([IO.File]::ReadAllText((Join-Path $Web 'ui-button-sound.js')) -ceq 'Unknown existing file') 'Collision preserves existing add-on'
    New-Item -ItemType Directory -Path 'test-results' -Force | Out-Null
    @{scope='Windows PowerShell 5.1 installer against non-proprietary fixtures';passed=$Results.Count;results=$Results} | ConvertTo-Json -Depth 10 | Set-Content 'test-results/installer.json' -Encoding UTF8
    Write-Host ('INSTALLER CHECKS PASSED: '+$Results.Count)
} finally { Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue }
