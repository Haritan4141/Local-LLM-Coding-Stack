@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Vision - RTX5090 Profiles

echo =========================================
echo  Qwen3.8 Vision - RTX5090 Profiles
echo =========================================
echo.
echo  [1] Q5_K_M Vision 96K - Recommended
echo      MTP3 / Q8 / batch1024
echo.
echo  [2] Q6_K Vision 64K - Balanced
echo      Quality/Performance Reference / MTP4 / Q8
echo.
echo  [3] Q6_K Vision 64K - Safe
echo      Permanent known-good fallback / MTP2 / Q8
echo.
echo  [4] Q6_K Vision 64K - Coding-Fast
echo      Explicit selection only / MTP4 / Q4
echo.
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select profile: "

if "%PROFILE_CHOICE%"=="1" goto :recommended
if "%PROFILE_CHOICE%"=="2" goto :balanced
if "%PROFILE_CHOICE%"=="3" goto :safe
if "%PROFILE_CHOICE%"=="4" goto :coding_fast
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:recommended
call "%~dp0..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat"
exit /b %ERRORLEVEL%

:balanced
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat"
exit /b %ERRORLEVEL%

:safe
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat"
exit /b %ERRORLEVEL%

:coding_fast
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat"
exit /b %ERRORLEVEL%
