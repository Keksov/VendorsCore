@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [gnumake] Error: failed to enter the script directory.
	exit /b 1
)

call ".\common.bat"

if not exist "%TOOLS_CACHE_DIR%" mkdir "%TOOLS_CACHE_DIR%"
if errorlevel 1 (
	echo [gnumake] Error: failed to create %TOOLS_CACHE_DIR%
	popd >nul
	exit /b 1
)

call ".\release_asset_digest.bat" --asset "%GNUMAKE_ASSET_NAME%" --out "%GNUMAKE_DIGEST_FILE%" --tag "%GNUMAKE_RELEASE_TAG%"
if errorlevel 1 goto :fail

call :load_expected_digest "%GNUMAKE_DIGEST_FILE%"
if errorlevel 1 goto :fail

if exist "%GNUMAKE_EXE%" (
	call ".\verify_hash.bat" "gnumake" "%GNUMAKE_EXE%" "%GNUMAKE_DIGEST_ALGORITHM%" "%GNUMAKE_DIGEST_HASH%" "GNU Make"
	if errorlevel 1 (
		echo [gnumake] Cached GNU Make failed integrity verification. Re-downloading...
		del /f /q "%GNUMAKE_EXE%" >nul 2>nul
		call ".\release_asset_digest.bat" --asset "%GNUMAKE_ASSET_NAME%" --out "%GNUMAKE_DIGEST_FILE%" --tag "%GNUMAKE_RELEASE_TAG%" --force
		if errorlevel 1 goto :fail
		call :load_expected_digest "%GNUMAKE_DIGEST_FILE%"
		if errorlevel 1 goto :fail
	)

	"%GNUMAKE_EXE%" --version >nul 2>nul
	if not errorlevel 1 (
		echo [gnumake] Using cached GNU Make: %GNUMAKE_EXE%
		popd >nul
		exit /b 0
	)

	echo [gnumake] Cached GNU Make is invalid. Re-downloading...
	del /f /q "%GNUMAKE_EXE%" >nul 2>nul
)

echo [gnumake] Downloading GNU Make from release asset...
call ".\release_asset_download.bat" --asset "%GNUMAKE_ASSET_NAME%" --out "%GNUMAKE_EXE%" --tag "%GNUMAKE_RELEASE_TAG%" --force
if errorlevel 1 (
	echo [gnumake] Error: failed to download GNU Make asset %GNUMAKE_ASSET_NAME% from release tag %GNUMAKE_RELEASE_TAG%
	goto :fail
)

call ".\verify_hash.bat" "gnumake" "%GNUMAKE_EXE%" "%GNUMAKE_DIGEST_ALGORITHM%" "%GNUMAKE_DIGEST_HASH%" "GNU Make"
if errorlevel 1 goto :fail

"%GNUMAKE_EXE%" --version >nul 2>nul
if errorlevel 1 (
	echo [gnumake] Error: downloaded GNU Make did not pass verification.
	goto :fail
)

echo [gnumake] Ready: %GNUMAKE_EXE%
popd >nul
exit /b 0

:fail
popd >nul
exit /b 1

:load_expected_digest
set "GNUMAKE_DIGEST="
set "GNUMAKE_DIGEST_ALGORITHM="
set "GNUMAKE_DIGEST_HASH="

if not exist "%~1" (
	echo [gnumake] Error: digest file was not found: %~1
	exit /b 1
)

set /p GNUMAKE_DIGEST=<"%~1"
if not defined GNUMAKE_DIGEST (
	echo [gnumake] Error: digest file is empty: %~1
	exit /b 1
)

for /f "tokens=1,2 delims=:" %%A in ("%GNUMAKE_DIGEST%") do (
	set "GNUMAKE_DIGEST_ALGORITHM=%%A"
	set "GNUMAKE_DIGEST_HASH=%%B"
)

if not defined GNUMAKE_DIGEST_ALGORITHM (
	echo [gnumake] Error: digest is missing an algorithm: %GNUMAKE_DIGEST%
	exit /b 1
)

if not defined GNUMAKE_DIGEST_HASH (
	echo [gnumake] Error: digest is missing a hash value: %GNUMAKE_DIGEST%
	exit /b 1
)

exit /b 0