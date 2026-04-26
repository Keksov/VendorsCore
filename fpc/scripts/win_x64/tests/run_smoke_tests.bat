@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "RUNNER_EXIT=1"
pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

call ".\run_all_tests.bat" --smoke %*
set "RUNNER_EXIT=%errorlevel%"

popd >nul
exit /b %RUNNER_EXIT%