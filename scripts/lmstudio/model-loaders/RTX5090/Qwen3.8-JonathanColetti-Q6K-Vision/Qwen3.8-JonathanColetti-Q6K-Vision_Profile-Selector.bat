@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Vision - RTX5090 Profiles

echo =========================================
echo  Qwen3.8 Vision - RTX5090 Profiles
echo =========================================
echo.
echo  [1] Safe
echo      MTP2 / Q8 / Proven Baseline
echo.
echo  [2] Balanced ^(Recommended^)
echo      MTP4 / Q8
echo.
echo  [3] Coding-Fast
echo      MTP4 / Q4
echo.
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select profile: "

if "%PROFILE_CHOICE%"=="1" goto :safe
if "%PROFILE_CHOICE%"=="2" goto :balanced
if "%PROFILE_CHOICE%"=="3" goto :coding_fast
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:safe
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat"
exit /b %ERRORLEVEL%

:balanced
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat"
exit /b %ERRORLEVEL%

:coding_fast
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat"
exit /b %ERRORLEVEL%
