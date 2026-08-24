@echo off
chcp 65001 >nul
setlocal
title Start BLUE JonathanColetti Q6_K Vision 64K / 370W Performance remotely

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.ps1"
if errorlevel 1 (
    echo [ERROR] Remote BLUE 370W Performance startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE Vision 370W Performance endpoint is ready.
pause
