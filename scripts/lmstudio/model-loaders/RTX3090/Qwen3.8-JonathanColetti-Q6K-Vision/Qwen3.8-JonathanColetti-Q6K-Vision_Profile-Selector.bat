@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Vision - BLUE Profiles

echo =========================================
echo  Qwen3.8 Vision - BLUE Production Profiles
echo =========================================
echo.
echo  [1] Q5_K_M 96K Stable - Recommended
echo      MTP3 / Q8 / batch1024 / 259W
echo.
echo  [2] Q5_K_M 96K Standalone Turbo
echo      Official llama.cpp MTP3 / explicit selection only
echo.
echo  [3] Q6_K Balanced 64K ^(Quality/Performance Reference^)
echo      MTP3 / Q8 / batch1024 / 259W
echo.
echo  [4] Q6_K Safe 64K
echo      MTP2 / Q8 / batch512 / 259W
echo.
echo  [5] Q6_K Coding-Fast 64K
echo      MTP3 / Q4 / batch512 / 259W
echo.
echo  [6] Q6_K 370W Performance
echo      Existing verified override
echo.
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select profile: "

if "%PROFILE_CHOICE%"=="1" goto :q5_stable
if "%PROFILE_CHOICE%"=="2" goto :q5_turbo
if "%PROFILE_CHOICE%"=="3" goto :q6_balanced
if "%PROFILE_CHOICE%"=="4" goto :q6_safe
if "%PROFILE_CHOICE%"=="5" goto :q6_coding_fast
if "%PROFILE_CHOICE%"=="6" goto :q6_performance
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:q5_stable
call "%~dp0..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable.bat"
exit /b %ERRORLEVEL%

:q5_turbo
call "%~dp0..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat"
exit /b %ERRORLEVEL%

:q6_balanced
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat"
exit /b %ERRORLEVEL%

:q6_safe
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.bat"
exit /b %ERRORLEVEL%

:q6_coding_fast
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat"
exit /b %ERRORLEVEL%

:q6_performance
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat"
exit /b %ERRORLEVEL%
