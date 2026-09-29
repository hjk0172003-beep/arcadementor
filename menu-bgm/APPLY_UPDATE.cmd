@echo off
setlocal
echo BattleZone - mode selection background music
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0APPLY_BGM.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Update was not completed. Read the message above before rebuilding.
pause
exit /b %RESULT%
