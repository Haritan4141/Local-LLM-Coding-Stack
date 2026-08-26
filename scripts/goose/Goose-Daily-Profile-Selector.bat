@echo off
setlocal
chcp 65001 >nul
title Goose Daily Profiles - MAIN and BLUE

echo =========================================
echo  Goose Daily Profiles - MAIN and BLUE
echo =========================================
echo.
echo  MAIN RTX5090
echo.
echo  [1] Stable - Q5KM Vision 96K / Output 16K
echo  [2] Stable - Q5KM Vision 96K / Output 32K
echo  [3] Turbo  - Q5KM Vision 96K / Output 16K
echo  [4] Quality Reference - Q6K Vision 64K / Output 32K
echo.
echo  BLUE RTX3090+RTX3060
echo.
echo  [5] Stable - Q5KM Vision 96K / Output 16K
echo  [6] Stable - Q5KM Vision 96K / Output 32K
echo  [7] Turbo  - Q5KM Vision 96K / Output 16K
echo  [8] Quality Reference - Q6K Vision 64K / Output 32K
echo  [0] Cancel
echo.

set "PROFILE_CHOICE=%~1"
set "INTERACTIVE=0"
if not defined PROFILE_CHOICE (
  set "INTERACTIVE=1"
  set /p "PROFILE_CHOICE=Select Goose profile: "
)

if "%PROFILE_CHOICE%"=="1" set "PROFILE_NAME=MAIN-Stable16K"
if "%PROFILE_CHOICE%"=="2" set "PROFILE_NAME=MAIN-Stable32K"
if "%PROFILE_CHOICE%"=="3" set "PROFILE_NAME=MAIN-Turbo16K"
if "%PROFILE_CHOICE%"=="4" set "PROFILE_NAME=MAIN-Quality32K"
if "%PROFILE_CHOICE%"=="5" set "PROFILE_NAME=BLUE-Stable16K"
if "%PROFILE_CHOICE%"=="6" set "PROFILE_NAME=BLUE-Stable32K"
if "%PROFILE_CHOICE%"=="7" set "PROFILE_NAME=BLUE-Turbo16K"
if "%PROFILE_CHOICE%"=="8" set "PROFILE_NAME=BLUE-Quality32K"
if "%PROFILE_CHOICE%"=="0" exit /b 0

if not defined PROFILE_NAME (
  echo [ERROR] Invalid selection.
  if "%INTERACTIVE%"=="1" pause
  exit /b 2
)

echo.
echo [INFO] Goose Desktop must be completely closed before runtime/profile switching.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-GooseDailyProfile.ps1" -Profile "%PROFILE_NAME%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo [ERROR] Goose Daily Profile startup failed with exit code %RC%.
  if "%INTERACTIVE%"=="1" pause
  exit /b %RC%
)

echo [OK] Goose Daily Profile startup completed.
exit /b 0
