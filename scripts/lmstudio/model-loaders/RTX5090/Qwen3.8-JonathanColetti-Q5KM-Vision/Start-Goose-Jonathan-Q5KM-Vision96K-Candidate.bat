@echo off
setlocal
chcp 65001 >nul
title Goose - Jonathan Q5_K_M Vision 96K Candidate

set "LAUNCHER=%~dp0Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo [ERROR] Goose Q5_K_M Vision Candidate startup failed with exit code %RC%.
  pause
)

exit /b %RC%
