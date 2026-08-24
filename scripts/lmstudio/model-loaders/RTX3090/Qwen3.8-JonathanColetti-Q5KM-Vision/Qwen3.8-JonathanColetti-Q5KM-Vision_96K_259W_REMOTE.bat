@echo off
chcp 65001 >nul
setlocal
title Start BLUE JonathanColetti Q5_K_M Vision 96K Recommended remotely

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.ps1"
if errorlevel 1 (
    echo [ERROR] Remote BLUE Q5_K_M 96K startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE Q5_K_M Vision 96K endpoint is ready.
pause

