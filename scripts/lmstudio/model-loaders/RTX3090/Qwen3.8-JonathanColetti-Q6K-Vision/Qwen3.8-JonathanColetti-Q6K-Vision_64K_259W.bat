@echo off
chcp 65001 >nul
setlocal
title BLUE JonathanColetti Q6_K Vision - 64K - 259W Primary

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.ps1"
if errorlevel 1 (
    echo [ERROR] BLUE 259W Operational Default startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE JonathanColetti Q6_K Vision 64K / RTX3090 259W is ready.
pause
