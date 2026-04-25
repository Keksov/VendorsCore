@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [cleanup] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

set "FAILED=0"

call :remove_dir "%WORK_DIR%"
call :remove_dir "%BUILD_TEMP_DIR%"
call :remove_dir "%SOURCES_DIR%"
call :remove_dir "%BOOTSTRAP_INSTALL_DIR%"

if not "%FAILED%"=="0" (
    echo [cleanup] Error: one or more directories could not be removed.
    popd >nul
    exit /b 1
)

echo [cleanup] Done.
popd >nul
exit /b 0

:remove_dir
if exist "%~1" (
    echo [cleanup] Removing %~1
    rd /s /q "%~1" >nul 2>nul
    if exist "%~1" (
        echo [cleanup] Error: failed to remove %~1
        set "FAILED=1"
    )
)
exit /b 0