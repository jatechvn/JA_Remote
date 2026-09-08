@echo off
cd /d %~dp0

:: 1. If running inside the Release/Debug folder where the .exe sits directly:
for %%i in (*.exe) do (
    start "" "%%i" -debug
    exit
)

:: 2. If running from the workspace root, check compiled binary:
if exist "build\windows\x64\runner\Release\ja_remote.exe" (
    start "" "build\windows\x64\runner\Release\ja_remote.exe" -debug
    exit
)

if exist "build\windows\x64\runner\Debug\ja_remote.exe" (
    start "" "build\windows\x64\runner\Debug\ja_remote.exe" -debug
    exit
)

:: 3. Fallback: Run via Flutter CLI passing -debug argument
echo Running in debug mode (-debug)...
flutter run -d windows -- -debug
