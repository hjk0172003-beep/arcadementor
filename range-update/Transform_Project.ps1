# Pure text transformations only. No files are written by this module.
Set-StrictMode -Version 2.0
function Replace-One([string]$Text,[string]$Pattern,[string]$Replacement,[string]$Label) {
    $Rx = New-Object System.Text.RegularExpressions.Regex($Pattern)
    if ($Rx.Matches($Text).Count -ne 1) { throw ('Unexpected project structure: ' + $Label + '. Nothing was changed.') }
    $Match = $Rx.Match($Text)
    return $Text.Remove($Match.Index,$Match.Length).Insert($Match.Index,$Replacement)
}
function Get-BattleZoneUpdate([string]$Html,[string]$Game) {
    $Marker = '/* BZ_UNTIMED_TARGETS_V1 */'
    if (-not $Html.Contains('id="stage"') -or -not $Game.Contains('BattleZoneInput') -or -not $Game.Contains('startGameButton')) {
        throw 'Not the expected BattleZone Android Studio project. Nothing was changed.'
    }
    $NewLine = if ($Html.Contains("`r`n")) { "`r`n" } else { "`n" }
    if (-not $Game.Contains($Marker)) {
        # Remove both complete setting rows, not merely their labels or styling.
        $TotalPanel = '(?s)<div\s+class="settingLabel">[^<]*<span>[^<]*</span></div>\s*<div\s+class="stepper">\s*<button\s+id="totalNone"[^>]*>.*?</div>'
        $ShotPanel = '(?s)<div\s+class="settingLabel">[^<]*<span>[^<]*</span></div>\s*<div\s+class="stepper">\s*<button\s+id="shotNone"[^>]*>.*?</div>'
        $ClockRow = '(?s)<div\s+class="timerRow">(?:(?!</div>).)*\bid="totalClock"(?:(?!</div>).)*\bid="shotClock"(?:(?!</div>).)*</div>'
        $Html = Replace-One $Html $TotalPanel '' 'total-time setting row'
        $Html = Replace-One $Html $ShotPanel '' 'per-shot-time setting row'
        $Html = Replace-One $Html $ClockRow '' 'live countdown row'
        # Remove references to those deleted controls.
        $SetupClock = '(?m)^[ \t]*\$\(''totalValue''\)\.textContent=[^\r\n]*\$\(''shotValue''\)[^\r\n]*selectStyle\(\$\(''shotNone''\),!settings\.shotLimit\);[ \t]*\r?$'
        $Game = Replace-One $Game $SetupClock '' 'time-setting renderer'
        $BindSteps = '(?m)^for\(const \[id,key,step\] of \[\[''totalMinus''[^\r\n]*\]\)bind\(id,[^\r\n]*\);[ \t]*\r?$'
        $Game = Replace-One $Game $BindSteps '' 'time +/- bindings'
        $BindNone = '(?m)^bind\(''totalNone''[^\r\n]*bind\(''shotNone''[^\r\n]*\);[ \t]*\r?$'
        $Game = Replace-One $Game $BindNone '' 'no-time-limit bindings'
        $ClockFunction = '(?m)^function renderClocks\(\)\{[^\r\n]*\}[ \t]*\r?$'
        $Game = Replace-One $Game $ClockFunction 'function renderClocks(){}' 'countdown renderer'
        # Delete the timeout and automatic match-ending branches themselves.
        # Elapsed timestamps are preserved for records and replays; they no longer impose a limit.
        $ShotCheck = 'if\(session\.config\.shotLimit&&[^{}\r\n]*\)\{[^{}\r\n]*\}'
        $TotalCheck = 'if\(session\.config\.totalLimit&&[^{}\r\n]*\)\{[^{}\r\n]*\}'
        $Game = Replace-One $Game $ShotCheck '' 'per-shot timeout branch'
        $Game = Replace-One $Game $TotalCheck '' 'total-time match-ending branch'
        $Game = Replace-One $Game 'function renderSetup\(\)\{' 'function renderSetup(){settings.shotLimit=0;settings.totalLimit=0;' 'neutralize remembered limits'
        $Game = Replace-One $Game 'const sessionConfig\s*=\s*clone\(settings\);' 'const sessionConfig=clone(settings);sessionConfig.shotLimit=0;sessionConfig.totalLimit=0;' 'new-session time limits'
        $Game += $NewLine + $Marker + $NewLine
    }
    # A cancelled timeout-zero-score request must not survive in the runtime.
    if ($Game -match 'if\s*\(\s*session\.config\.(shotLimit|totalLimit)' -or $Game -match 'effect\([''"]timeout[''"]\)') {
        throw 'An unrecognized timeout handler remains. Nothing was changed.'
    }
    foreach ($Id in @('totalNone','totalMinus','totalPlus','totalValue','shotNone','shotMinus','shotPlus','shotValue','totalClock','shotClock')) {
        if ($Html.Contains('id="'+$Id+'"') -or $Game.Contains("$('"+$Id+"')")) {
            throw ('A removed time control is still referenced: '+$Id+'. Nothing was changed.')
        }
    }
    $Tag = '<script id="bz-button-feedback" src="ui-button-sound.js"></script>'
    if (-not $Html.Contains('id="bz-button-feedback"')) {
        $Html = Replace-One $Html '(?i)</body\s*>' ($Tag+$NewLine+'</body>') 'button sound insertion point'
    } elseif (-not $Html.Contains($Tag)) {
        throw 'Unrecognized previous button sound installation. Nothing was changed.'
    }
    return @{Html=$Html;Game=$Game}
}
