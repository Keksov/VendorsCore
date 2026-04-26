@echo off

if "%~1"=="" exit /b 0

set "TEST_COMMON_ACTION=%~1"
shift
goto :%TEST_COMMON_ACTION%

:init_test
set "TEST_NAME=%~1"
if not defined TEST_NAME (
    echo [test-common] Error: test name is required.
    exit /b 1
)

pushd "%~dp0.." >nul
if errorlevel 1 (
    echo [test-common] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

for %%I in ("%VENDOR_ROOT%") do set "VENDOR_ROOT=%%~fI"
for %%I in ("%DOWNLOADS_DIR%") do set "DOWNLOADS_DIR=%%~fI"
for %%I in ("%TOOLS_CACHE_DIR%") do set "TOOLS_CACHE_DIR=%%~fI"
for %%I in ("%BOOTSTRAP_CACHE_DIR%") do set "BOOTSTRAP_CACHE_DIR=%%~fI"
for %%I in ("%RELEASE_CACHE_DIR%") do set "RELEASE_CACHE_DIR=%%~fI"
for %%I in ("%SOURCES_DIR%") do set "SOURCES_DIR=%%~fI"
for %%I in ("%WORK_DIR%") do set "WORK_DIR=%%~fI"
for %%I in ("%BUILD_TEMP_DIR%") do set "BUILD_TEMP_DIR=%%~fI"
for %%I in ("%BOOTSTRAP_INSTALL_DIR%") do set "BOOTSTRAP_INSTALL_DIR=%%~fI"
for %%I in ("%FPC_BIN_TARGET_DIR%") do set "FPC_BIN_TARGET_DIR=%%~fI"
for %%I in ("%FPC_MAIN_SOURCE_DIR%") do set "FPC_MAIN_SOURCE_DIR=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_INSTALLER_PATH%") do set "FPC_BOOTSTRAP_INSTALLER_PATH=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_DIGEST_FILE%") do set "FPC_BOOTSTRAP_DIGEST_FILE=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_BIN_DIR%") do set "FPC_BOOTSTRAP_BIN_DIR=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_PPCROSSX64_EXE%") do set "FPC_BOOTSTRAP_PPCROSSX64_EXE=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_FPC_EXE%") do set "FPC_BOOTSTRAP_FPC_EXE=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_PPC386_EXE%") do set "FPC_BOOTSTRAP_PPC386_EXE=%%~fI"
for %%I in ("%FPC_MAIN_BIN_DIR%") do set "FPC_MAIN_BIN_DIR=%%~fI"
for %%I in ("%FPC_MAIN_FPC_EXE%") do set "FPC_MAIN_FPC_EXE=%%~fI"
for %%I in ("%FPC_MAIN_PPC_EXE%") do set "FPC_MAIN_PPC_EXE=%%~fI"
for %%I in ("%GNUMAKE_EXE%") do set "GNUMAKE_EXE=%%~fI"
for %%I in ("%GNUMAKE_DIGEST_FILE%") do set "GNUMAKE_DIGEST_FILE=%%~fI"

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"`) do set "TEST_STAMP=%%I"
if not defined TEST_STAMP set "TEST_STAMP=00000000-000000"

set "TEST_LOG_ROOT=%TEMP%\kkmindwave-fpc-tests"
if not exist "%TEST_LOG_ROOT%" mkdir "%TEST_LOG_ROOT%"
if errorlevel 1 (
    echo [test-common] Error: failed to create %TEST_LOG_ROOT%
    popd >nul
    exit /b 1
)

set "TEST_LOG_DIR=%TEST_LOG_ROOT%\%TEST_STAMP%_%TEST_NAME%"
mkdir "%TEST_LOG_DIR%" >nul 2>nul
if errorlevel 1 (
    echo [test-common] Error: failed to create %TEST_LOG_DIR%
    popd >nul
    exit /b 1
)

set "TEST_LAST_LOG="
set "TEST_LAST_EXIT="

echo [test:%TEST_NAME%] Log directory: %TEST_LOG_DIR%
popd >nul
exit /b 0

:run_and_capture
if not defined TEST_LOG_DIR (
    echo [test-common] Error: init_test must be called before run_and_capture.
    exit /b 1
)

set "RUN_LABEL=%~1"
if not defined RUN_LABEL (
    echo [test-common] Error: run label is required.
    exit /b 1
)

set "RUN_PROGRAM=%~2"
if not defined RUN_PROGRAM (
    echo [test-common] Error: program or script is required for %RUN_LABEL%.
    exit /b 1
)

set "RUN_COMMAND="%RUN_PROGRAM%""
if not "%~3"=="" set "RUN_COMMAND=%RUN_COMMAND% %3"
if not "%~4"=="" set "RUN_COMMAND=%RUN_COMMAND% %4"
if not "%~5"=="" set "RUN_COMMAND=%RUN_COMMAND% %5"
if not "%~6"=="" set "RUN_COMMAND=%RUN_COMMAND% %6"
if not "%~7"=="" set "RUN_COMMAND=%RUN_COMMAND% %7"
if not "%~8"=="" set "RUN_COMMAND=%RUN_COMMAND% %8"
if not "%~9"=="" set "RUN_COMMAND=%RUN_COMMAND% %9"

set "TEST_LAST_LOG=%TEST_LOG_DIR%\%RUN_LABEL%.log"

echo [test:%TEST_NAME%] Running %RUN_LABEL%...
cmd /d /s /c "%RUN_COMMAND%" > "%TEST_LAST_LOG%" 2>&1
set "TEST_LAST_EXIT=%errorlevel%"
echo [test:%TEST_NAME%] %RUN_LABEL% exit code: %TEST_LAST_EXIT%
exit /b 0

:assert_last_exit
if not defined TEST_LAST_EXIT (
    echo [test-common] Error: no previous command exit code was recorded.
    exit /b 1
)

if "%TEST_LAST_EXIT%"=="%~1" exit /b 0

echo [test:%TEST_NAME%] Error: expected last exit code %~1 but got %TEST_LAST_EXIT%.
if defined TEST_LAST_LOG echo [test:%TEST_NAME%] See log: %TEST_LAST_LOG%
exit /b 1

:assert_last_exit_nonzero
if not defined TEST_LAST_EXIT (
    echo [test-common] Error: no previous command exit code was recorded.
    exit /b 1
)

if not "%TEST_LAST_EXIT%"=="0" exit /b 0

echo [test:%TEST_NAME%] Error: expected a non-zero exit code.
if defined TEST_LAST_LOG echo [test:%TEST_NAME%] See log: %TEST_LAST_LOG%
exit /b 1

:assert_file_exists
if exist "%~f1" exit /b 0
echo [test:%TEST_NAME%] Error: expected file is missing: %~f1
exit /b 1

:assert_dir_exists
set "ASSERT_DIR=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$path = $env:ASSERT_DIR; if ($path) { $path = $path.Trim() }; if ($path -and (Test-Path -LiteralPath $path -PathType Container)) { exit 0 } exit 1" >nul 2>nul
if not errorlevel 1 exit /b 0
echo [test:%TEST_NAME%] Error: expected directory is missing: %ASSERT_DIR%
exit /b 1

:assert_not_exists
if exist "%~f1" (
    echo [test:%TEST_NAME%] Error: expected path to be absent: %~f1
    exit /b 1
)
exit /b 0

:assert_file_nonempty
if not exist "%~f1" (
    echo [test:%TEST_NAME%] Error: file is missing: %~f1
    exit /b 1
)

for %%I in ("%~f1") do if %%~zI gtr 0 exit /b 0

echo [test:%TEST_NAME%] Error: file is empty: %~f1
exit /b 1

:assert_text_in_file
if not exist "%~f1" (
    echo [test:%TEST_NAME%] Error: file is missing for text assertion: %~f1
    exit /b 1
)

findstr /c:"%~2" "%~f1" >nul 2>nul
if not errorlevel 1 exit /b 0

echo [test:%TEST_NAME%] Error: expected text was not found in %~f1
echo [test:%TEST_NAME%] Missing text: %~2
exit /b 1

:assert_last_log_contains
if not defined TEST_LAST_LOG (
    echo [test-common] Error: no previous command log was recorded.
    exit /b 1
)

call :assert_text_in_file "%TEST_LAST_LOG%" "%~1"
exit /b %errorlevel%

:assert_zip_contains
set "ASSERT_ZIP_PATH=%~f1"
set "ASSERT_ZIP_PATTERN=%~2"

if not exist "%ASSERT_ZIP_PATH%" (
    echo [test:%TEST_NAME%] Error: zip file is missing: %ASSERT_ZIP_PATH%
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip = [IO.Compression.ZipFile]::OpenRead($env:ASSERT_ZIP_PATH); try { $entry = $zip.Entries | Where-Object { $_.FullName -like $env:ASSERT_ZIP_PATTERN } | Select-Object -First 1; if (-not $entry) { exit 1 } } finally { $zip.Dispose() }"
if errorlevel 1 (
    echo [test:%TEST_NAME%] Error: zip entry matching %ASSERT_ZIP_PATTERN% was not found in %ASSERT_ZIP_PATH%
    exit /b 1
)

exit /b 0

:remove_path
set "REMOVE_TARGET=%~f1"
if not defined REMOVE_TARGET exit /b 0

if exist "%REMOVE_TARGET%\NUL" (
    attrib -r -s -h "%REMOVE_TARGET%" /s /d >nul 2>nul
    rd /s /q "%REMOVE_TARGET%" >nul 2>nul
)

if exist "%REMOVE_TARGET%" if not exist "%REMOVE_TARGET%\NUL" (
    attrib -r -s -h "%REMOVE_TARGET%" >nul 2>nul
    del /f /q "%REMOVE_TARGET%" >nul 2>nul
)

if exist "%REMOVE_TARGET%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; if (Test-Path -LiteralPath $env:REMOVE_TARGET) { Remove-Item -LiteralPath $env:REMOVE_TARGET -Recurse -Force }" >nul 2>nul
)

if exist "%REMOVE_TARGET%" (
    echo [test:%TEST_NAME%] Error: failed to remove %REMOVE_TARGET%
    exit /b 1
)

exit /b 0

:corrupt_file
if not exist "%~f1" (
    echo [test:%TEST_NAME%] Error: file is missing for corruption: %~f1
    exit /b 1
)

> "%~f1" echo CORRUPTED-FOR-TEST
if errorlevel 1 (
    echo [test:%TEST_NAME%] Error: failed to corrupt %~f1
    exit /b 1
)

exit /b 0

:resolve_latest_snapshot
set "LATEST_SNAPSHOT="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; if (Test-Path $env:SOURCES_DIR) { $item = Get-ChildItem -LiteralPath $env:SOURCES_DIR -Directory | Where-Object { $_.Name -like 'sources-*' } | Sort-Object Name -Descending | Select-Object -First 1; if ($item) { $item.FullName.Trim() } }"`) do set "LATEST_SNAPSHOT=%%I"

if not defined LATEST_SNAPSHOT exit /b 1

set "%~1=%LATEST_SNAPSHOT%"
exit /b 0

:ensure_latest_snapshot
call :resolve_latest_snapshot %~1
if not errorlevel 1 exit /b 0

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyyMMdd'"`) do set "ENSURE_SNAPSHOT_STAMP=%%I"
if not defined ENSURE_SNAPSHOT_STAMP (
    echo [test:%TEST_NAME%] Error: failed to resolve the snapshot date stamp.
    exit /b 1
)

set "ENSURE_SNAPSHOT_DIR=%SOURCES_DIR%\sources-%ENSURE_SNAPSHOT_STAMP%"
call :run_and_capture ensure_latest_snapshot "..\fpc_source_sync.bat" main --force "%ENSURE_SNAPSHOT_DIR%"
call :assert_last_exit 0
if errorlevel 1 exit /b 1

set "%~1=%ENSURE_SNAPSHOT_DIR%"
exit /b 0

:assert_main_matches_snapshot
if not exist "%FPC_MAIN_SOURCE_DIR%\.git" (
    echo [test:%TEST_NAME%] Error: main source tree is missing: %FPC_MAIN_SOURCE_DIR%
    exit /b 1
)

if not exist "%~f1\.git" (
    echo [test:%TEST_NAME%] Error: snapshot source tree is missing: %~f1
    exit /b 1
)

set "MAIN_COMMIT="
set "SNAPSHOT_COMMIT="
for /f "usebackq delims=" %%I in (`git -C "%FPC_MAIN_SOURCE_DIR%" rev-parse HEAD`) do set "MAIN_COMMIT=%%I"
for /f "usebackq delims=" %%I in (`git -C "%~f1" rev-parse HEAD`) do set "SNAPSHOT_COMMIT=%%I"

if not defined MAIN_COMMIT (
    echo [test:%TEST_NAME%] Error: failed to resolve main commit.
    exit /b 1
)

if not defined SNAPSHOT_COMMIT (
    echo [test:%TEST_NAME%] Error: failed to resolve snapshot commit.
    exit /b 1
)

if /I "%MAIN_COMMIT%"=="%SNAPSHOT_COMMIT%" exit /b 0

echo [test:%TEST_NAME%] Error: commit mismatch between main and snapshot.
echo [test:%TEST_NAME%]   main: %MAIN_COMMIT%
echo [test:%TEST_NAME%]   snapshot: %SNAPSHOT_COMMIT%
exit /b 1

:hard_reset_vendor_state
call :remove_path "%DOWNLOADS_DIR%"
if errorlevel 1 exit /b 1
call :remove_path "%SOURCES_DIR%"
if errorlevel 1 exit /b 1
call :remove_path "%WORK_DIR%"
if errorlevel 1 exit /b 1
call :remove_path "%BUILD_TEMP_DIR%"
if errorlevel 1 exit /b 1
call :remove_path "%BOOTSTRAP_INSTALL_DIR%"
if errorlevel 1 exit /b 1
call :remove_path "%FPC_BIN_TARGET_DIR%"
if errorlevel 1 exit /b 1
call :remove_path "%VENDOR_ROOT%\%FPC_MAIN_ARCHIVE_NAME%"
if errorlevel 1 exit /b 1
exit /b 0