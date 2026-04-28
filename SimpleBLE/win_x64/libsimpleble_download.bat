@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [simpleble] Error: failed to enter the script directory.
	exit /b 1
)

set "SIMPLEBLE_REPO=simpleble/simpleble"
set "SIMPLEBLE_TAG=v0.12.1"
set "SIMPLEBLE_ZIP_NAME=libsimplecble_windows-x64.zip"
set "DOWNLOAD_DIR=downloads"
set "EXTRACT_DIR=libsimpleble"
set "ZIP_PATH=%DOWNLOAD_DIR%\%SIMPLEBLE_ZIP_NAME%"
set "RELEASE_ASSET_DOWNLOAD=..\..\common\win\release_asset_download.bat"
set "EXIT_CODE=0"
set "FAIL_MESSAGE="

if not exist "%RELEASE_ASSET_DOWNLOAD%" (
	set "FAIL_MESSAGE=Missing helper script: %RELEASE_ASSET_DOWNLOAD%."
	goto :fail
)

if not exist "%DOWNLOAD_DIR%" (
	mkdir "%DOWNLOAD_DIR%"
	if errorlevel 1 (
		set "FAIL_MESSAGE=Failed to create download directory: %DOWNLOAD_DIR%."
		goto :fail
	)
)

call "%RELEASE_ASSET_DOWNLOAD%" --repo "%SIMPLEBLE_REPO%" --asset "%SIMPLEBLE_ZIP_NAME%" --out "%ZIP_PATH%" --tag "%SIMPLEBLE_TAG%"
if errorlevel 1 (
	set "USE_CACHED_ZIP=0"
	if exist "%ZIP_PATH%" (
		for %%A in ("%ZIP_PATH%") do if %%~zA GTR 0 set "USE_CACHED_ZIP=1"
	)
	if "%USE_CACHED_ZIP%"=="1" (
		echo [simpleble] Warning: verified download failed, using cached archive %ZIP_PATH%.
	) else (
		set "FAIL_MESSAGE=Failed to download %SIMPLEBLE_ZIP_NAME% and no usable cache was found."
		goto :fail
	)
)

echo [simpleble] Extracting %SIMPLEBLE_ZIP_NAME%...
if exist "%EXTRACT_DIR%" rd /s /q "%EXTRACT_DIR%" >nul 2>nul
mkdir "%EXTRACT_DIR%"
if errorlevel 1 (
	set "FAIL_MESSAGE=Failed to create extraction directory: %EXTRACT_DIR%."
	goto :fail
)

set "ZIP_FILE=%ZIP_PATH%"
set "DEST_DIR=%EXTRACT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Expand-Archive -LiteralPath $env:ZIP_FILE -DestinationPath $env:DEST_DIR -Force"
if errorlevel 1 (
	set "FAIL_MESSAGE=Failed to extract %SIMPLEBLE_ZIP_NAME%."
	if exist "%EXTRACT_DIR%" rd /s /q "%EXTRACT_DIR%" >nul 2>nul
	goto :fail
)

echo [simpleble] Ready: %EXTRACT_DIR%
call :cleanup_cache
popd >nul
exit /b 0

:cleanup_cache
if exist "%ZIP_PATH%" del /f /q "%ZIP_PATH%" >nul 2>nul
if exist "%DOWNLOAD_DIR%" rd "%DOWNLOAD_DIR%" >nul 2>nul
exit /b 0

:fail
set "EXIT_CODE=1"
call :cleanup_cache
if not defined FAIL_MESSAGE set "FAIL_MESSAGE=Setup failed."
echo [simpleble] Error: %FAIL_MESSAGE%
popd >nul
exit /b 1
