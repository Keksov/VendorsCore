@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [release-asset-digest] Error: failed to enter the script directory.
	exit /b 1
)

call ".\common.bat"

set "ASSET_NAME="
set "OUTPUT_PATH="
set "RELEASE_REF="
set "FORCE_REFRESH=0"

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--asset" (
	if "%~2"=="" goto :missing_value
	set "ASSET_NAME=%~2"
	shift
	shift
	goto :parse_args
)

if /I "%~1"=="--out" (
	if "%~2"=="" goto :missing_value
	set "OUTPUT_PATH=%~2"
	shift
	shift
	goto :parse_args
)

if /I "%~1"=="--tag" (
	if "%~2"=="" goto :missing_value
	set "RELEASE_REF=%~2"
	shift
	shift
	goto :parse_args
)

if /I "%~1"=="--latest" (
	set "RELEASE_REF=latest"
	shift
	goto :parse_args
)

if /I "%~1"=="--force" (
	set "FORCE_REFRESH=1"
	shift
	goto :parse_args
)

echo [release-asset-digest] Error: unknown argument %~1
goto :usage

:missing_value
echo [release-asset-digest] Error: missing value for %~1
goto :usage

:args_done
if not defined ASSET_NAME (
	echo [release-asset-digest] Error: --asset is required.
	goto :usage
)

if not defined OUTPUT_PATH (
	echo [release-asset-digest] Error: --out is required.
	goto :usage
)

if not defined RELEASE_REF set "RELEASE_REF=latest"

set "ALLOW_CACHE=1"
if /I "%RELEASE_REF%"=="latest" set "ALLOW_CACHE=0"

for %%I in ("%OUTPUT_PATH%") do set "OUTPUT_DIR=%%~dpI"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if errorlevel 1 (
	echo [release-asset-digest] Error: failed to create output directory %OUTPUT_DIR%
	goto :fail
)

if "%FORCE_REFRESH%"=="0" if "%ALLOW_CACHE%"=="1" if exist "%OUTPUT_PATH%" (
	echo [release-asset-digest] Using cached digest: %OUTPUT_PATH%
	goto :success
)

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" (
	where powershell.exe >nul 2>nul
	if errorlevel 1 (
		echo [release-asset-digest] Error: powershell.exe was not found.
		goto :fail
	)
	set "POWERSHELL_EXE=powershell.exe"
)

if not exist "%~dp0get_release_asset_digest.ps1" (
	echo [release-asset-digest] Error: helper script was not found: %~dp0get_release_asset_digest.ps1
	goto :fail
)

set "TEMP_OUTPUT=%OUTPUT_PATH%.download"
if exist "%TEMP_OUTPUT%" del /f /q "%TEMP_OUTPUT%" >nul 2>nul

"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0get_release_asset_digest.ps1" "%RELEASE_REPO%" "%RELEASE_REF%" "%ASSET_NAME%" > "%TEMP_OUTPUT%" 2>nul
set "DIGEST_RESULT=%errorlevel%"

if "%DIGEST_RESULT%"=="0" goto :validate_output

if "%DIGEST_RESULT%"=="3" (
	echo [release-asset-digest] Error: asset %ASSET_NAME% was not found in release ref %RELEASE_REF%.
	goto :fail
)

if "%DIGEST_RESULT%"=="4" (
	echo [release-asset-digest] Error: release asset %ASSET_NAME% does not expose a digest in GitHub metadata.
	goto :fail
)

if "%DIGEST_RESULT%"=="5" (
	echo [release-asset-digest] Error: release ref %RELEASE_REF% was not found. Ensure the release tag is published and accessible via the GitHub API.
	goto :fail
)

echo [release-asset-digest] Error: failed to query GitHub release metadata for %ASSET_NAME%.
goto :fail

:validate_output
set "ASSET_DIGEST="
set /p ASSET_DIGEST=<"%TEMP_OUTPUT%"
if not defined ASSET_DIGEST (
	echo [release-asset-digest] Error: digest output is empty for %ASSET_NAME%.
	goto :fail
)

move /y "%TEMP_OUTPUT%" "%OUTPUT_PATH%" >nul
if errorlevel 1 (
	echo [release-asset-digest] Error: failed to move %TEMP_OUTPUT% to %OUTPUT_PATH%
	goto :fail
)

echo [release-asset-digest] Saved %ASSET_NAME% digest to %OUTPUT_PATH%
goto :success

:usage
echo Usage: release_asset_digest.bat --asset NAME --out PATH [--latest ^| --tag TAG] [--force]
goto :fail

:fail
if exist "%TEMP_OUTPUT%" del /f /q "%TEMP_OUTPUT%" >nul 2>nul
popd >nul
exit /b 1

:success
popd >nul
exit /b 0