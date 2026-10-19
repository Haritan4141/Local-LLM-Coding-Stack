@echo off
setlocal
chcp 65001 >nul
title BLUE IQ4XS Vision256K Remote Candidate
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-IQ4XS-Vision_256K_REMOTE.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo [ERROR] BLUE IQ4XS256K remote startup failed with exit code %RC%.
pause
exit /b %RC%
