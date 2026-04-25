@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [fpc-source-sync] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

if "%~1"=="" goto :usage

set "FORCE_SYNC=0"

if /I "%~1"=="bootstrap" (
    set "SYNC_KIND=bootstrap"
    set "SYNC_REF=%FPC_BOOTSTRAP_SOURCE_REF%"
    set "SYNC_DIR=%FPC_BOOTSTRAP_SOURCE_DIR%"
    goto :sync_selected
)

if /I "%~1"=="main" (
    set "SYNC_KIND=main"
    set "SYNC_REF=%FPC_MAIN_SOURCE_REF%"
    set "SYNC_DIR=%FPC_MAIN_SOURCE_DIR%"
    goto :sync_selected
)

echo [fpc-source-sync] Error: unknown source set %~1
goto :usage

:sync_selected
if not "%~2"=="" (
    if /I "%~2"=="--force" (
        set "FORCE_SYNC=1"
    ) else (
        echo [fpc-source-sync] Error: unknown argument %~2
        goto :usage
    )
)

if not "%~3"=="" (
    echo [fpc-source-sync] Error: too many arguments.
    goto :usage
)

where git >nul 2>nul
if errorlevel 1 (
    echo [fpc-source-sync] Error: git.exe was not found in PATH.
    goto :fail
)

for %%I in ("%SYNC_DIR%") do set "SYNC_PARENT=%%~dpI"
if not exist "%SYNC_PARENT%" mkdir "%SYNC_PARENT%"
if errorlevel 1 (
    echo [fpc-source-sync] Error: failed to create %SYNC_PARENT%
    goto :fail
)

if exist "%SYNC_DIR%\.git" goto :update_existing

if exist "%SYNC_DIR%" (
    echo [fpc-source-sync] Error: %SYNC_DIR% exists but is not a git worktree.
    goto :fail
)

echo [fpc-source-sync] Cloning %SYNC_KIND% sources...
git clone --depth 1 --branch "%SYNC_REF%" "%FPC_GIT_HTTPS_URL%" "%SYNC_DIR%"
if errorlevel 1 goto :fail
goto :success

:update_existing
pushd "%SYNC_DIR%" >nul
if errorlevel 1 (
    echo [fpc-source-sync] Error: failed to enter %SYNC_DIR%
    goto :fail
)

if "%FORCE_SYNC%"=="0" (
    git status --porcelain --untracked-files=all | findstr . >nul
    if not errorlevel 1 (
        echo [fpc-source-sync] Error: %SYNC_DIR% has local changes or untracked files. Re-run with --force to discard them.
        popd >nul
        goto :fail
    )
)

if /I "%SYNC_KIND%"=="bootstrap" (
    git fetch --depth 1 origin "refs/tags/%SYNC_REF%:refs/tags/%SYNC_REF%"
    if errorlevel 1 goto :update_fail
    git checkout -f "%SYNC_REF%"
    if errorlevel 1 goto :update_fail
    git reset --hard "%SYNC_REF%"
    if errorlevel 1 goto :update_fail
) else (
    git fetch --depth 1 origin "%SYNC_REF%"
    if errorlevel 1 goto :update_fail
    git checkout -f "%SYNC_REF%"
    if errorlevel 1 goto :update_fail
    git reset --hard "origin/%SYNC_REF%"
    if errorlevel 1 goto :update_fail
)

git clean -fdx
if errorlevel 1 goto :update_fail

popd >nul
goto :success

:update_fail
popd >nul
goto :fail

:usage
echo Usage: fpc_source_sync.bat bootstrap^|main [--force]
goto :fail

:success
echo [fpc-source-sync] Ready: %SYNC_DIR%
popd >nul
exit /b 0

:fail
popd >nul
exit /b 1