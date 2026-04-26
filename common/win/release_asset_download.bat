@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "TARGET_REPO="
set "ASSET_NAME="
set "OUTPUT_PATH="
set "RELEASE_REF="
set "FORCE_DOWNLOAD=0"
set "TEMP_DOWNLOAD="
set "TEMP_DIGEST="
set "ASSET_DIGEST="
set "ASSET_DIGEST_ALGORITHM="
set "ASSET_DIGEST_HASH="

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--repo" (
    if "%~2"=="" goto :missing_value
    set "TARGET_REPO=%~2"
    shift
    shift
    goto :parse_args
)

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
if not defined TARGET_REPO if defined RELEASE_REPO set "TARGET_REPO=%RELEASE_REPO%"
if not defined TARGET_REPO (
    echo [release-asset] Error: --repo is required.
    goto :usage
)

if not defined ASSET_NAME (
    echo [release-asset] Error: --asset is required.
    goto :usage
)

if not defined OUTPUT_PATH (
    echo [release-asset] Error: --out is required.
    goto :usage
)

if not defined RELEASE_REF set "RELEASE_REF=latest"

for %%I in ("%OUTPUT_PATH%") do set "OUTPUT_DIR=%%~dpI"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if errorlevel 1 (
    echo [release-asset] Error: failed to create output directory %OUTPUT_DIR%
    goto :fail
)

set "TEMP_DOWNLOAD=%OUTPUT_PATH%.download"
set "TEMP_DIGEST=%OUTPUT_PATH%.download.digest"

call :refresh_digest
if errorlevel 1 goto :fail

if "%FORCE_DOWNLOAD%"=="0" if exist "%OUTPUT_PATH%" (
    call :verify_asset "%OUTPUT_PATH%"
    if errorlevel 1 (
        echo [release-asset] Cached asset failed integrity verification. Re-downloading...
        del /f /q "%OUTPUT_PATH%" >nul 2>nul
    ) else (
        echo [release-asset] Using cached asset: %OUTPUT_PATH%
        goto :success
    )
)

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" (
    where powershell.exe >nul 2>nul
    if errorlevel 1 (
        echo [release-asset] Error: powershell.exe was not found.
        goto :fail
    )
    set "POWERSHELL_EXE=powershell.exe"
)

if /I "%RELEASE_REF%"=="latest" (
    set "DOWNLOAD_URL=https://github.com/%TARGET_REPO%/releases/latest/download/%ASSET_NAME%"
) else (
    set "DOWNLOAD_URL=https://github.com/%TARGET_REPO%/releases/download/%RELEASE_REF%/%ASSET_NAME%"
)

if exist "%TEMP_DOWNLOAD%" del /f /q "%TEMP_DOWNLOAD%" >nul 2>nul

echo [release-asset] Downloading %ASSET_NAME% from %TARGET_REPO%@%RELEASE_REF%...
"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $maxAttempts = 3; if ($env:HTTP_RETRY_ATTEMPTS -match '^[0-9]+$' -and [int]$env:HTTP_RETRY_ATTEMPTS -gt 0) { $maxAttempts = [int]$env:HTTP_RETRY_ATTEMPTS }; $delaySeconds = 2; if ($env:HTTP_RETRY_DELAY_SECONDS -match '^[0-9]+$' -and [int]$env:HTTP_RETRY_DELAY_SECONDS -ge 0) { $delaySeconds = [int]$env:HTTP_RETRY_DELAY_SECONDS }; for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) { try { Invoke-WebRequest -UseBasicParsing -Uri $env:DOWNLOAD_URL -OutFile $env:TEMP_DOWNLOAD; exit 0 } catch { if ($attempt -ge $maxAttempts) { throw }; Write-Host ('[release-asset] Warning: download attempt {0}/{1} failed: {2}' -f $attempt, $maxAttempts, $_.Exception.Message); Start-Sleep -Seconds $delaySeconds } }"
if errorlevel 1 (
    echo [release-asset] Error: failed to download %ASSET_NAME% from %DOWNLOAD_URL%
    goto :fail
)

if not exist "%TEMP_DOWNLOAD%" (
    echo [release-asset] Error: download did not produce %TEMP_DOWNLOAD%
    goto :fail
)

call :verify_asset "%TEMP_DOWNLOAD%"
if errorlevel 1 goto :fail

move /y "%TEMP_DOWNLOAD%" "%OUTPUT_PATH%" >nul
if errorlevel 1 (
    echo [release-asset] Error: failed to move %TEMP_DOWNLOAD% to %OUTPUT_PATH%
    goto :fail
)

echo [release-asset] Saved %ASSET_NAME% to %OUTPUT_PATH%
goto :success

:usage
echo Usage: release_asset_download.bat --repo OWNER/REPO --asset NAME --out PATH [--latest ^| --tag TAG] [--force]
goto :fail

:fail
if exist "%TEMP_DOWNLOAD%" del /f /q "%TEMP_DOWNLOAD%" >nul 2>nul
if exist "%TEMP_DIGEST%" del /f /q "%TEMP_DIGEST%" >nul 2>nul
exit /b 1

:success
if exist "%TEMP_DIGEST%" del /f /q "%TEMP_DIGEST%" >nul 2>nul
exit /b 0

:refresh_digest
if exist "%TEMP_DIGEST%" del /f /q "%TEMP_DIGEST%" >nul 2>nul

if /I "%RELEASE_REF%"=="latest" (
    call "%~dp0release_asset_digest.bat" --repo "%TARGET_REPO%" --asset "%ASSET_NAME%" --out "%TEMP_DIGEST%" --latest --force
) else (
    call "%~dp0release_asset_digest.bat" --repo "%TARGET_REPO%" --asset "%ASSET_NAME%" --out "%TEMP_DIGEST%" --tag "%RELEASE_REF%" --force
)
if errorlevel 1 exit /b 1

call :load_expected_digest "%TEMP_DIGEST%"
exit /b %errorlevel%

:verify_asset
call "%~dp0verify_hash.bat" "release-asset" "%~1" "%ASSET_DIGEST_ALGORITHM%" "%ASSET_DIGEST_HASH%" "%ASSET_NAME%"
exit /b %errorlevel%

:load_expected_digest
set "ASSET_DIGEST="
set "ASSET_DIGEST_ALGORITHM="
set "ASSET_DIGEST_HASH="

if not exist "%~1" (
    echo [release-asset] Error: digest file was not found: %~1
    exit /b 1
)

set /p ASSET_DIGEST=<"%~1"
if not defined ASSET_DIGEST (
    echo [release-asset] Error: digest file is empty: %~1
    exit /b 1
)

for /f "tokens=1,* delims=:" %%A in ("%ASSET_DIGEST%") do (
    set "ASSET_DIGEST_ALGORITHM=%%A"
    set "ASSET_DIGEST_HASH=%%B"
)

if not defined ASSET_DIGEST_ALGORITHM (
    echo [release-asset] Error: digest is missing an algorithm: %ASSET_DIGEST%
    exit /b 1
)

if not defined ASSET_DIGEST_HASH (
    echo [release-asset] Error: digest is missing a hash value: %ASSET_DIGEST%
    exit /b 1
)

exit /b 0