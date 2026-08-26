@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Daily Profiles - RTX5090

echo =========================================
echo  Qwen3.8 Daily Profiles - RTX5090
echo =========================================
echo.
echo  [1] Stable - Q5KM Vision 96K ^(Recommended^)
echo  [2] Turbo - Q5KM Vision 96K
echo  [3] Quality Reference - Q6K Vision 64K
echo  [4] Release - unload model / stop Turbo
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select profile: "

if "%PROFILE_CHOICE%"=="1" goto :stable
if "%PROFILE_CHOICE%"=="2" goto :turbo
if "%PROFILE_CHOICE%"=="3" goto :quality
if "%PROFILE_CHOICE%"=="4" goto :release
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:stable
call "%~dp01-Stable.bat"
exit /b %ERRORLEVEL%

:turbo
call "%~dp02-Turbo.bat"
exit /b %ERRORLEVEL%

:quality
call "%~dp03-Quality-Reference.bat"
exit /b %ERRORLEVEL%

:release
call "%~dp04-Release.bat"
exit /b %ERRORLEVEL%
