@echo off
setlocal
title BattleZone - Menu and Logo Update
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Apply_Update.ps1" %*
if errorlevel 1 (
  echo.
  echo UPDATE FAILED - keep this window open and send a screenshot.
) else (
  echo.
  echo Next: run BUILD_DEBUG_APK.cmd in your existing game project.
)
pause
