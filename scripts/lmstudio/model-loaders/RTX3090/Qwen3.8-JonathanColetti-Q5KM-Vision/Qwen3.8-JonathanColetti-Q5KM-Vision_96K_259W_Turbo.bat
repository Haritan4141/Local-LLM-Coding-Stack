@echo off
setlocal
chcp 65001 >nul
title BLUE JonathanColetti Q5_K_M Vision - 96K Standalone Turbo - 259W

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.ps1"
if errorlevel 1 (
    echo [ERROR] BLUE Standalone MTP3 Turbo startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE Standalone MTP3 Turbo is ready at http://127.0.0.1:18080/v1.
pause
exit /b 0
