@echo off
REM Chharizard-LAC -> Phoenix XI deployment wrapper (double-click friendly)
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0DEPLOY-TO-PHOENIX.ps1"
echo.
pause
