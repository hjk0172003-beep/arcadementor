@echo off
setlocal
title BattleZone - Button Sound and No Time Limits
echo.
echo BattleZone update: button confirmation sound + remove both time limits
echo Your existing project and signing settings are kept.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply_Update.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (
  echo Update ready. Rebuild your APK using the existing BUILD_DEBUG_APK.cmd.
) else (
  echo Update failed. Do not delete the existing project. Read the error above.
)
echo.
pause
exit /b %RESULT%
