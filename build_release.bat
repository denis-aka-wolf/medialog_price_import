@echo off
setlocal
flutter pub get
if errorlevel 1 exit /b 1
flutter build windows --release
if errorlevel 1 exit /b 1
echo.
echo Build complete: build\windows\x64\runner\Release
