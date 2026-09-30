@echo off
setlocal
title BattleZone - Small Shot Markers
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Apply_Update.ps1" %*
set "BZ_RESULT=%ERRORLEVEL%"
if "%BZ_RESULT%"=="0" (
  echo.
  echo Rebuild the APK in the project you selected, then install the NEW APK.
) else (
  if "%BZ_RESULT%"=="2" (
    echo Cancelled. No changes made.
  ) else (
    echo.
    echo UPDATE FAILED. Keep this window open and send a screenshot.
  )
)
pause
exit /b %BZ_RESULT%
