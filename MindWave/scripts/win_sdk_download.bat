@echo off
setlocal EnableExtensions EnableDelayedExpansion

if not defined SDK_RELEASE_REPO set "SDK_RELEASE_REPO=Keksov/VendorsCore"
if not defined SDK_RELEASE_TAG set "SDK_RELEASE_TAG=fpc-bootstrap"
if not defined SDK_ZIP_NAME set "SDK_ZIP_NAME=Windows-Developer-Tools-3.2.zip"
if not defined NEUROSKY_SDK_URL set "NEUROSKY_SDK_URL=https://github.com/%SDK_RELEASE_REPO%/releases/download/%SDK_RELEASE_TAG%/%SDK_ZIP_NAME%"
if not defined NEUROSKY_STORE_URL set "NEUROSKY_STORE_URL=https://store.neurosky.com/collections/developer-tools-3"

pushd "%~dp0" >nul
if errorlevel 1 (
  echo [win_sdk_download] Error: failed to enter the script directory.
  exit /b 1
)

set "ROOT_DIR=.."
for %%I in ("..\..\common\win\release_asset_download.bat") do set "RELEASE_ASSET_DOWNLOAD=%%~fI"
for %%I in ("..\..\common\win\release_asset_digest.bat") do set "RELEASE_ASSET_DIGEST=%%~fI"
for %%I in ("..\..\common\win\verify_hash.bat") do set "VERIFY_HASH_HELPER=%%~fI"
set "DOWNLOAD_DIR=downloads"
set "UNZIP_SCRIPT=unzip.bat"
set "SDK_ZIP_PATH=%DOWNLOAD_DIR%\%SDK_ZIP_NAME%"
set "SDK_FALLBACK_DIGEST_PATH=%DOWNLOAD_DIR%\%SDK_ZIP_NAME%.digest"
set "SDK_RELEASE_DIGEST_PATH=%DOWNLOAD_DIR%\%SDK_ZIP_NAME%.release.digest"
set "SDK_SELECTED_DIGEST_PATH="
set "SDK_DIGEST_SOURCE="
set "SDK_MANUAL_FALLBACK=0"
set "TEMP_WORK_DIR=.tmp-neurosky-sdk-%RANDOM%%RANDOM%"
set "EXTRACT_DIR=%TEMP_WORK_DIR%\extract"
set "EXIT_CODE=0"
set "FAIL_MESSAGE="

if /I not "%OS%"=="Windows_NT" (
  echo [win_sdk_download] Error: unsupported operating system.
  exit /b 1
)

if not exist "%UNZIP_SCRIPT%" (
  set "FAIL_MESSAGE=Missing helper script: %UNZIP_SCRIPT%."
  goto :fail
)

if not exist "%RELEASE_ASSET_DOWNLOAD%" (
  set "FAIL_MESSAGE=Missing helper script: %RELEASE_ASSET_DOWNLOAD%."
  goto :fail
)

if not exist "%RELEASE_ASSET_DIGEST%" (
  set "FAIL_MESSAGE=Missing helper script: %RELEASE_ASSET_DIGEST%."
  goto :fail
)

if not exist "%VERIFY_HASH_HELPER%" (
  set "FAIL_MESSAGE=Missing helper script: %VERIFY_HASH_HELPER%."
  goto :fail
)

call :ensure_download_dir
if errorlevel 1 goto :fail

call :ensure_sdk_digest
if errorlevel 1 goto :fail

call :load_expected_digest "%SDK_SELECTED_DIGEST_PATH%"
if errorlevel 1 goto :fail

call :ensure_sdk_archive
if errorlevel 1 goto :fail

echo [win_sdk_download] Extracting %SDK_ZIP_NAME%...
call "%UNZIP_SCRIPT%" "%SDK_ZIP_PATH%" "%EXTRACT_DIR%"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to extract %SDK_ZIP_NAME%."
  goto :fail
)

call :find_artifact "%EXTRACT_DIR%" "thinkgear64.dll" THINKGEAR_SOURCE
if errorlevel 1 (
  set "FAIL_MESSAGE=Could not find thinkgear64.dll in the extracted SDK."
  goto :fail
)

call :find_artifact "%EXTRACT_DIR%" "AlgoSdkDll64.dll" ALGOSDK_SOURCE
if errorlevel 1 (
  set "FAIL_MESSAGE=Could not find AlgoSdkDll64.dll in the extracted SDK."
  goto :fail
)

call :find_artifact "%EXTRACT_DIR%" "EULA.pdf" EULA_SOURCE
if errorlevel 1 (
  set "FAIL_MESSAGE=Could not find EULA.pdf in the extracted SDK."
  goto :fail
)

call :copy_artifact "%THINKGEAR_SOURCE%" "%ROOT_DIR%\thinkgear64.dll"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to copy thinkgear64.dll into %ROOT_DIR%\."
  goto :fail
)

call :copy_artifact "%ALGOSDK_SOURCE%" "%ROOT_DIR%\AlgoSdkDll64.dll"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to copy AlgoSdkDll64.dll into %ROOT_DIR%\."
  goto :fail
)

call :copy_artifact "%EULA_SOURCE%" "%ROOT_DIR%\EULA.pdf"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to copy EULA.pdf into %ROOT_DIR%\."
  goto :fail
)

echo [win_sdk_download] Installed files:
echo [win_sdk_download]   ..\thinkgear64.dll
echo [win_sdk_download]   ..\AlgoSdkDll64.dll
echo [win_sdk_download]   ..\EULA.pdf
goto :cleanup

:fail
set "EXIT_CODE=1"
if not defined FAIL_MESSAGE set "FAIL_MESSAGE=Setup failed."
echo [win_sdk_download] Error: %FAIL_MESSAGE%

:cleanup
if exist "%TEMP_WORK_DIR%" rd /s /q "%TEMP_WORK_DIR%" >nul 2>nul
popd >nul
exit /b %EXIT_CODE%

:ensure_sdk_digest
set "SDK_SELECTED_DIGEST_PATH="
set "SDK_DIGEST_SOURCE="
set "SDK_MANUAL_FALLBACK=0"

if exist "%SDK_RELEASE_DIGEST_PATH%" del /f /q "%SDK_RELEASE_DIGEST_PATH%" >nul 2>nul

call "%RELEASE_ASSET_DIGEST%" --repo "%SDK_RELEASE_REPO%" --asset "%SDK_ZIP_NAME%" --out "%SDK_RELEASE_DIGEST_PATH%" --tag "%SDK_RELEASE_TAG%" --force
set "DIGEST_LOOKUP_RESULT=%errorlevel%"

if "%DIGEST_LOOKUP_RESULT%"=="0" (
  set "SDK_SELECTED_DIGEST_PATH=%SDK_RELEASE_DIGEST_PATH%"
  set "SDK_DIGEST_SOURCE=GitHub release metadata"
  exit /b 0
)

if "%DIGEST_LOOKUP_RESULT%"=="3" goto :use_committed_fallback_digest
if "%DIGEST_LOOKUP_RESULT%"=="5" goto :use_committed_fallback_digest

if "%DIGEST_LOOKUP_RESULT%"=="4" (
  set "FAIL_MESSAGE=GitHub release asset %SDK_ZIP_NAME% does not expose digest metadata. The committed fallback digest is reserved for missing release assets only."
  exit /b 1
)

if "%DIGEST_LOOKUP_RESULT%"=="2" (
  set "FAIL_MESSAGE=Failed to query GitHub release metadata for %SDK_ZIP_NAME%. The committed fallback digest is reserved for missing release assets only."
  exit /b 1
)

set "FAIL_MESSAGE=GitHub digest lookup failed for %SDK_ZIP_NAME% with exit code %DIGEST_LOOKUP_RESULT%."
exit /b 1

:use_committed_fallback_digest
if not exist "%SDK_FALLBACK_DIGEST_PATH%" (
  set "FAIL_MESSAGE=GitHub release asset %SDK_ZIP_NAME% was not found, and the committed fallback digest is missing: %SDK_FALLBACK_DIGEST_PATH%"
  exit /b 1
)

set "SDK_SELECTED_DIGEST_PATH=%SDK_FALLBACK_DIGEST_PATH%"
set "SDK_DIGEST_SOURCE=committed fallback digest"
set "SDK_MANUAL_FALLBACK=1"
echo [win_sdk_download] GitHub release asset %SDK_ZIP_NAME% was not found. Using the committed fallback digest: %SDK_FALLBACK_DIGEST_PATH%

exit /b 0

:load_expected_digest
set "SDK_DIGEST="
set "SDK_DIGEST_ALGORITHM="
set "SDK_DIGEST_HASH="

if not exist "%~1" (
  set "FAIL_MESSAGE=Digest file was not found: %~1"
  exit /b 1
)

set /p SDK_DIGEST=<"%~1"
if not defined SDK_DIGEST (
  set "FAIL_MESSAGE=Digest file is empty: %~1"
  exit /b 1
)

for /f "tokens=1,* delims=:" %%A in ("%SDK_DIGEST%") do (
  set "SDK_DIGEST_ALGORITHM=%%A"
  set "SDK_DIGEST_HASH=%%B"
)

if not defined SDK_DIGEST_ALGORITHM (
  set "FAIL_MESSAGE=Digest is missing an algorithm: %SDK_DIGEST%"
  exit /b 1
)

if not defined SDK_DIGEST_HASH (
  set "FAIL_MESSAGE=Digest is missing a hash value: %SDK_DIGEST%"
  exit /b 1
)

exit /b 0

:ensure_download_dir
if exist "%DOWNLOAD_DIR%" exit /b 0

mkdir "%DOWNLOAD_DIR%"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to create download directory: %DOWNLOAD_DIR%."
  exit /b 1
)

exit /b 0

:ensure_sdk_archive
if "%SDK_MANUAL_FALLBACK%"=="1" (
  if not exist "%SDK_ZIP_PATH%" (
    set "FAIL_MESSAGE=GitHub release asset %SDK_ZIP_NAME% was not found. Manually obtain the unopened ZIP from %NEUROSKY_STORE_URL%, place it at %SDK_ZIP_PATH%, and rerun this script."
    exit /b 1
  )

  call "%VERIFY_HASH_HELPER%" "win_sdk_download" "%SDK_ZIP_PATH%" "%SDK_DIGEST_ALGORITHM%" "%SDK_DIGEST_HASH%" "%SDK_ZIP_NAME%"
  if errorlevel 1 (
    set "FAIL_MESSAGE=The manually staged archive failed %SDK_DIGEST_ALGORITHM% verification: %SDK_ZIP_PATH%. Obtain a fresh ZIP from %NEUROSKY_STORE_URL% and keep it unopened."
    exit /b 1
  )

  echo [win_sdk_download] Using manually staged archive: %SDK_ZIP_PATH%
  exit /b 0
)

if exist "%SDK_ZIP_PATH%" (
  call "%VERIFY_HASH_HELPER%" "win_sdk_download" "%SDK_ZIP_PATH%" "%SDK_DIGEST_ALGORITHM%" "%SDK_DIGEST_HASH%" "%SDK_ZIP_NAME%"
  if not errorlevel 1 (
    echo [win_sdk_download] Using cached archive: %SDK_ZIP_PATH%
    exit /b 0
  )

  echo [win_sdk_download] Cached archive failed %SDK_DIGEST_ALGORITHM% verification. Re-downloading...
  del /f /q "%SDK_ZIP_PATH%" >nul 2>nul
)

call "%RELEASE_ASSET_DOWNLOAD%" --repo "%SDK_RELEASE_REPO%" --asset "%SDK_ZIP_NAME%" --out "%SDK_ZIP_PATH%" --tag "%SDK_RELEASE_TAG%"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to download %SDK_ZIP_NAME% from %NEUROSKY_SDK_URL%."
  exit /b 1
)

call "%VERIFY_HASH_HELPER%" "win_sdk_download" "%SDK_ZIP_PATH%" "%SDK_DIGEST_ALGORITHM%" "%SDK_DIGEST_HASH%" "%SDK_ZIP_NAME%"
if errorlevel 1 (
  del /f /q "%SDK_ZIP_PATH%" >nul 2>nul
  set "FAIL_MESSAGE=Downloaded archive failed %SDK_DIGEST_ALGORITHM% verification."
  exit /b 1
)

exit /b 0

:find_artifact
set "%~3="
for /f "delims=" %%I in ('where /r "%~1" "%~2" 2^>nul') do if not defined %~3 set "%~3=%%~fI"
if not defined %~3 exit /b 1
exit /b 0

:copy_artifact
copy /y "%~1" "%~2" >nul
if errorlevel 1 exit /b 1
exit /b 0
