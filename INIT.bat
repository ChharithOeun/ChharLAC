@echo off
setlocal
REM ChharLAC — one-click git init + first commit + push to github.com/ChharithOeun/ChharLAC
cd /d "%~dp0"

if exist ".git" (
    echo Git repo already initialized here.
    git status
    git log --oneline -5
    goto end
)

echo Initializing git repo for ChharLAC...
git init
git branch -M main

echo Staging all files...
git add .

echo Creating initial commit...
git commit -m "Initial commit: ChharLAC v1.0.0 — 22 LuAshitaCast profiles + shared subjob automation library (Horizon XI, Phoenix XI, retail)"

echo Adding GitHub remote...
git remote add origin https://github.com/ChharithOeun/ChharLAC.git

echo Pushing to main...
git push -u origin main

:end
echo.
pause
