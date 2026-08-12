@echo off
setlocal
call "%~dp0Setup.cmd"
set "MOD_EXIT=%ERRORLEVEL%"
exit /b %MOD_EXIT%
