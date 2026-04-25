@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [release-asset] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

set "ASSET_NAME="
set "OUTPUT_PATH="
set "RELEASE_REF="
set "FORCE_DOWNLOAD=0"

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--asset" (
    if "%~2"=="" goto :missing_value
    set "ASSET_NAME=%~2"
    shift
    shift
    goto :parse_args
)

if /I "%~1"=="--out" (
    if "%~2"=="" goto :missing_value
    set "OUTPUT_PATH=%~2"
    shift
    shift
    goto :parse_args
)

if /I "%~1"=="--tag" (
    if "%~2"=="" goto :missing_value
    set "RELEASE_REF=%~2"
    shift
    shift
    goto :parse_args
)

if /I "%~1"=="--latest" (
    set "RELEASE_REF=latest"
    shift
    goto :parse_args
)

if /I "%~1"=="--force" (
    set "FORCE_DOWNLOAD=1"
    shift
    goto :parse_args
)

echo [release-asset] Error: unknown argument %~1
goto :usage

:missing_value
echo [release-asset] Error: missing value for %~1
goto :usage

:args_done
if not defined ASSET_NAME (
    echo [release-asset] Error: --asset is required.
    goto :usage
)

if not defined OUTPUT_PATH (
    echo [release-asset] Error: --out is required.
    goto :usage
)

if not defined RELEASE_REF set "RELEASE_REF=latest"

set "ALLOW_CACHE=1"
if /I "%RELEASE_REF%"=="latest" set "ALLOW_CACHE=0"

for %%I in ("%OUTPUT_PATH%") do set "OUTPUT_DIR=%%~dpI"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if errorlevel 1 (
    echo [release-asset] Error: failed to create output directory %OUTPUT_DIR%
    goto :fail
)

if "%FORCE_DOWNLOAD%"=="0" if "%ALLOW_CACHE%"=="1" if exist "%OUTPUT_PATH%" (
    echo [release-asset] Using cached asset: %OUTPUT_PATH%
    goto :success
)

if /I "%RELEASE_REF%"=="latest" (
    set "DOWNLOAD_URL=https://github.com/%RELEASE_REPO%/releases/latest/download/%ASSET_NAME%"
) else (
    set "DOWNLOAD_URL=%RELEASE_DOWNLOAD_BASE_URL%/%RELEASE_REF%/%ASSET_NAME%"
)

set "TEMP_DOWNLOAD=%OUTPUT_PATH%.download"
if exist "%TEMP_DOWNLOAD%" del /f /q "%TEMP_DOWNLOAD%" >nul 2>nul

echo [release-asset] Downloading %ASSET_NAME% from %RELEASE_REF%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Invoke-WebRequest -UseBasicParsing -Uri $env:DOWNLOAD_URL -OutFile $env:TEMP_DOWNLOAD"
if errorlevel 1 (
    echo [release-asset] Error: failed to download %ASSET_NAME% from %DOWNLOAD_URL%
    goto :fail
)

if not exist "%TEMP_DOWNLOAD%" (
    echo [release-asset] Error: download did not produce %TEMP_DOWNLOAD%
    goto :fail
)

move /y "%TEMP_DOWNLOAD%" "%OUTPUT_PATH%" >nul
if errorlevel 1 (
    echo [release-asset] Error: failed to move %TEMP_DOWNLOAD% to %OUTPUT_PATH%
    goto :fail
)

echo [release-asset] Saved %ASSET_NAME% to %OUTPUT_PATH%
goto :success

:usage
echo Usage: release_asset_download.bat --asset NAME --out PATH [--latest ^| --tag TAG] [--force]
goto :fail

:fail
if exist "%TEMP_DOWNLOAD%" del /f /q "%TEMP_DOWNLOAD%" >nul 2>nul
popd >nul
exit /b 1

:success
popd >nul
exit /b 0