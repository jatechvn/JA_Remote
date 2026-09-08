@echo off
cd /d %~dp0

set /p commit_msg="Enter commit message (default 'Update JA Remote'): "
if "%commit_msg%"=="" set commit_msg=Update JA Remote

if not exist ".git" (
    git init
    git branch -M main
)

git add .
git commit -m "%commit_msg%"
git status
pause
