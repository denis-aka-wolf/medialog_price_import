@echo off
chcp 65001 > nul
setlocal DisableDelayedExpansion

:: ============================================================
:: BUMP.BAT
:: Управление версиями Flutter-проекта и Git-коммитами
::
:: Использование:
:: bump.bat "Текст коммита" <x|y|z> [push]
::
:: x = Major
:: y = Minor
:: z = Patch
:: push = отправить коммиты на сервер
:: ============================================================

:: ------------------------------------------------------------
:: 0. Получение аргументов
:: ------------------------------------------------------------

set "COMMIT_MSG=%~1"
set "BUMP_TYPE=%~2"
set "PUSH_PARAM=%~3"

if not defined COMMIT_MSG goto :usage
if not defined BUMP_TYPE goto :usage

if /i "%BUMP_TYPE%"=="x" set "BUMP_TYPE=x"
if /i "%BUMP_TYPE%"=="y" set "BUMP_TYPE=y"
if /i "%BUMP_TYPE%"=="z" set "BUMP_TYPE=z"

if not "%BUMP_TYPE%"=="x" if not "%BUMP_TYPE%"=="y" if not "%BUMP_TYPE%"=="z" goto :usage

if not "%PUSH_PARAM%"=="" if /i not "%PUSH_PARAM%"=="push" goto :usage

:: ------------------------------------------------------------
:: 1. Проверка Git
:: ------------------------------------------------------------

git rev-parse --is-inside-work-tree > nul 2>&1

if errorlevel 1 (
    echo Ошибка: текущая директория не является Git-репозиторием.
    exit /b 1
)

:: ------------------------------------------------------------
:: 2. Подготовка временного файла для сообщения коммита
:: ------------------------------------------------------------

set "COMMIT_FILE=%TEMP%\bump_commit_%RANDOM%_%RANDOM%.txt"

set "BUMP_COMMIT_MSG=%COMMIT_MSG%"

:: ------------------------------------------------------------
:: 3. Добавление всех изменений
:: ------------------------------------------------------------

echo.
echo [1/9] Добавление изменений в Git...

git add -A

if errorlevel 1 goto :git_add_error

:: ------------------------------------------------------------
:: 4. Первый коммит
:: ------------------------------------------------------------

echo.
echo [2/9] Создание первоначального коммита...

powershell -NoProfile -Command ^
    "$message = [Environment]::GetEnvironmentVariable('BUMP_COMMIT_MSG');" ^
    "$encoding = [System.Text.UTF8Encoding]::new($false);" ^
    "[System.IO.File]::WriteAllText($env:COMMIT_FILE, $message + [Environment]::NewLine, $encoding);"

if errorlevel 1 goto :message_file_error

git -c i18n.commitEncoding=UTF-8 commit --cleanup=verbatim -F "%COMMIT_FILE%"

if errorlevel 1 goto :first_commit_error

:: ------------------------------------------------------------
:: 5. Получение SHA первоначального коммита
:: ------------------------------------------------------------

for /f "tokens=*" %%a in ('git rev-parse --short HEAD') do set "COMMIT_SHA=%%a"

if not defined COMMIT_SHA goto :sha_error

echo.
echo Создан коммит: %COMMIT_SHA%

:: ------------------------------------------------------------
:: 6. Обновление версий и changelog
:: ------------------------------------------------------------

echo.
echo [3-6/9] Обновление версий и changelog...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$versionFile = 'version.txt';" ^
        "$pubspecFile = 'pubspec.yaml';" ^
        "$changelogFile = 'changelog.md';" ^
        "$bumpType = $env:BUMP_TYPE;" ^
        "$sha = $env:COMMIT_SHA;" ^
        "$message = [Environment]::GetEnvironmentVariable('BUMP_COMMIT_MSG');" ^
        "$encoding = [System.Text.UTF8Encoding]::new($false);" ^
        "if (-not (Test-Path $pubspecFile)) { throw 'Файл pubspec.yaml не найден.' };" ^
        "$pubContent = [System.IO.File]::ReadAllText($pubspecFile);" ^
        "$pattern = '(?m)^version:[ \t]*(\d+\.\d+\.\d+)(?:\+(\d+))?[ \t]*(?:#.*)?$';" ^
        "$match = [regex]::Match($pubContent, $pattern);" ^
        "if (-not $match.Success) { throw 'Не найдена корректная версия в pubspec.yaml.' };" ^
        "$pubVersion = $match.Groups[1].Value;" ^
        "$buildText = $match.Groups[2].Value;" ^
        "if ([string]::IsNullOrEmpty($buildText)) { $buildText = '0' };" ^
        "if (Test-Path $versionFile) {" ^
            "$current = [System.IO.File]::ReadAllText($versionFile).Trim();" ^
            "if ($current -notmatch '^\d+\.\d+\.\d+$') { throw 'Некорректный формат версии в version.txt. Ожидается X.Y.Z.' };" ^
        "} else {" ^
            "$current = $pubVersion;" ^
            "Write-Output ('version.txt отсутствует. Используем версию из pubspec.yaml: ' + $current);" ^
        "};" ^
        "$parts = $current.Split('.');" ^
        "[long]$major = $parts[0];" ^
        "[long]$minor = $parts[1];" ^
        "[long]$patch = $parts[2];" ^
        "switch ($bumpType) {" ^
            "'x' { $major++; $minor = 0; $patch = 0 }" ^
            "'y' { $minor++; $patch = 0 }" ^
            "'z' { $patch++ }" ^
            "default { throw 'Неизвестный тип изменения версии.' }" ^
        "};" ^
        "$newVersion = '{0}.{1}.{2}' -f $major, $minor, $patch;" ^
        "[long]$buildNum = [long]$buildText + 1;" ^
        "$newPubVersion = 'version: {0}+{1}' -f $newVersion, $buildNum;" ^
        "$rx = [regex]::new($pattern);" ^
        "$pubContent = $rx.Replace($pubContent, $newPubVersion, 1);" ^
        "[System.IO.File]::WriteAllText($pubspecFile, $pubContent, $encoding);" ^
        "[System.IO.File]::WriteAllText($versionFile, $newVersion + [Environment]::NewLine, $encoding);" ^
        "$date = Get-Date -Format 'yyyy-MM-dd';" ^
        "$nl = [Environment]::NewLine;" ^
        "$newEntry = '## [' + $newVersion + '] - ' + $date + ' (' + $sha + ')' + $nl + '* ' + $message + $nl + $nl;" ^
        "if (Test-Path $changelogFile) { $oldContent = [System.IO.File]::ReadAllText($changelogFile) } else { $oldContent = '' };" ^
        "[System.IO.File]::WriteAllText($changelogFile, $newEntry + $oldContent, $encoding);" ^
        "Write-Output ('Версия проекта: ' + $current + ' -> ' + $newVersion);" ^
        "Write-Output ('Flutter version: ' + $newVersion + '+' + $buildNum);" ^
        "Write-Output ('Build number: ' + $buildNum);" ^
        "Write-Output ('Changelog обновлён. SHA: ' + $sha);" ^
    "} catch {" ^
        "[Console]::Error.WriteLine('ОШИБКА: ' + $_.Exception.Message);" ^
        "exit 1;" ^
    "}"

if errorlevel 1 goto :version_update_error

:: ------------------------------------------------------------
:: 7. Создание второго коммита
:: ------------------------------------------------------------

echo.
echo [7/9] Добавление файлов версий...

git add -- version.txt pubspec.yaml changelog.md

if errorlevel 1 goto :second_add_error

echo.
echo [8/9] Создание коммита обновления версии...

git commit -m "chore: bump version"

if errorlevel 1 goto :second_commit_error

:: ------------------------------------------------------------
:: 8. Отправка на сервер
:: ------------------------------------------------------------

if /i "%PUSH_PARAM%"=="push" goto :push

echo.
echo [9/9] Отправка пропущена (параметр push не указан).
goto :success

:push

echo.
echo [9/9] Отправка изменений на сервер...

git push

if errorlevel 1 goto :push_error

:: ------------------------------------------------------------
:: Успешное завершение
:: ------------------------------------------------------------

:success

if exist "%COMMIT_FILE%" del /q "%COMMIT_FILE%" > nul 2>&1

echo.
echo ============================================================
echo Все операции успешно выполнены!
echo ============================================================
echo.
echo Первоначальный коммит: %COMMIT_SHA%
echo Обновление версии: успешно
echo Changelog: обновлён
echo Второй коммит: создан
echo.

exit /b 0

:: ============================================================
:: ОБРАБОТКА ОШИБОК
:: ============================================================

:git_add_error
echo Ошибка: не удалось добавить изменения в Git.
goto :error

:message_file_error
echo Ошибка: не удалось создать временный файл сообщения коммита.
goto :error

:first_commit_error
echo Ошибка: не удалось создать первоначальный коммит.
echo Проверьте наличие изменений и настройки Git.
goto :error

:sha_error
echo Ошибка: не удалось получить SHA коммита.
goto :error

:version_update_error
echo Ошибка: не удалось обновить файлы версий.
echo Первоначальный коммит уже создан.
goto :error

:second_add_error
echo Ошибка: не удалось добавить файлы версий в Git.
goto :error

:second_commit_error
echo Ошибка: не удалось создать коммит обновления версии.
goto :error

:push_error
echo Ошибка: не удалось отправить изменения на сервер.
echo Локальные коммиты сохранены.
goto :error

:error

if exist "%COMMIT_FILE%" del /q "%COMMIT_FILE%" > nul 2>&1

echo.
echo Выполнение скрипта завершено с ошибкой.
exit /b 1

:: ============================================================
:: СПРАВКА
:: ============================================================

:usage

echo.
echo Использование:
echo   %~nx0 "Текст коммита" ^<x^|y^|z^> [push]
echo.
echo Примеры:
echo   %~nx0 "Исправлена ошибка авторизации" z
echo   %~nx0 "Добавлен новый функционал" y push
echo   %~nx0 "Полный релиз приложения" x push
echo.

exit /b 1