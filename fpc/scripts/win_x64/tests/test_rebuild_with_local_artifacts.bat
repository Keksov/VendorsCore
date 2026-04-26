@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "TEST_EXIT=1"
pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\test_common.bat" init_test rebuild_with_local_artifacts
if errorlevel 1 goto :fail

call ".\test_common.bat" assert_file_exists "%FPC_MAIN_FPC_EXE%"
if errorlevel 1 goto :missing_prereq
call ".\test_common.bat" resolve_latest_snapshot LATEST_SOURCE_SNAPSHOT
if errorlevel 1 goto :missing_prereq
call ".\test_common.bat" assert_main_matches_snapshot "%LATEST_SOURCE_SNAPSHOT%"
if errorlevel 1 goto :fail

for %%I in ("%LATEST_SOURCE_SNAPSHOT%") do set "LATEST_SOURCE_SNAPSHOT_NAME=%%~nxI"

call ".\test_common.bat" remove_path "%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture warm_build_skip_pack "..\fpc_main_build.bat" --skip-pack
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_MAIN_FPC_EXE%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_main_matches_snapshot "%LATEST_SOURCE_SNAPSHOT%"
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture warm_release_pack "..\fpc_release_pack.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_zip_contains "%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%" "fpc-main/%LATEST_SOURCE_SNAPSHOT_NAME%.zip"
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture warm_release_setup "..\fpc_release_setup.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_MAIN_FPC_EXE%"
if errorlevel 1 goto :fail

echo [test:rebuild_with_local_artifacts] PASS
set "TEST_EXIT=0"
goto :end

:missing_prereq
echo [test:rebuild_with_local_artifacts] Error: prerequisites are missing. Run test_clean_build_after_clone.bat first.
goto :fail

:fail
echo [test:rebuild_with_local_artifacts] FAIL
if defined TEST_LAST_LOG echo [test:rebuild_with_local_artifacts] See log: %TEST_LAST_LOG%

:end
popd >nul
exit /b %TEST_EXIT%