@echo off
setlocal
title BattleZone - Menu BGM Update
cd /d "%~dp0"
if not exist "%~dp0Apply_MenuBGM.ps1" (
  echo Extract the entire ZIP before running this file.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Apply_MenuBGM.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo UPDATE FAILED - do not delete your existing project. Send a screenshot of this window.
pause
exit /b %RESULT%
