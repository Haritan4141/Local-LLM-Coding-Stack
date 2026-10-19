@echo off
setlocal
chcp 65001 >nul
title MAIN RTX5090 IQ4XS Vision256K Candidate
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo [ERROR] MAIN IQ4XS256K startup failed with exit code %RC%.
pause
exit /b %RC%
