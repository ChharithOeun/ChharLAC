@echo off
REM One-click: scrape every NM on BG-Wiki + FFXIclopedia into ph_database.lua.
REM Just double-click this file.  Takes 20-40 min, safe to re-run.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WIKI-SCRAPE.ps1" -All
echo.
echo === Scrape complete.  Reload chhartarget in-game to pick up new entries:
echo     /addon reload chhartarget
echo.
pause
