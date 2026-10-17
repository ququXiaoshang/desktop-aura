@echo off
setlocal
set "PS=%~dp0restore-all.ps1"
if not exist "%PS%" set "PS=%~dp0scripts\restore-all.ps1"
if not exist "%PS%" (
  echo [error] restore-all.ps1 not found next to this file.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%"
echo.
echo Done. System desktop icons restored, autostart removed.
pause
