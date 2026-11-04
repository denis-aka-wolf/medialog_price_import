
@echo off
setlocal

pushd "%~dp0"

echo ========================================
echo Medialog Price Import - Debug Launch
echo ========================================
echo.

echo [1/3] Resolving dependencies...
call flutter pub get

if errorlevel 1 (
    echo.
    echo ERROR: Failed to resolve dependencies!
    pause
    popd
    exit /b 1
)

echo.
echo [2/3] Incrementing local build counter...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$buildFile = 'build.txt';" ^
        "$pubspecFile = 'pubspec.yaml';" ^
        "if (Test-Path $buildFile) {" ^
            "$text = [System.IO.File]::ReadAllText($buildFile).Trim();" ^
            "if ($text -notmatch '^\d+$') { throw 'Invalid build.txt format.' };" ^
            "[long]$build = $text;" ^
        "} else {" ^
            "if (-not (Test-Path $pubspecFile)) { throw 'pubspec.yaml not found.' };" ^
            "$content = [System.IO.File]::ReadAllText($pubspecFile);" ^
            "$pattern = '(?m)^version:[ \t]*\d+\.\d+\.\d+(?:\+(\d+))?[ \t]*(?:#.*)?$';" ^
            "$match = [regex]::Match($content, $pattern);" ^
            "if (-not $match.Success) { throw 'Invalid version in pubspec.yaml.' };" ^
            "$build = 0;" ^
            "if ($match.Groups[1].Success) { $build = [long]$match.Groups[1].Value };" ^
        "};" ^
        "if ($build -eq [long]::MaxValue) { throw 'Build number overflow.' };" ^
        "$newBuild = $build + 1;" ^
        "$encoding = New-Object System.Text.UTF8Encoding($false);" ^
        "[System.IO.File]::WriteAllText($buildFile, $newBuild.ToString() + [Environment]::NewLine, $encoding);" ^
        "Write-Host ('Build number: ' + $build + ' -> ' + $newBuild);" ^
    "} catch {" ^
        "[Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message);" ^
        "exit 1;" ^
    "}"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to increment build number!
    pause
    popd
    exit /b 1
)

echo.
echo [3/3] Starting Windows application...
echo.

call flutter run -d windows

if errorlevel 1 (
    echo.
    echo ERROR: Application launch failed!
    pause
    popd
    exit /b 1
)

echo.
echo ========================================
echo APPLICATION STOPPED
echo ========================================
pause

popd
exit /b 0
