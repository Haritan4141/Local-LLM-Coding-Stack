@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 JonathanColetti Q5_K_M Vision - 96K Standalone Turbo

set "REPO_ROOT=%~dp0..\..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Start-ManagedTurbo.ps1" -Profile RTX5090
if errorlevel 1 (
    echo [ERROR] RTX5090 Standalone MTP3 Turbo startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] RTX5090 Standalone MTP3 Turbo is ready at http://127.0.0.1:18080/v1.
pause
exit /b 0
