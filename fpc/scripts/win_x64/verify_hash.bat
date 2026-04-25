@echo off
setlocal EnableExtensions DisableDelayedExpansion

if "%~5"=="" goto :usage

set "VERIFY_TAG=%~1"
set "VERIFY_PATH=%~f2"
set "VERIFY_ALGORITHM=%~3"
set "VERIFY_EXPECTED=%~4"
set "VERIFY_LABEL=%~5"

if not exist "%VERIFY_PATH%" (
	echo [%VERIFY_TAG%] Error: file was not found for %VERIFY_LABEL% verification: %VERIFY_PATH%
	exit /b 1
)

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" (
	where powershell.exe >nul 2>nul
	if errorlevel 1 (
		echo [%VERIFY_TAG%] Error: powershell.exe was not found.
		exit /b 1
	)
	set "POWERSHELL_EXE=powershell.exe"
)

if not exist "%~dp0get_file_hash.ps1" (
	echo [%VERIFY_TAG%] Error: helper script was not found: %~dp0get_file_hash.ps1
	exit /b 1
)

"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0get_file_hash.ps1" "%VERIFY_PATH%" "%VERIFY_ALGORITHM%" "%VERIFY_EXPECTED%" >nul 2>nul
set "VERIFY_RESULT=%errorlevel%"

if "%VERIFY_RESULT%"=="0" exit /b 0

if "%VERIFY_RESULT%"=="2" (
	echo [%VERIFY_TAG%] Error: failed to compute %VERIFY_ALGORITHM% for %VERIFY_PATH%.
	exit /b 1
)

echo [%VERIFY_TAG%] Error: %VERIFY_LABEL% failed %VERIFY_ALGORITHM% verification.
exit /b 1

:usage
echo Usage: verify_hash.bat TAG PATH ALGORITHM EXPECTED_HASH LABEL
exit /b 1