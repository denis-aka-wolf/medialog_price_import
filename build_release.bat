@echo off
setlocal

echo ========================================
echo Medialog Price Import - Release Build
echo ========================================
echo.

echo [1/2] Resolving dependencies...
call flutter pub get

if errorlevel 1 (
    echo.
    echo ERROR: Failed to resolve dependencies!
    pause
    exit /b 1
)

echo.
echo [2/2] Building Windows Release...
call flutter build windows --release

if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo BUILD COMPLETE!
echo ========================================
echo.
echo Output:
echo build\windows\x64\runner\Release
echo.

pause