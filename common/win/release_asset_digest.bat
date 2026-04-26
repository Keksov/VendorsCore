@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "TARGET_REPO="
set "ASSET_NAME="
set "OUTPUT_PATH="
set "RELEASE_REF="
set "FORCE_REFRESH=0"
set "EXIT_CODE=1"

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--repo" (
    if "%~2"=="" goto :missing_value
    set "TARGET_REPO=%~2"
    shift
    shift
    goto :parse_args
)

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
if not defined TARGET_REPO if defined RELEASE_REPO set "TARGET_REPO=%RELEASE_REPO%"
if not defined TARGET_REPO (
    echo [release-asset-digest] Error: --repo is required.
    goto :usage
)

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

set "TEMP_OUTPUT=%OUTPUT_PATH%.download"
if exist "%TEMP_OUTPUT%" del /f /q "%TEMP_OUTPUT%" >nul 2>nul

"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $ownerRepo = $env:TARGET_REPO; $releaseRef = $env:RELEASE_REF; $assetName = $env:ASSET_NAME; $headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'KKMindWave-Win-Helpers'; 'X-GitHub-Api-Version' = '2026-03-10' }; $retryAttempts = 3; if ($env:HTTP_RETRY_ATTEMPTS -match '^[0-9]+$' -and [int]$env:HTTP_RETRY_ATTEMPTS -gt 0) { $retryAttempts = [int]$env:HTTP_RETRY_ATTEMPTS }; $retryDelaySeconds = 2; if ($env:HTTP_RETRY_DELAY_SECONDS -match '^[0-9]+$' -and [int]$env:HTTP_RETRY_DELAY_SECONDS -ge 0) { $retryDelaySeconds = [int]$env:HTTP_RETRY_DELAY_SECONDS }; function Invoke-ReleaseApiWithRetry { param([string]$Uri, [hashtable]$Headers, [int]$MaxAttempts, [int]$DelaySeconds); for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) { try { return Invoke-RestMethod -UseBasicParsing -Headers $Headers -Uri $Uri } catch { $statusCode = $null; if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) { $statusCode = [int]$_.Exception.Response.StatusCode }; if ($statusCode -eq 404 -or $attempt -ge $MaxAttempts) { throw }; [Console]::Error.WriteLine(('[get-release-asset-digest] Warning: metadata attempt {0}/{1} failed: {2}' -f $attempt, $MaxAttempts, $_.Exception.Message)); Start-Sleep -Seconds $DelaySeconds } } }; try { if ($releaseRef -ieq 'latest') { $releaseApiUrl = 'https://api.github.com/repos/' + $ownerRepo + '/releases/latest' } else { $releaseApiUrl = 'https://api.github.com/repos/' + $ownerRepo + '/releases/tags/' + [System.Uri]::EscapeDataString($releaseRef) }; $release = Invoke-ReleaseApiWithRetry -Uri $releaseApiUrl -Headers $headers -MaxAttempts $retryAttempts -DelaySeconds $retryDelaySeconds } catch { if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode -and [int]$_.Exception.Response.StatusCode -eq 404) { exit 5 }; exit 2 }; $assetMatches = @($release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1); if ($assetMatches.Count -eq 0) { exit 3 }; $digest = $assetMatches[0].digest; if ([string]::IsNullOrWhiteSpace($digest)) { exit 4 }; Write-Output $digest.Trim()" > "%TEMP_OUTPUT%" 2>nul
set "DIGEST_RESULT=%errorlevel%"

if "%DIGEST_RESULT%"=="0" goto :validate_output

if "%DIGEST_RESULT%"=="3" (
    set "EXIT_CODE=3"
    echo [release-asset-digest] Error: asset %ASSET_NAME% was not found in release ref %RELEASE_REF%.
    goto :fail
)

if "%DIGEST_RESULT%"=="4" (
    set "EXIT_CODE=4"
    echo [release-asset-digest] Error: release asset %ASSET_NAME% does not expose a digest in GitHub metadata.
    goto :fail
)

if "%DIGEST_RESULT%"=="5" (
    set "EXIT_CODE=5"
    echo [release-asset-digest] Error: release ref %RELEASE_REF% was not found. Ensure the release tag is published and accessible via the GitHub API.
    goto :fail
)

set "EXIT_CODE=%DIGEST_RESULT%"
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
echo Usage: release_asset_digest.bat --repo OWNER/REPO --asset NAME --out PATH [--latest ^| --tag TAG] [--force]
goto :fail

:fail
if exist "%TEMP_OUTPUT%" del /f /q "%TEMP_OUTPUT%" >nul 2>nul
exit /b %EXIT_CODE%

:success
exit /b 0