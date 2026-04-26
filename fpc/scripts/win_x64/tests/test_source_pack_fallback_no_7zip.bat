@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "TEST_EXIT=1"
pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\test_common.bat" init_test source_pack_fallback_no_7zip
if errorlevel 1 goto :fail

call ".\test_common.bat" ensure_latest_snapshot LATEST_SOURCE_SNAPSHOT
if errorlevel 1 goto :fail

for %%I in ("%LATEST_SOURCE_SNAPSHOT%") do set "LATEST_SOURCE_SNAPSHOT_NAME=%%~nxI"

call ".\test_common.bat" remove_path "%FPC_BIN_TARGET_DIR%\%LATEST_SOURCE_SNAPSHOT_NAME%.zip"
if errorlevel 1 goto :fail

set "SEVEN_ZIP_EXE=%TEMP%\missing-7z.exe"

call ".\test_common.bat" run_and_capture fallback_source_pack "..\fpc_source_pack.bat" "%LATEST_SOURCE_SNAPSHOT%" "%FPC_BIN_TARGET_DIR%"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_last_log_contains "7-Zip not found, falling back to git archive."
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_BIN_TARGET_DIR%\%LATEST_SOURCE_SNAPSHOT_NAME%.zip"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_zip_contains "%FPC_BIN_TARGET_DIR%\%LATEST_SOURCE_SNAPSHOT_NAME%.zip" "%LATEST_SOURCE_SNAPSHOT_NAME%/*"
if errorlevel 1 goto :fail

echo [test:source_pack_fallback_no_7zip] PASS
set "TEST_EXIT=0"
goto :end

:fail
echo [test:source_pack_fallback_no_7zip] FAIL
if defined TEST_LAST_LOG echo [test:source_pack_fallback_no_7zip] See log: %TEST_LAST_LOG%

:end
popd >nul
exit /b %TEST_EXIT%