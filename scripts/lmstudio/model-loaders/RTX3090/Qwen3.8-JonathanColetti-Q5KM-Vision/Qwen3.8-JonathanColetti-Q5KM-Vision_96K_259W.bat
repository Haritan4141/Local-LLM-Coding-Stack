@echo off
chcp 65001 >nul
setlocal
title BLUE JonathanColetti Q5_K_M Vision - 96K - 259W Recommended

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.ps1"
if errorlevel 1 (
    echo [ERROR] BLUE Q5_K_M Vision 96K Recommended startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE JonathanColetti Q5_K_M Vision 96K Recommended is ready.
pause

