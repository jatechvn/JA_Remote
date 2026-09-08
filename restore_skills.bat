@echo off
title Khôi Phục AI Skills & Rules
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_skills.ps1"
pause
