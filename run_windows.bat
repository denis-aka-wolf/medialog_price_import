@echo off
setlocal

echo ========================================
echo Medialog Price Import - Debug Launch
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
echo [2/2] Starting Windows application...
echo.

call flutter run -d windows

if errorlevel 1 (
    echo.
    echo ERROR: Application launch failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo APPLICATION STOPPED
echo ========================================
pause