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

call ".\fpc_source_sync.bat" main --force
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
    echo [fpc-main-build] Ready: %FPC_BIN_TARGET_DIR_ABS%
    popd >nul
    exit /b 0
)

call ".\fpc_release_pack.bat"
if errorlevel 1 goto :fail

echo [fpc-main-build] Ready: %FPC_BIN_TARGET_DIR_ABS%
popd >nul
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