@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to enter the script directory.
    exit /b 1
)

call ".\common.bat"

set "SKIP_PACK=0"

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--skip-pack" (
    set "SKIP_PACK=1"
    shift
    goto :parse_args
)

echo [fpc-main-build] Error: unknown argument %~1
goto :usage

:args_done
call ".\gnumake_download.bat"
if errorlevel 1 goto :fail

call ".\fpc_bootstrap_build.bat"
if errorlevel 1 goto :fail

call :resolve_source_snapshot
if errorlevel 1 goto :fail

call :prepare_main_source_tree
if errorlevel 1 goto :fail

for %%I in ("%GNUMAKE_EXE%") do set "GNUMAKE_EXE_ABS=%%~fI"
for %%I in ("%FPC_BOOTSTRAP_FPC_EXE%") do set "BOOTSTRAP_EXE_ABS=%%~fI"
for %%I in ("%FPC_MAIN_SOURCE_DIR%") do set "FPC_MAIN_SOURCE_DIR_ABS=%%~fI"
for %%I in ("%FPC_BIN_TARGET_DIR%") do set "FPC_BIN_TARGET_DIR_ABS=%%~fI"
for %%I in ("%FPC_MAIN_STAGE_DIR%") do set "FPC_MAIN_STAGE_DIR_ABS=%%~fI"

set "FPC_MAIN_SOURCE_DIR_FWD=%FPC_MAIN_SOURCE_DIR_ABS:\=/%"
set "NEW_FPC=%FPC_MAIN_SOURCE_DIR_ABS%\compiler\ppcx64.exe"
set "NEW_FPCMAKE=%FPC_MAIN_SOURCE_DIR_ABS%\utils\fpcm\bin\%FPC_TARGET_SUFFIX%\fpcmake.exe"
set "SOURCE_PACKAGES_INSTALL_PREFIX=."
set "SOURCE_PACKAGES_INSTALL_BASEDIR=packages"
set "SOURCE_PACKAGES_INSTALL_BINDIR=packages/bin"
set "SOURCE_PACKAGES_INSTALL_UNITDIR=packages/units/%FPC_TARGET_SUFFIX%"

pushd "%FPC_MAIN_SOURCE_DIR_ABS%" >nul
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to enter %FPC_MAIN_SOURCE_DIR_ABS%
    goto :fail
)

echo [fpc-main-build] Building compiler cycle...
"%GNUMAKE_EXE_ABS%" -C compiler cycle PP="%BOOTSTRAP_EXE_ABS%" BASEDIR="%FPC_MAIN_SOURCE_DIR_FWD%/compiler" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS%
if errorlevel 1 goto :build_fail

if not exist "%NEW_FPC%" (
    echo [fpc-main-build] Error: expected stage-3 compiler was not built: %NEW_FPC%
    goto :build_fail
)

set "PATH=%FPC_MAIN_SOURCE_DIR_ABS%\compiler;%FPC_MAIN_SOURCE_DIR_ABS%\compiler\utils;%PATH%"

echo [fpc-main-build] Building RTL...
"%GNUMAKE_EXE_ABS%" -C rtl all PP="%NEW_FPC%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS%
if errorlevel 1 goto :build_fail

echo [fpc-main-build] Building packages...
"%GNUMAKE_EXE_ABS%" -C packages all FPC="%NEW_FPC%" FPCFPMAKE="%NEW_FPC%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS%
if errorlevel 1 goto :build_fail

echo [fpc-main-build] Preparing installed package layout for utils...
"%GNUMAKE_EXE_ABS%" -C packages install FPC="%NEW_FPC%" FPCFPMAKE="%NEW_FPC%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS% INSTALL_PREFIX="%SOURCE_PACKAGES_INSTALL_PREFIX%" INSTALL_BASEDIR="%SOURCE_PACKAGES_INSTALL_BASEDIR%" INSTALL_BINDIR="%SOURCE_PACKAGES_INSTALL_BINDIR%" INSTALL_UNITDIR="%SOURCE_PACKAGES_INSTALL_UNITDIR%"
if errorlevel 1 goto :build_fail

echo [fpc-main-build] Building utils...
"%GNUMAKE_EXE_ABS%" -C utils all PP="%NEW_FPC%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS%
if errorlevel 1 goto :build_fail

if not exist "%NEW_FPCMAKE%" (
    echo [fpc-main-build] Error: expected fpcmake was not built: %NEW_FPCMAKE%
    goto :build_fail
)

popd >nul

if exist "%FPC_MAIN_STAGE_DIR_ABS%" rd /s /q "%FPC_MAIN_STAGE_DIR_ABS%" >nul 2>nul
if not exist "%BUILD_TEMP_DIR%" mkdir "%BUILD_TEMP_DIR%"
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to create %BUILD_TEMP_DIR%
    goto :fail
)

pushd "%FPC_MAIN_SOURCE_DIR_ABS%" >nul
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to re-enter %FPC_MAIN_SOURCE_DIR_ABS%
    goto :fail
)

echo [fpc-main-build] Installing compiler into stage dir...
"%GNUMAKE_EXE_ABS%" -C compiler install FPC="%NEW_FPC%" PP="%NEW_FPC%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS% INSTALL_PREFIX="%FPC_MAIN_STAGE_DIR_ABS%"
if errorlevel 1 goto :build_fail

echo [fpc-main-build] Installing RTL into stage dir...
"%GNUMAKE_EXE_ABS%" -C rtl install PP="%NEW_FPC%" FPCMAKE="%NEW_FPCMAKE%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS% INSTALL_PREFIX="%FPC_MAIN_STAGE_DIR_ABS%"
if errorlevel 1 goto :build_fail

echo [fpc-main-build] Installing packages into stage dir...
"%GNUMAKE_EXE_ABS%" -C packages install FPC="%NEW_FPC%" FPCFPMAKE="%NEW_FPC%" FPCMAKE="%NEW_FPCMAKE%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS% INSTALL_PREFIX="%FPC_MAIN_STAGE_DIR_ABS%"
if errorlevel 1 goto :build_fail

echo [fpc-main-build] Installing utils into stage dir...
"%GNUMAKE_EXE_ABS%" -C utils install PP="%NEW_FPC%" CPU_TARGET=%FPC_TARGET_CPU% OS_TARGET=%FPC_TARGET_OS% INSTALL_PREFIX="%FPC_MAIN_STAGE_DIR_ABS%"
if errorlevel 1 goto :build_fail

popd >nul

if exist "%FPC_BIN_TARGET_DIR_ABS%" rd /s /q "%FPC_BIN_TARGET_DIR_ABS%" >nul 2>nul
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to remove %FPC_BIN_TARGET_DIR_ABS%
    goto :fail
)

echo [fpc-main-build] Finalizing staged toolchain into %FPC_BIN_TARGET_DIR_ABS%...
move "%FPC_MAIN_STAGE_DIR_ABS%" "%FPC_BIN_TARGET_DIR_ABS%" >nul
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to move %FPC_MAIN_STAGE_DIR_ABS% to %FPC_BIN_TARGET_DIR_ABS%.
    goto :fail
)

if not exist "%FPC_MAIN_FPC_EXE%" (
    echo [fpc-main-build] Error: staged toolchain is missing %FPC_MAIN_FPC_EXE%
    goto :fail
)

if not exist "%FPC_MAIN_PPC_EXE%" (
    echo [fpc-main-build] Error: staged toolchain is missing %FPC_MAIN_PPC_EXE%
    goto :fail
)

if "%SKIP_PACK%"=="1" (
    call ".\fpc_source_pack.bat" "%FPC_SOURCE_SNAPSHOT_DIR%" "%FPC_BIN_TARGET_DIR_ABS%"
    if errorlevel 1 goto :fail

    echo [fpc-main-build] Ready: %FPC_BIN_TARGET_DIR_ABS%
    popd >nul
    exit /b 0
)

call ".\fpc_release_pack.bat"
if errorlevel 1 goto :fail

echo [fpc-main-build] Ready: %FPC_BIN_TARGET_DIR_ABS%
popd >nul
exit /b 0

:resolve_source_snapshot
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyyMMdd'"`) do set "FPC_SOURCE_SNAPSHOT_STAMP=%%I"
if not defined FPC_SOURCE_SNAPSHOT_STAMP (
    echo [fpc-main-build] Error: failed to resolve the source snapshot date stamp.
    exit /b 1
)

set "FPC_SOURCE_SNAPSHOT_NAME=sources-%FPC_SOURCE_SNAPSHOT_STAMP%"
set "FPC_SOURCE_SNAPSHOT_DIR=%SOURCES_DIR%\%FPC_SOURCE_SNAPSHOT_NAME%"
exit /b 0

:prepare_main_source_tree
call ".\fpc_source_sync.bat" main --force "%FPC_SOURCE_SNAPSHOT_DIR%"
if errorlevel 1 exit /b 1

set "FPC_SOURCE_SNAPSHOT_COMMIT="
for /f "usebackq delims=" %%I in (`git -C "%FPC_SOURCE_SNAPSHOT_DIR%" rev-parse HEAD`) do set "FPC_SOURCE_SNAPSHOT_COMMIT=%%I"
if not defined FPC_SOURCE_SNAPSHOT_COMMIT (
    echo [fpc-main-build] Error: failed to resolve the commit for %FPC_SOURCE_SNAPSHOT_DIR%
    exit /b 1
)

if exist "%FPC_MAIN_SOURCE_DIR%\.git" goto :update_main_source_tree

if exist "%FPC_MAIN_SOURCE_DIR%" (
    echo [fpc-main-build] Error: %FPC_MAIN_SOURCE_DIR% exists but is not a git worktree.
    exit /b 1
)

echo [fpc-main-build] Initializing main source tree from %FPC_SOURCE_SNAPSHOT_NAME%...
call :mirror_directory "%FPC_SOURCE_SNAPSHOT_DIR%" "%FPC_MAIN_SOURCE_DIR%"
exit /b %ERRORLEVEL%

:update_main_source_tree
echo [fpc-main-build] Updating main source tree to %FPC_SOURCE_SNAPSHOT_COMMIT%...
pushd "%FPC_MAIN_SOURCE_DIR%" >nul
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to enter %FPC_MAIN_SOURCE_DIR%
    exit /b 1
)

git fetch --depth 1 origin "%FPC_MAIN_SOURCE_REF%"
if errorlevel 1 goto :update_main_source_tree_fail

set "FPC_MAIN_FETCH_HEAD="
for /f "usebackq delims=" %%I in (`git rev-parse FETCH_HEAD`) do set "FPC_MAIN_FETCH_HEAD=%%I"
if not defined FPC_MAIN_FETCH_HEAD (
    echo [fpc-main-build] Error: failed to resolve FETCH_HEAD for %FPC_MAIN_SOURCE_DIR%
    goto :update_main_source_tree_fail
)

git checkout -f "%FPC_MAIN_SOURCE_REF%"
if errorlevel 1 goto :update_main_source_tree_fail

if /I "%FPC_MAIN_FETCH_HEAD%"=="%FPC_SOURCE_SNAPSHOT_COMMIT%" (
    git reset --hard "%FPC_MAIN_FETCH_HEAD%"
    if errorlevel 1 goto :update_main_source_tree_fail

    git clean -fdx
    if errorlevel 1 goto :update_main_source_tree_fail

    popd >nul
    exit /b 0
)

popd >nul
echo [fpc-main-build] Warning: fetched main commit %FPC_MAIN_FETCH_HEAD% differs from %FPC_SOURCE_SNAPSHOT_COMMIT%; refreshing main from the dated snapshot.

rd /s /q "%FPC_MAIN_SOURCE_DIR%" >nul 2>nul
if exist "%FPC_MAIN_SOURCE_DIR%" (
    echo [fpc-main-build] Error: failed to remove %FPC_MAIN_SOURCE_DIR%
    exit /b 1
)

call :mirror_directory "%FPC_SOURCE_SNAPSHOT_DIR%" "%FPC_MAIN_SOURCE_DIR%"
exit /b %ERRORLEVEL%

:update_main_source_tree_fail
popd >nul
exit /b 1

:mirror_directory
for %%I in ("%~2") do set "MIRROR_PARENT=%%~dpI"
if not exist "%MIRROR_PARENT%" mkdir "%MIRROR_PARENT%"
if errorlevel 1 (
    echo [fpc-main-build] Error: failed to create %MIRROR_PARENT%
    exit /b 1
)

robocopy "%~1" "%~2" /MIR /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% geq 8 (
    echo [fpc-main-build] Error: failed to mirror %~1 into %~2
    exit /b 1
)

exit /b 0

:usage
echo Usage: fpc_main_build.bat [--skip-pack]
goto :fail

:build_fail
popd >nul

:fail
if exist "%FPC_MAIN_STAGE_DIR_ABS%" rd /s /q "%FPC_MAIN_STAGE_DIR_ABS%" >nul 2>nul
popd >nul
exit /b 1