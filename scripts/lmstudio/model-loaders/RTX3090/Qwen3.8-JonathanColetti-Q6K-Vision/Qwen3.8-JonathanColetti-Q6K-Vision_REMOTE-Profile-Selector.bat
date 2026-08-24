@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 Vision - BLUE Remote Profiles

echo =========================================
echo  Qwen3.8 Vision - BLUE Remote Profiles
echo =========================================
echo.
echo  [1] Safe
echo      MTP2 / Q8 / batch512 / 259W
echo.
echo  [2] Balanced ^(Recommended^)
echo      MTP3 / Q8 / batch1024 / 259W
echo.
echo  [3] Coding-Fast
echo      MTP3 / Q4 / batch512 / 259W
echo.
echo  [4] 370W Performance
echo      Existing verified override
echo.
echo  [0] Cancel
echo.
set "PROFILE_CHOICE=%~1"
if not defined PROFILE_CHOICE set /p "PROFILE_CHOICE=Select remote profile: "

if "%PROFILE_CHOICE%"=="1" goto :safe
if "%PROFILE_CHOICE%"=="2" goto :balanced
if "%PROFILE_CHOICE%"=="3" goto :coding_fast
if "%PROFILE_CHOICE%"=="4" goto :performance
if "%PROFILE_CHOICE%"=="0" exit /b 0

echo [ERROR] Invalid selection.
exit /b 2

:safe
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W_REMOTE.bat"
exit /b %ERRORLEVEL%

:balanced
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat"
exit /b %ERRORLEVEL%

:coding_fast
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.bat"
exit /b %ERRORLEVEL%

:performance
call "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.bat"
exit /b %ERRORLEVEL%
