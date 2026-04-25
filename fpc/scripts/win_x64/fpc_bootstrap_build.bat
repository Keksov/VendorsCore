@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [fpc-bootstrap] Error: failed to enter the script directory.
	exit /b 1
)

call ".\common.bat"

if exist "%FPC_BOOTSTRAP_FPC_EXE%" if exist "%FPC_BOOTSTRAP_PPCROSSX64_EXE%" (
	echo [fpc-bootstrap] Using existing bootstrap compiler: %FPC_BOOTSTRAP_FPC_EXE%
	goto :success
)

if not exist "%BOOTSTRAP_CACHE_DIR%" mkdir "%BOOTSTRAP_CACHE_DIR%"
if errorlevel 1 (
	echo [fpc-bootstrap] Error: failed to create %BOOTSTRAP_CACHE_DIR%
	goto :fail
)

call ".\release_asset_digest.bat" --asset "%FPC_BOOTSTRAP_ASSET_NAME%" --out "%FPC_BOOTSTRAP_DIGEST_FILE%" --tag "%FPC_BOOTSTRAP_RELEASE_TAG%"
if errorlevel 1 goto :fail

call :load_expected_digest "%FPC_BOOTSTRAP_DIGEST_FILE%"
if errorlevel 1 goto :fail

if exist "%FPC_BOOTSTRAP_INSTALLER_PATH%" (
	call ".\verify_hash.bat" "fpc-bootstrap" "%FPC_BOOTSTRAP_INSTALLER_PATH%" "%FPC_BOOTSTRAP_DIGEST_ALGORITHM%" "%FPC_BOOTSTRAP_DIGEST_HASH%" "bootstrap installer"
	if errorlevel 1 (
		echo [fpc-bootstrap] Cached installer failed integrity verification. Re-downloading...
		del /f /q "%FPC_BOOTSTRAP_INSTALLER_PATH%" >nul 2>nul
		call ".\release_asset_digest.bat" --asset "%FPC_BOOTSTRAP_ASSET_NAME%" --out "%FPC_BOOTSTRAP_DIGEST_FILE%" --tag "%FPC_BOOTSTRAP_RELEASE_TAG%" --force
		if errorlevel 1 goto :fail
		call :load_expected_digest "%FPC_BOOTSTRAP_DIGEST_FILE%"
		if errorlevel 1 goto :fail
	)
)

if not exist "%FPC_BOOTSTRAP_INSTALLER_PATH%" (
	call ".\release_asset_download.bat" --asset "%FPC_BOOTSTRAP_ASSET_NAME%" --out "%FPC_BOOTSTRAP_INSTALLER_PATH%" --tag "%FPC_BOOTSTRAP_RELEASE_TAG%"
	if errorlevel 1 (
		echo [fpc-bootstrap] Error: bootstrap installer is unavailable. Publish %FPC_BOOTSTRAP_ASSET_NAME% to the %FPC_BOOTSTRAP_RELEASE_TAG% release tag or place it into %BOOTSTRAP_CACHE_DIR%.
		goto :fail
	)
) else (
	echo [fpc-bootstrap] Using cached installer: %FPC_BOOTSTRAP_INSTALLER_PATH%
)

call ".\verify_hash.bat" "fpc-bootstrap" "%FPC_BOOTSTRAP_INSTALLER_PATH%" "%FPC_BOOTSTRAP_DIGEST_ALGORITHM%" "%FPC_BOOTSTRAP_DIGEST_HASH%" "bootstrap installer"
if errorlevel 1 goto :fail

if exist "%BOOTSTRAP_INSTALL_DIR%" rd /s /q "%BOOTSTRAP_INSTALL_DIR%" >nul 2>nul

echo [fpc-bootstrap] Installing bootstrap compiler...
"%FPC_BOOTSTRAP_INSTALLER_PATH%" /DIR="%BOOTSTRAP_INSTALL_DIR%" /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
if errorlevel 1 (
	echo [fpc-bootstrap] Error: installer execution failed.
	goto :fail
)

if not exist "%FPC_BOOTSTRAP_FPC_EXE%" (
	echo [fpc-bootstrap] Error: expected bootstrap wrapper was not installed: %FPC_BOOTSTRAP_FPC_EXE%
	goto :fail
)

if not exist "%FPC_BOOTSTRAP_PPCROSSX64_EXE%" (
	echo [fpc-bootstrap] Error: expected bootstrap compiler was not installed: %FPC_BOOTSTRAP_PPCROSSX64_EXE%
	goto :fail
)

echo [fpc-bootstrap] Ready: %FPC_BOOTSTRAP_FPC_EXE%
echo [fpc-bootstrap] Cross compiler: %FPC_BOOTSTRAP_PPCROSSX64_EXE%

:success
popd >nul
exit /b 0

:fail
popd >nul
exit /b 1

:load_expected_digest
set "FPC_BOOTSTRAP_DIGEST="
set "FPC_BOOTSTRAP_DIGEST_ALGORITHM="
set "FPC_BOOTSTRAP_DIGEST_HASH="

if not exist "%~1" (
	echo [fpc-bootstrap] Error: digest file was not found: %~1
	exit /b 1
)

set /p FPC_BOOTSTRAP_DIGEST=<"%~1"
if not defined FPC_BOOTSTRAP_DIGEST (
	echo [fpc-bootstrap] Error: digest file is empty: %~1
	exit /b 1
)

for /f "tokens=1,2 delims=:" %%A in ("%FPC_BOOTSTRAP_DIGEST%") do (
	set "FPC_BOOTSTRAP_DIGEST_ALGORITHM=%%A"
	set "FPC_BOOTSTRAP_DIGEST_HASH=%%B"
)

if not defined FPC_BOOTSTRAP_DIGEST_ALGORITHM (
	echo [fpc-bootstrap] Error: digest is missing an algorithm: %FPC_BOOTSTRAP_DIGEST%
	exit /b 1
)

if not defined FPC_BOOTSTRAP_DIGEST_HASH (
	echo [fpc-bootstrap] Error: digest is missing a hash value: %FPC_BOOTSTRAP_DIGEST%
	exit /b 1
)

exit /b 0