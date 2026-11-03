@echo off
setlocal
flutter pub get
if errorlevel 1 exit /b 1
flutter run -d windows
