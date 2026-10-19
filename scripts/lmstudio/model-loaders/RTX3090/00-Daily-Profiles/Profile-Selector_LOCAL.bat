@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Daily Profiles - BLUE Local

echo =========================================
echo  Qwen3.8 Daily Profiles - BLUE Local
echo =========================================
echo.
echo  [1] Stable - Q5KM Vision 96K ^(Recommended^)
echo  [2] Turbo - Q5KM Vision 96K
echo  [3] Quick Response - Q5KM Vision 64K / Output 8K ^(Candidate^)
echo  [4] Quality Reference - Q6K Vision 64K
echo  [5] Release - unload model / stop managed runtime
echo  [6] Extended Context - IQ4XS Vision 256K ^(Candidate^)
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select profile: "

if "%PROFILE_CHOICE%"=="1" goto :stable
if "%PROFILE_CHOICE%"=="2" goto :turbo
if "%PROFILE_CHOICE%"=="3" goto :quick
if "%PROFILE_CHOICE%"=="4" goto :quality
if "%PROFILE_CHOICE%"=="5" goto :release
if "%PROFILE_CHOICE%"=="6" goto :extended
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:stable
call "%~dp01-Stable.bat"
exit /b %ERRORLEVEL%

:turbo
call "%~dp02-Turbo.bat"
exit /b %ERRORLEVEL%

:quick
call "%~dp0Quick-Response.bat"
exit /b %ERRORLEVEL%

:quality
call "%~dp03-Quality-Reference.bat"
exit /b %ERRORLEVEL%

:release
call "%~dp04-Release.bat"
exit /b %ERRORLEVEL%

:extended
call "%~dp0Extended-Context.bat"
exit /b %ERRORLEVEL%
