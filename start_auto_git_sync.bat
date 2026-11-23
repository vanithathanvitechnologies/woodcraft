@echo off
title WoodCraft Auto Git Sync
echo Watching %~dp0 for changes and auto-pushing to GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\auto_git_sync.ps1"
pause
