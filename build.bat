@echo off
setlocal enabledelayedexpansion
title Building JA Remote Release...
cd /d %~dp0

echo ========================================================
echo   Building JA Remote Windows Release (x64)
echo ========================================================

taskkill /IM ja_remote.exe /F 2>nul

echo [1/5] Compiling Flutter Windows Desktop (Release mode)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Release build failed with error code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

set REL=build\windows\x64\runner\Release
set DIST=dist
set PACK=dist_pack
set APP_NAME=JA_Remote

:: Extract app version from pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr /r "^version:" pubspec.yaml') do (
    for /f "tokens=1 delims=+" %%v in ("%%a") do set APP_VERSION=%%v
)
if "%APP_VERSION%"=="" set APP_VERSION=1.3.0

set ZIP_NAME=%APP_NAME%_v%APP_VERSION%_Windows_x64.zip
set STAGING_NAME=%APP_NAME%_v%APP_VERSION%_Windows_x64

echo [2/5] Cleaning runtime junk from Release...
if exist "%REL%\logs" rmdir /s /q "%REL%\logs"
if exist "%REL%\config.json" del /f /q "%REL%\config.json"
if exist "%REL%\config.ini" del /f /q "%REL%\config.ini"

echo [3/5] Copying accessories into Release folder...
if exist debug.bat copy /y debug.bat "%REL%\" >nul
if exist install.bat copy /y install.bat "%REL%\" >nul
if exist uninstall.bat copy /y uninstall.bat "%REL%\" >nul
if exist uninstall.ps1 copy /y uninstall.ps1 "%REL%\" >nul
if exist ABOUT.txt copy /y ABOUT.txt "%REL%\" >nul
if exist README.md copy /y README.md "%REL%\" >nul
if exist CHANGELOG.md copy /y CHANGELOG.md "%REL%\" >nul
if exist USERGUIDE.md copy /y USERGUIDE.md "%REL%\" >nul
if exist LICENSE copy /y LICENSE "%REL%\" >nul
if exist bin xcopy /e /i /y /q bin "%REL%\bin\" >nul
if exist assets xcopy /e /i /y /q assets "%REL%\assets\" >nul
if exist i18n xcopy /e /i /y /q i18n "%REL%\i18n\" >nul

echo [4/5] Unpacking application files directly into dist/...
if not exist "%DIST%" mkdir "%DIST%"
powershell -NoProfile -Command "Get-ChildItem -Path '%DIST%' -Exclude '*.zip' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
xcopy /e /i /y /q "%REL%\*.*" "%DIST%\" >nul

echo [5/5] Packaging release ZIP with parent folder (%STAGING_NAME%)...
if exist "%PACK%" rmdir /s /q "%PACK%"
mkdir "%PACK%\%STAGING_NAME%"
xcopy /e /i /y /q "%DIST%\*.*" "%PACK%\%STAGING_NAME%\" >nul
if exist "%PACK%\%STAGING_NAME%\*.zip" del /f /q "%PACK%\%STAGING_NAME%\*.zip"

powershell -NoProfile -Command "Compress-Archive -Path '%PACK%\*' -DestinationPath '%DIST%\%ZIP_NAME%' -Force"
if exist "%PACK%" rmdir /s /q "%PACK%"

:: Delete obsolete zip files
powershell -NoProfile -Command "Get-ChildItem -Path '%DIST%' -Filter '*.zip' | Where-Object { $_.Name -ne '%ZIP_NAME%' } | Remove-Item -Force"

:: Metadata
powershell -NoProfile -Command "$hash = (Get-FileHash -Path '%DIST%\%ZIP_NAME%' -Algorithm SHA256).Hash.ToLower(); Set-Content -Path '%DIST%\SHA256SUMS.txt' -Value \"$hash *%ZIP_NAME%\"; $date = (Get-Date -Format 'yyyy-MM-dd'); $json = [ordered]@{ version = '%APP_VERSION%'; fileName = '%ZIP_NAME%'; sha256 = $hash; releaseDate = $date; releaseNotes = 'Release v%APP_VERSION%' } | ConvertTo-Json -Depth 4; Set-Content -Path '%DIST%\version.json' -Value $json -Encoding UTF8"
if exist RELEASE_NOTES.md copy /y RELEASE_NOTES.md "%DIST%\" >nul

echo.
echo ========================================================
echo   BUILD COMPLETED SUCCESSFULLY!
echo   Unpacked app and %ZIP_NAME% are ready in %DIST%\
echo ========================================================
echo.
