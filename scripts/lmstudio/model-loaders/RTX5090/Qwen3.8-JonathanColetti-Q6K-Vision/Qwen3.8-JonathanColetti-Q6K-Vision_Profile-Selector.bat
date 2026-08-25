@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Vision - RTX5090 Profiles

echo =========================================
echo  Qwen3.8 Vision - RTX5090 Profiles
echo =========================================
echo.
echo  [1] Q5_K_M Vision 96K Stable - Recommended
echo      MTP3 / Q8 / batch1024
echo.
echo  [2] Q5_K_M Vision 96K Standalone Turbo
echo      Official llama.cpp MTP3 / explicit selection only
echo.
echo  [3] Q6_K Vision 64K - Balanced
echo      Quality/Performance Reference / MTP4 / Q8
echo.
echo  [4] Q6_K Vision 64K - Safe
echo      Permanent known-good fallback / MTP2 / Q8
echo.
echo  [5] Q6_K Vision 64K - Coding-Fast
echo      Explicit selection only / MTP4 / Q4
echo.
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select profile: "

if "%PROFILE_CHOICE%"=="1" goto :stable
if "%PROFILE_CHOICE%"=="2" goto :turbo
if "%PROFILE_CHOICE%"=="3" goto :balanced
if "%PROFILE_CHOICE%"=="4" goto :safe
if "%PROFILE_CHOICE%"=="5" goto :coding_fast
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:stable
call "%~dp0..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat"
exit /b %ERRORLEVEL%

:turbo
call "%~dp0..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat"
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
