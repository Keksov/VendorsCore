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

"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $literalPath = $env:VERIFY_PATH; $algorithm = ($env:VERIFY_ALGORITHM).ToUpperInvariant(); $expectedHash = $env:VERIFY_EXPECTED; try { switch ($algorithm) { 'SHA1' { $hasher = [System.Security.Cryptography.SHA1]::Create() } 'SHA256' { $hasher = [System.Security.Cryptography.SHA256]::Create() } default { exit 2 } }; try { $stream = [System.IO.File]::Open($literalPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read); try { $hashBytes = $hasher.ComputeHash($stream) } finally { $stream.Dispose() } } finally { $hasher.Dispose() }; $actualHash = -join ($hashBytes | ForEach-Object { $_.ToString('X2') }) } catch { exit 2 }; if ($actualHash -ieq $expectedHash) { exit 0 }; exit 1" >nul 2>nul
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