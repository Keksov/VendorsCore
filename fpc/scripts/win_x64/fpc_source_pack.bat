@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [fpc-source-pack] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

set "SOURCE_SNAPSHOT_DIR=%~1"
set "SOURCE_ARCHIVE_TARGET_DIR=%~2"

if not defined SOURCE_SNAPSHOT_DIR if defined FPC_SOURCE_SNAPSHOT_DIR set "SOURCE_SNAPSHOT_DIR=%FPC_SOURCE_SNAPSHOT_DIR%"
if not defined SOURCE_ARCHIVE_TARGET_DIR if defined FPC_SOURCE_ARCHIVE_TARGET_DIR set "SOURCE_ARCHIVE_TARGET_DIR=%FPC_SOURCE_ARCHIVE_TARGET_DIR%"
if not defined SOURCE_ARCHIVE_TARGET_DIR set "SOURCE_ARCHIVE_TARGET_DIR=%FPC_BIN_TARGET_DIR%"

if not defined SOURCE_SNAPSHOT_DIR (
    for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $root = Resolve-Path $env:SOURCES_DIR; $item = Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -like 'sources-*' } | Sort-Object Name -Descending | Select-Object -First 1; if ($item) { $item.FullName }"`) do set "SOURCE_SNAPSHOT_DIR=%%I"
)

if not defined SOURCE_SNAPSHOT_DIR (
    echo [fpc-source-pack] Error: no dated sources snapshot was found under %SOURCES_DIR%
    goto :fail
)

if not exist "%SOURCE_SNAPSHOT_DIR%" (
    echo [fpc-source-pack] Error: source snapshot directory was not found: %SOURCE_SNAPSHOT_DIR%
    goto :fail
)

if not exist "%SOURCE_ARCHIVE_TARGET_DIR%" mkdir "%SOURCE_ARCHIVE_TARGET_DIR%"
if errorlevel 1 (
    echo [fpc-source-pack] Error: failed to create %SOURCE_ARCHIVE_TARGET_DIR%
    goto :fail
)

for %%I in ("%SOURCE_SNAPSHOT_DIR%") do (
    set "SOURCE_SNAPSHOT_DIR=%%~fI"
    set "SOURCE_SNAPSHOT_NAME=%%~nxI"
    set "SOURCE_SNAPSHOT_PARENT=%%~dpI"
)

for %%I in ("%SOURCE_ARCHIVE_TARGET_DIR%") do set "SOURCE_ARCHIVE_TARGET_DIR=%%~fI"

set "SOURCE_SNAPSHOT_ARCHIVE_PATH=%SOURCE_ARCHIVE_TARGET_DIR%\%SOURCE_SNAPSHOT_NAME%.zip"

if exist "%SOURCE_SNAPSHOT_ARCHIVE_PATH%" del /f /q "%SOURCE_SNAPSHOT_ARCHIVE_PATH%" >nul 2>nul

if exist "%SEVEN_ZIP_EXE%" (
    call :pack_with_7zip
) else (
    call :pack_with_git_archive
)
if errorlevel 1 goto :fail

if not exist "%SOURCE_SNAPSHOT_ARCHIVE_PATH%" (
    echo [fpc-source-pack] Error: source archive was not created: %SOURCE_SNAPSHOT_ARCHIVE_PATH%
    goto :fail
)

echo [fpc-source-pack] Ready: %SOURCE_SNAPSHOT_ARCHIVE_PATH%
popd >nul
exit /b 0

:pack_with_7zip
echo [fpc-source-pack] Using 7-Zip: %SEVEN_ZIP_EXE%
echo [fpc-source-pack] Packing %SOURCE_SNAPSHOT_NAME% into %SOURCE_SNAPSHOT_ARCHIVE_PATH%...
pushd "%SOURCE_SNAPSHOT_PARENT%" >nul
if errorlevel 1 (
    echo [fpc-source-pack] Error: failed to enter %SOURCE_SNAPSHOT_PARENT%
    exit /b 1
)

"%SEVEN_ZIP_EXE%" a -tzip -mx=9 -mfb=258 -mpass=15 -mmt=on "%SOURCE_SNAPSHOT_ARCHIVE_PATH%" "%SOURCE_SNAPSHOT_NAME%\" -x!"%SOURCE_SNAPSHOT_NAME%\.git" -x!"%SOURCE_SNAPSHOT_NAME%\.git\*"
if errorlevel 1 (
    popd >nul
    echo [fpc-source-pack] Error: 7-Zip failed to create %SOURCE_SNAPSHOT_ARCHIVE_PATH%
    exit /b 1
)

popd >nul
exit /b 0

:pack_with_git_archive
echo [fpc-source-pack] 7-Zip not found, falling back to git archive.
echo [fpc-source-pack] Packing %SOURCE_SNAPSHOT_NAME% into %SOURCE_SNAPSHOT_ARCHIVE_PATH%...
pushd "%SOURCE_SNAPSHOT_DIR%" >nul
if errorlevel 1 (
    echo [fpc-source-pack] Error: failed to enter %SOURCE_SNAPSHOT_DIR%
    exit /b 1
)

git archive --format=zip --output="%SOURCE_SNAPSHOT_ARCHIVE_PATH%" --prefix="%SOURCE_SNAPSHOT_NAME%/" HEAD
if errorlevel 1 (
    popd >nul
    echo [fpc-source-pack] Error: git archive failed to create %SOURCE_SNAPSHOT_ARCHIVE_PATH%
    exit /b 1
)

popd >nul
exit /b 0

:fail
popd >nul
exit /b 1