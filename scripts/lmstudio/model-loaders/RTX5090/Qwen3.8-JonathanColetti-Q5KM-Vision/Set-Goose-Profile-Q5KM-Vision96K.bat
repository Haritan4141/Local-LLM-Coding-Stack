@echo off
setlocal
chcp 65001 >nul
title Set Goose Profile - Jonathan Q5_K_M Vision 96K

set "HELPER=%~dp0..\..\..\..\goose\Set-GooseProfile.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HELPER%" -Profile Q5KM-Vision96K
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo [ERROR] Goose profile selection failed with exit code %RC%.
  pause
  exit /b %RC%
)

timeout /t 2 /nobreak >nul
exit /b 0
