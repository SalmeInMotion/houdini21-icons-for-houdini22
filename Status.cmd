@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Status.ps1" -VerifyFiles
set "MOD_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %MOD_EXIT%
