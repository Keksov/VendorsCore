@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "OFFLINE_ONLY=0"
set "TEST_EXIT=1"

if /I "%~1"=="--offline-only" set "OFFLINE_ONLY=1"

pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\test_common.bat" init_test missing_artifacts
if errorlevel 1 goto :fail

if "%OFFLINE_ONLY%"=="0" (
    call :subtest_missing_release_tag
    if errorlevel 1 goto :fail
)

call :subtest_missing_toolchain
if errorlevel 1 goto :fail

call :subtest_missing_snapshot
if errorlevel 1 goto :fail

if "%OFFLINE_ONLY%"=="0" (
    call :subtest_corrupt_release_cache
    if errorlevel 1 goto :fail
    call :subtest_corrupt_bootstrap_cache
    if errorlevel 1 goto :fail
    call :subtest_corrupt_gnumake_cache
    if errorlevel 1 goto :fail
)

echo [test:missing_artifacts] PASS
set "TEST_EXIT=0"
goto :end

:subtest_missing_release_tag
call ".\test_common.bat" run_and_capture missing_release_tag "..\fpc_release_setup.bat" --tag definitely-missing-tag
call ".\test_common.bat" assert_last_exit_nonzero
if errorlevel 1 exit /b 1
call ".\test_common.bat" assert_last_log_contains "release ref definitely-missing-tag was not found"
if errorlevel 1 exit /b 1
exit /b 0

:subtest_missing_toolchain
call ".\test_common.bat" remove_path "%FPC_BIN_TARGET_DIR%"
if errorlevel 1 exit /b 1
call ".\test_common.bat" run_and_capture missing_toolchain_release_pack "..\fpc_release_pack.bat"
call ".\test_common.bat" assert_last_exit_nonzero
if errorlevel 1 exit /b 1
call ".\test_common.bat" assert_last_log_contains "expected toolchain was not found"
if errorlevel 1 exit /b 1
exit /b 0

:subtest_missing_snapshot
call ".\test_common.bat" remove_path "%SOURCES_DIR%"
if errorlevel 1 exit /b 1
call ".\test_common.bat" run_and_capture missing_snapshot_source_pack "..\fpc_source_pack.bat"
call ".\test_common.bat" assert_last_exit_nonzero
if errorlevel 1 exit /b 1
call ".\test_common.bat" assert_last_log_contains "no dated sources snapshot was found"
if errorlevel 1 exit /b 1
exit /b 0

:subtest_corrupt_release_cache
call ".\test_common.bat" run_and_capture populate_release_cache "..\fpc_release_setup.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 exit /b 1
call ".\test_common.bat" corrupt_file "%RELEASE_CACHE_DIR%\latest\%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 exit /b 1
call ".\test_common.bat" run_and_capture repair_release_cache "..\fpc_release_setup.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 exit /b 1
call ".\test_common.bat" assert_last_log_contains "Cached archive failed integrity verification. Re-downloading..."
if errorlevel 1 exit /b 1
exit /b 0

:subtest_corrupt_bootstrap_cache
call ".\test_common.bat" run_and_capture populate_bootstrap_cache "..\fpc_bootstrap_build.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 exit /b 1
call ".\test_common.bat" remove_path "%BOOTSTRAP_INSTALL_DIR%"
if errorlevel 1 exit /b 1
call ".\test_common.bat" corrupt_file "%FPC_BOOTSTRAP_INSTALLER_PATH%"
if errorlevel 1 exit /b 1
call ".\test_common.bat" run_and_capture repair_bootstrap_cache "..\fpc_bootstrap_build.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 exit /b 1
call ".\test_common.bat" assert_last_log_contains "Cached installer failed integrity verification. Re-downloading..."
if errorlevel 1 exit /b 1
exit /b 0

:subtest_corrupt_gnumake_cache
call ".\test_common.bat" run_and_capture populate_gnumake_cache "..\gnumake_download.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 exit /b 1
call ".\test_common.bat" corrupt_file "%GNUMAKE_EXE%"
if errorlevel 1 exit /b 1
call ".\test_common.bat" run_and_capture repair_gnumake_cache "..\gnumake_download.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 exit /b 1
call ".\test_common.bat" assert_last_log_contains "Cached GNU Make failed integrity verification. Re-downloading..."
if errorlevel 1 exit /b 1
exit /b 0

:fail
echo [test:missing_artifacts] FAIL
if defined TEST_LAST_LOG echo [test:missing_artifacts] See log: %TEST_LAST_LOG%

:end
popd >nul
exit /b %TEST_EXIT%