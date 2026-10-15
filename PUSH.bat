@echo off
cd /d "%~dp0"
echo === ChharLAC push ===
git status
echo.
git push
echo.
pause
