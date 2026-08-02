@echo off
setlocal
cd /d "%~dp0"
start "TrackerRadar" powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0TrackerRadar.App.ps1"
endlocal
