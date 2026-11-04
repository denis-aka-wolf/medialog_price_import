@echo off
setlocal

pushd "%~dp0"
if errorlevel 1 (
    echo.
    echo ERROR: Failed to enter project directory!
    pause
    exit /b 1
)

echo ========================================
echo Medialog Price Import - Release Build
echo ========================================
echo.

echo [1/3] Resolving dependencies...
call flutter pub get

if errorlevel 1 goto error_dependencies

echo.
echo [2/3] Incrementing local build number...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $buildFile = 'build.txt'; $pubspecFile = 'pubspec.yaml'; if (Test-Path $buildFile) { $buildText = [System.IO.File]::ReadAllText($buildFile).Trim(); if ($buildText -notmatch '^\d+$') { throw 'build.txt contains an invalid build number.' }; $buildNum = [long]$buildText } else { $pubspecText = [System.IO.File]::ReadAllText($pubspecFile); $match = [regex]::Match($pubspecText, '(?m)^version:[ \t]*\d+\.\d+\.\d+(?:\+(\d+))?[ \t]*(?:#.*)?$'); if (-not $match.Success) { throw 'Could not find a valid version in pubspec.yaml.' }; if ($match.Groups[1].Success) { $buildNum = [long]$match.Groups[1].Value } else { $buildNum = 0 } }; if ($buildNum -ge [long]::MaxValue) { throw 'Build number limit reached.' }; $newBuildNum = $buildNum + 1; $utf8 = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($buildFile, [string]$newBuildNum, $utf8); Write-Host ('Build number: ' + $newBuildNum) } catch { Write-Host ('ERROR: ' + $_.Exception.Message); exit 1 }"

if errorlevel 1 goto error_build_number

echo.
echo [3/3] Building Windows Release...
call flutter build windows --release

if errorlevel 1 goto error_build

echo.
echo ========================================
echo BUILD COMPLETE!
echo ========================================
echo.
echo Output:
echo build\windows\x64\runner\Release
echo.

pause
exit /b 0

:error_dependencies
echo.
echo ERROR: Failed to resolve dependencies!
goto fail

:error_build_number
echo.
echo ERROR: Failed to update build.txt!
goto fail

:error_build
echo.
echo ERROR: Build failed!
goto fail

:fail
pause
exit /b 1