@echo off
setlocal
title BattleZone - Paper Color Tabs
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Apply_Update.ps1" %*
set "R=%ERRORLEVEL%"
echo.
if "%R%"=="0" (
  echo Update finished. Rebuild the APK from the SAME project.
) else if "%R%"=="2" (
  echo Cancelled. No changes made.
) else (
  echo Update failed. Keep this window open and send a screenshot.
)
pause
exit /b %R%
