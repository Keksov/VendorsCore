@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "ZIP_FILE=%~1"
set "DEST_DIR=%~2"

if "%ZIP_FILE%"=="" (
	echo [unzip] Error: missing zip file path.
	exit /b 1
)

if "%DEST_DIR%"=="" (
	echo [unzip] Error: missing destination directory.
	exit /b 1
)

if not exist "%ZIP_FILE%" (
	echo [unzip] Error: zip file not found: %ZIP_FILE%
	exit /b 1
)

if exist "%DEST_DIR%" rd /s /q "%DEST_DIR%" >nul 2>nul
mkdir "%DEST_DIR%"
if errorlevel 1 (
	echo [unzip] Error: failed to create destination directory: %DEST_DIR%
	exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Expand-Archive -LiteralPath $env:ZIP_FILE -DestinationPath $env:DEST_DIR -Force"
if errorlevel 1 (
	echo [unzip] Error: failed to extract %ZIP_FILE%
	if exist "%DEST_DIR%" rd /s /q "%DEST_DIR%" >nul 2>nul
	exit /b 1
)

exit /b 0