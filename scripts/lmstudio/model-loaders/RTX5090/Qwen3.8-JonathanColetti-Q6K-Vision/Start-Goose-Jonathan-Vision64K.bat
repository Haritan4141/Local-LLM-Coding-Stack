@echo off
setlocal
chcp 65001 >nul
title Goose - Jonathan Q6_K Vision 64K

set "LAUNCHER=%~dp0Start-Goose-Jonathan-Vision64K.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo [ERROR] Goose Vision startup failed with exit code %RC%.
  pause
)

exit /b %RC%
