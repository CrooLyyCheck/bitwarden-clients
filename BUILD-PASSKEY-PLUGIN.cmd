@echo off
setlocal
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\Build-Bitwarden-PasskeyPlugin.ps1" %*
if errorlevel 1 (
  echo.
  echo Build nie powiodl sie. Szczegoly znajduja sie powyzej.
  exit /b 1
)
echo.
echo Build zakonczony powodzeniem.
