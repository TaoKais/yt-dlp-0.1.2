@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\yt-list-lock.ps1" %*
exit /b %ERRORLEVEL%
