@echo off
setlocal
title BattleZone - Button Sound Update
echo.
echo BattleZone button sound update
echo This keeps your current game and Android Studio settings.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply_ButtonSound.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (
  echo Update finished. Rebuild your APK using BUILD_DEBUG_APK.cmd in your project.
) else (
  echo Update failed. Read the error above. Do not delete your existing project.
)
echo.
pause
exit /b %RESULT%
