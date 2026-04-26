@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\common.bat"
for %%I in ("%~dp0..\..\..\common\win") do set "COMMON_WIN_DIR=%%~fI"

call "%COMMON_WIN_DIR%\release_asset_digest.bat" --repo "%RELEASE_REPO%" %*
set "WRAPPER_EXIT=%errorlevel%"

popd >nul
exit /b %WRAPPER_EXIT%