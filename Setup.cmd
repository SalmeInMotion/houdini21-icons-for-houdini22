@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Setup.ps1"
set "MOD_EXIT=%ERRORLEVEL%"
if not "%MOD_EXIT%"=="0" (
    echo.
    echo Setup failed with exit code %MOD_EXIT%.
    pause
)
exit /b %MOD_EXIT%
