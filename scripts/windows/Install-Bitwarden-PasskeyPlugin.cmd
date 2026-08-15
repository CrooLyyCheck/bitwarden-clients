@echo off
setlocal
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Bitwarden-PasskeyPlugin.ps1"
echo.
pause
