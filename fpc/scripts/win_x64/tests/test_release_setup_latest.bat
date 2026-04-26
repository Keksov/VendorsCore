@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "TEST_EXIT=1"
pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\test_common.bat" init_test release_setup_latest
if errorlevel 1 goto :fail

call ".\test_common.bat" remove_path "%WORK_DIR%"
if errorlevel 1 goto :fail
call ".\test_common.bat" remove_path "%FPC_BIN_TARGET_DIR%"
if errorlevel 1 goto :fail
call ".\test_common.bat" remove_path "%RELEASE_CACHE_DIR%\latest"
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture release_setup_latest "..\fpc_release_setup.bat"
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail

call ".\test_common.bat" assert_file_exists "%RELEASE_CACHE_DIR%\latest\%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%RELEASE_CACHE_DIR%\latest\%FPC_MAIN_ARCHIVE_NAME%.digest"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_MAIN_FPC_EXE%"
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_exists "%FPC_MAIN_PPC_EXE%"
if errorlevel 1 goto :fail

call ".\test_common.bat" run_and_capture release_setup_version "%FPC_MAIN_FPC_EXE%" -iV
call ".\test_common.bat" assert_last_exit 0
if errorlevel 1 goto :fail
call ".\test_common.bat" assert_file_nonempty "%TEST_LAST_LOG%"
if errorlevel 1 goto :fail

echo [test:release_setup_latest] PASS
set "TEST_EXIT=0"
goto :end

:fail
echo [test:release_setup_latest] FAIL
if defined TEST_LAST_LOG echo [test:release_setup_latest] See log: %TEST_LAST_LOG%

:end
popd >nul
exit /b %TEST_EXIT%