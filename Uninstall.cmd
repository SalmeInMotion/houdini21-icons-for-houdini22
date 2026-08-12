@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
set "MOD_EXIT=%ERRORLEVEL%"
echo.
if not "%MOD_EXIT%"=="0" echo Uninstall failed with exit code %MOD_EXIT%.
pause
exit /b %MOD_EXIT%
