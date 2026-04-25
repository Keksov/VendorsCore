@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [fpc-release-setup] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

set "RELEASE_REF=%FPC_MAIN_RELEASE_REF%"
set "CACHE_REF=latest"

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--tag" (
    if "%~2"=="" goto :usage
    set "RELEASE_REF=%~2"
    set "CACHE_REF=%~2"
    shift
    shift
    goto :parse_args
)

echo [fpc-release-setup] Error: unknown argument %~1
goto :usage

:args_done
set "ARCHIVE_CACHE_DIR=%RELEASE_CACHE_DIR%\%CACHE_REF%"
set "ARCHIVE_PATH=%ARCHIVE_CACHE_DIR%\%FPC_MAIN_ARCHIVE_NAME%"
set "ARCHIVE_DIGEST_PATH=%ARCHIVE_PATH%.digest"
set "EXTRACT_DIR=%WORK_DIR%\release-setup"

if /I "%RELEASE_REF%"=="latest" (
    call ".\release_asset_digest.bat" --asset "%FPC_MAIN_ARCHIVE_NAME%" --out "%ARCHIVE_DIGEST_PATH%" --latest
    if errorlevel 1 goto :fail
    call :load_expected_digest "%ARCHIVE_DIGEST_PATH%"
    if errorlevel 1 goto :fail
    if exist "%ARCHIVE_PATH%" (
        call ".\verify_hash.bat" "fpc-release-setup" "%ARCHIVE_PATH%" "%ARCHIVE_DIGEST_ALGORITHM%" "%ARCHIVE_DIGEST_HASH%" "%FPC_MAIN_ARCHIVE_NAME%"
        if errorlevel 1 (
            echo [fpc-release-setup] Cached archive failed integrity verification. Re-downloading...
            del /f /q "%ARCHIVE_PATH%" >nul 2>nul
        )
    )
    call ".\release_asset_download.bat" --asset "%FPC_MAIN_ARCHIVE_NAME%" --out "%ARCHIVE_PATH%" --latest
) else (
    call ".\release_asset_digest.bat" --asset "%FPC_MAIN_ARCHIVE_NAME%" --out "%ARCHIVE_DIGEST_PATH%" --tag "%RELEASE_REF%"
    if errorlevel 1 goto :fail
    call :load_expected_digest "%ARCHIVE_DIGEST_PATH%"
    if errorlevel 1 goto :fail
    if exist "%ARCHIVE_PATH%" (
        call ".\verify_hash.bat" "fpc-release-setup" "%ARCHIVE_PATH%" "%ARCHIVE_DIGEST_ALGORITHM%" "%ARCHIVE_DIGEST_HASH%" "%FPC_MAIN_ARCHIVE_NAME%"
        if errorlevel 1 (
            echo [fpc-release-setup] Cached archive failed integrity verification. Re-downloading...
            del /f /q "%ARCHIVE_PATH%" >nul 2>nul
        )
    )
    call ".\release_asset_download.bat" --asset "%FPC_MAIN_ARCHIVE_NAME%" --out "%ARCHIVE_PATH%" --tag "%RELEASE_REF%"
)

if errorlevel 1 (
    echo [fpc-release-setup] Error: %FPC_MAIN_ARCHIVE_NAME% is not available in release ref %RELEASE_REF%.
    echo [fpc-release-setup] Hint: publish the asset to GitHub Releases or run fpc_main_build.bat.
    goto :fail
)

call ".\verify_hash.bat" "fpc-release-setup" "%ARCHIVE_PATH%" "%ARCHIVE_DIGEST_ALGORITHM%" "%ARCHIVE_DIGEST_HASH%" "%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 goto :fail

if exist "%EXTRACT_DIR%" rd /s /q "%EXTRACT_DIR%" >nul 2>nul
if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
if errorlevel 1 (
    echo [fpc-release-setup] Error: failed to create %WORK_DIR%
    goto :fail
)

mkdir "%EXTRACT_DIR%"
if errorlevel 1 (
    echo [fpc-release-setup] Error: failed to create %EXTRACT_DIR%
    goto :fail
)

if exist "%FPC_BIN_TARGET_DIR%" rd /s /q "%FPC_BIN_TARGET_DIR%" >nul 2>nul

echo [fpc-release-setup] Extracting %ARCHIVE_PATH%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_PATH -DestinationPath $env:EXTRACT_DIR -Force"
if errorlevel 1 (
    echo [fpc-release-setup] Error: failed to extract %ARCHIVE_PATH%
    goto :fail
)

if not exist "%EXTRACT_DIR%\fpc-main\bin\%FPC_TARGET_SUFFIX%\fpc.exe" (
    echo [fpc-release-setup] Error: archive layout is invalid. Expected fpc-main\bin\%FPC_TARGET_SUFFIX%\fpc.exe inside the zip.
    goto :fail
)

move "%EXTRACT_DIR%\fpc-main" "%FPC_BIN_TARGET_DIR%" >nul
if errorlevel 1 (
    echo [fpc-release-setup] Error: failed to stage %FPC_BIN_TARGET_DIR%
    goto :fail
)

if exist "%EXTRACT_DIR%" rd /s /q "%EXTRACT_DIR%" >nul 2>nul

echo [fpc-release-setup] Ready: %FPC_BIN_TARGET_DIR%
popd >nul
exit /b 0

:usage
echo Usage: fpc_release_setup.bat [--tag TAG]
goto :fail

:fail
if exist "%EXTRACT_DIR%" rd /s /q "%EXTRACT_DIR%" >nul 2>nul
popd >nul
exit /b 1

:load_expected_digest
set "ARCHIVE_DIGEST="
set "ARCHIVE_DIGEST_ALGORITHM="
set "ARCHIVE_DIGEST_HASH="

if not exist "%~1" (
    echo [fpc-release-setup] Error: digest file was not found: %~1
    exit /b 1
)

set /p ARCHIVE_DIGEST=<"%~1"
if not defined ARCHIVE_DIGEST (
    echo [fpc-release-setup] Error: digest file is empty: %~1
    exit /b 1
)

for /f "tokens=1,2 delims=:" %%A in ("%ARCHIVE_DIGEST%") do (
    set "ARCHIVE_DIGEST_ALGORITHM=%%A"
    set "ARCHIVE_DIGEST_HASH=%%B"
)

if not defined ARCHIVE_DIGEST_ALGORITHM (
    echo [fpc-release-setup] Error: digest is missing an algorithm: %ARCHIVE_DIGEST%
    exit /b 1
)

if not defined ARCHIVE_DIGEST_HASH (
    echo [fpc-release-setup] Error: digest is missing a hash value: %ARCHIVE_DIGEST%
    exit /b 1
)

exit /b 0