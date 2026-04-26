@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "MODE=full"
set "STOP_ON_FAILURE=1"
set "TOTAL=0"
set "FAILED=0"
set "RUNNER_EXIT=1"

pushd "%~dp0" >nul
if errorlevel 1 exit /b 1

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--smoke" (
    set "MODE=smoke"
    shift
    goto :parse_args
)

if /I "%~1"=="--continue-on-failure" (
    set "STOP_ON_FAILURE=0"
    shift
    goto :parse_args
)

echo [runner] Error: unknown argument %~1
echo Usage: run_all_tests.bat [--smoke] [--continue-on-failure]
goto :end

:args_done
echo [runner] Mode: %MODE%

if /I "%MODE%"=="smoke" goto :run_smoke

call :run_scenario release_setup_latest ".\test_release_setup_latest.bat"
if errorlevel 1 goto :summary
call :run_scenario clean_build_after_clone ".\test_clean_build_after_clone.bat"
if errorlevel 1 goto :summary
call :run_scenario rebuild_with_local_artifacts ".\test_rebuild_with_local_artifacts.bat"
if errorlevel 1 goto :summary
call :run_scenario source_pack_fallback_no_7zip ".\test_source_pack_fallback_no_7zip.bat"
if errorlevel 1 goto :summary
call :run_scenario missing_artifacts ".\test_missing_artifacts.bat"
goto :summary

:run_smoke
call :run_scenario source_pack_fallback_no_7zip ".\test_source_pack_fallback_no_7zip.bat"
if errorlevel 1 goto :summary
call :run_scenario missing_artifacts_offline ".\test_missing_artifacts.bat" --offline-only

:summary
echo.
echo [runner] Summary:
for /L %%I in (1,1,%TOTAL%) do call echo [runner]   %%SCENARIO_RESULT_%%I%%

if "%FAILED%"=="0" (
    echo [runner] All scenarios passed.
    set "RUNNER_EXIT=0"
    goto :end
)

echo [runner] Failed scenarios: %FAILED%
set "RUNNER_EXIT=1"
goto :end

:run_scenario
set /a TOTAL+=1
set "SCENARIO_NAME=%~1"
set "SCENARIO_SCRIPT=%~2"

echo.
echo [runner] Running %SCENARIO_NAME%...
call "%SCENARIO_SCRIPT%" %3 %4 %5 %6 %7 %8 %9
set "SCENARIO_EXIT=%errorlevel%"

if "%SCENARIO_EXIT%"=="0" (
    set "SCENARIO_RESULT_%TOTAL%=PASS %SCENARIO_NAME%"
    exit /b 0
)

set /a FAILED+=1
set "SCENARIO_RESULT_%TOTAL%=FAIL %SCENARIO_NAME%"
if "%STOP_ON_FAILURE%"=="1" exit /b 1
exit /b 0

:end
popd >nul
exit /b %RUNNER_EXIT%