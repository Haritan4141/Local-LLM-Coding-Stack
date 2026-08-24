@echo off
chcp 65001 >nul
setlocal
title BLUE JonathanColetti Q6_K Vision - 64K - 370W Performance

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.ps1"
if errorlevel 1 (
    echo [ERROR] BLUE 370W Performance startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE JonathanColetti Q6_K Vision 64K / RTX3090 370W Performance is ready.
pause
