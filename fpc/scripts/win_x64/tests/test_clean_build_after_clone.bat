@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "TEST_EXIT=1"
pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\test_common.bat" init_test clean_build_after_clone
if errorlevel 1 goto :fail

call ".\test_common.bat" hard_reset_vendor_state
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture clean_build_after_clone "..\fpc_main_build.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :retry_after_download_failure

:after_build_success
call ".\test_common.bat" assert_last_log_contains "[fpc-source-pack] Using 7-Zip:"
if errorlevel 1 goto :fail

call ".\test_common.bat" assert_file_exists "%FPC_BOOTSTRAP_INSTALLER_PATH%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%GNUMAKE_EXE%"
if errorlevel 1 goto :fail

call ".\test_common.bat" resolve_latest_snapshot LATEST_SOURCE_SNAPSHOT
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_dir_exists "%LATEST_SOURCE_SNAPSHOT%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_main_matches_snapshot "%LATEST_SOURCE_SNAPSHOT%"
if errorlevel 1 goto :fail

for %%I in ("%LATEST_SOURCE_SNAPSHOT%") do set "LATEST_SOURCE_SNAPSHOT_NAME=%%~nxI"

call ".\test_common.bat" assert_dir_exists "%FPC_BIN_TARGET_DIR%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_MAIN_FPC_EXE%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_BIN_TARGET_DIR%\%LATEST_SOURCE_SNAPSHOT_NAME%.zip"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_zip_contains "%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%" "fpc-main/%LATEST_SOURCE_SNAPSHOT_NAME%.zip"
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture clean_build_version "%FPC_MAIN_FPC_EXE%" -iV
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail

echo [test:clean_build_after_clone] PASS
set "TEST_EXIT=0"
goto :end

:retry_after_download_failure
call ".\test_common.bat" assert_last_log_contains "[release-asset] Error: failed to download"
if errorlevel 1 goto :fail

echo [test:clean_build_after_clone] Retrying after transient release asset download failure...
call ".\test_common.bat" run_and_capture clean_build_after_clone_retry "..\fpc_main_build.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail
goto :after_build_success

:fail
echo [test:clean_build_after_clone] FAIL
if defined TEST_LAST_LOG echo [test:clean_build_after_clone] See log: %TEST_LAST_LOG%

:end
popd >nul
exit /b %TEST_EXIT%