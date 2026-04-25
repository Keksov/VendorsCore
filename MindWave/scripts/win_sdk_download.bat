@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "NEUROSKY_SDK_URL=https://neurosky.fetchapp.com/files/bc5006e1"
set "SDK_ZIP_NAME=Windows-Developer-Tools-3.2.zip"

pushd "%~dp0" >nul
if errorlevel 1 (
  echo [win_sdk_download] Error: failed to enter the script directory.
  exit /b 1
)

set "ROOT_DIR=.."
set "DOWNLOAD_DIR=downloads"
set "KNOWN_SIZE_FILE=known_file_sizes.txt"
set "UNZIP_SCRIPT=unzip.bat"
set "SDK_ZIP_PATH=%DOWNLOAD_DIR%\%SDK_ZIP_NAME%"
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

if not exist "%KNOWN_SIZE_FILE%" (
  set "FAIL_MESSAGE=Missing known size file: %KNOWN_SIZE_FILE%."
  goto :fail
)

call :load_expected_zip_size
if errorlevel 1 goto :fail

call :ensure_download_dir
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

:load_expected_zip_size
set "EXPECTED_ZIP_SIZE="
for /f "usebackq tokens=* delims=" %%I in ("%KNOWN_SIZE_FILE%") do (
  set "FILE_LINE=%%I"
  if defined FILE_LINE if not "!FILE_LINE:~0,1!"=="#" if not defined EXPECTED_ZIP_SIZE set "EXPECTED_ZIP_SIZE=!FILE_LINE!"
)

if not defined EXPECTED_ZIP_SIZE (
  set "FAIL_MESSAGE=Could not read an expected zip size from %KNOWN_SIZE_FILE%."
  exit /b 1
)

echo(!EXPECTED_ZIP_SIZE!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
  set "FAIL_MESSAGE=Expected zip size must be numeric: !EXPECTED_ZIP_SIZE!"
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
if exist "%SDK_ZIP_PATH%" (
  call :verify_zip_size "%SDK_ZIP_PATH%"
  if not errorlevel 1 (
    echo [win_sdk_download] Using cached archive: %SDK_ZIP_PATH%
    exit /b 0
  )

  echo [win_sdk_download] Cached archive failed size verification. Re-downloading...
  del /f /q "%SDK_ZIP_PATH%" >nul 2>nul
)

echo [win_sdk_download] Downloading %SDK_ZIP_NAME%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Invoke-WebRequest -Uri $env:NEUROSKY_SDK_URL -OutFile $env:SDK_ZIP_PATH"
if errorlevel 1 (
  set "FAIL_MESSAGE=Failed to download %SDK_ZIP_NAME% from %NEUROSKY_SDK_URL%."
  exit /b 1
)

call :verify_zip_size "%SDK_ZIP_PATH%"
if errorlevel 1 (
  del /f /q "%SDK_ZIP_PATH%" >nul 2>nul
  set "FAIL_MESSAGE=Downloaded archive did not match expected size !EXPECTED_ZIP_SIZE! bytes."
  exit /b 1
)

exit /b 0

:verify_zip_size
if not exist "%~1" exit /b 1

for %%I in ("%~1") do set "ACTUAL_ZIP_SIZE=%%~zI"
if "!ACTUAL_ZIP_SIZE!"=="!EXPECTED_ZIP_SIZE!" exit /b 0
exit /b 1

:find_artifact
set "%~3="
for /f "delims=" %%I in ('where /r "%~1" "%~2" 2^>nul') do if not defined %~3 set "%~3=%%~fI"
if not defined %~3 exit /b 1
exit /b 0

:copy_artifact
copy /y "%~1" "%~2" >nul
if errorlevel 1 exit /b 1
exit /b 0
