@echo off
chcp 65001 >nul
setlocal
title Start BLUE JonathanColetti Q6_K Vision 64K / 259W Balanced remotely

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.ps1"
if errorlevel 1 (
    echo [ERROR] Remote BLUE 259W Balanced startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE Vision 259W Balanced endpoint is ready.
pause
