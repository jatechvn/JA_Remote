@echo off
title Building JA Remote Release...
cd /d %~dp0
echo ========================================================
echo   Building JA Remote Windows Release (x64)
echo ========================================================

call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Release build failed with error code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [1/3] Copying debug.bat to Release folder...
if exist debug.bat (
    copy /y debug.bat "build\windows\x64\runner\Release\" >nul
)

echo [2/3] Creating .Release.lnk shortcut at workspace root...
powershell -NoProfile -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('.Release.lnk'); $Shortcut.TargetPath = Join-Path (Get-Item .).FullName 'build\windows\x64\runner\Release'; $Shortcut.Save()"

echo [3/3] Build complete!
echo Output directory: build\windows\x64\runner\Release\
echo Shortcut created: .Release.lnk
echo.
pause
