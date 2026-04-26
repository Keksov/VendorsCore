@echo off
setlocal EnableExtensions DisableDelayedExpansion

for %%I in ("%~dp0..\..\..\common\win") do set "COMMON_WIN_DIR=%%~fI"
call "%COMMON_WIN_DIR%\verify_hash.bat" %*
exit /b %errorlevel%