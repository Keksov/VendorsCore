@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [fpc-release-pack] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

set "ARCHIVE_PATH=%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%"
set "EXISTING_SOURCE_ARCHIVE="

if not exist "%FPC_MAIN_FPC_EXE%" (
    echo [fpc-release-pack] Error: expected toolchain was not found in %FPC_BIN_TARGET_DIR%
    goto :fail
)

call :prepare_source_archive
if errorlevel 1 goto :fail

if exist "%ARCHIVE_PATH%" del /f /q "%ARCHIVE_PATH%" >nul 2>nul

echo [fpc-release-pack] Packing %FPC_BIN_TARGET_DIR% into %ARCHIVE_PATH%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Compress-Archive -LiteralPath $env:FPC_BIN_TARGET_DIR -DestinationPath $env:ARCHIVE_PATH -Force"
if errorlevel 1 (
    echo [fpc-release-pack] Error: failed to create %ARCHIVE_PATH%
    goto :fail
)

if not exist "%ARCHIVE_PATH%" (
    echo [fpc-release-pack] Error: archive was not created: %ARCHIVE_PATH%
    goto :fail
)

echo [fpc-release-pack] Ready: %ARCHIVE_PATH%
echo [fpc-release-pack] Manual upload:
echo [fpc-release-pack]   1. Open https://github.com/%RELEASE_REPO%/releases
echo [fpc-release-pack]   2. Create or edit the target release
echo [fpc-release-pack]   3. Upload %FPC_MAIN_ARCHIVE_NAME%
popd >nul
exit /b 0

:prepare_source_archive
if exist "%SOURCES_DIR%" (
    call ".\fpc_source_pack.bat"
    exit /b %ERRORLEVEL%
)

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; if (Test-Path $env:FPC_BIN_TARGET_DIR) { $item = Get-ChildItem -LiteralPath $env:FPC_BIN_TARGET_DIR -File | Where-Object { $_.Name -like 'sources-*.zip' } | Sort-Object Name -Descending | Select-Object -First 1; if ($item) { $item.FullName } }"`) do set "EXISTING_SOURCE_ARCHIVE=%%I"

if defined EXISTING_SOURCE_ARCHIVE (
    echo [fpc-release-pack] Reusing existing source archive %EXISTING_SOURCE_ARCHIVE%.
    exit /b 0
)

echo [fpc-release-pack] Error: no dated sources snapshot was found under %SOURCES_DIR%, and no existing sources-*.zip was found in %FPC_BIN_TARGET_DIR%.
exit /b 1

:fail
popd >nul
exit /b 1