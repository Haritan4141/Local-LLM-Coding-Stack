@echo off
setlocal
chcp 65001 >nul
title Start BLUE Q5_K_M Vision 96K Standalone Turbo remotely

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo [ERROR] BLUE Remote Standalone MTP3 Turbo startup failed with exit code %RC%.
    echo [INFO] Read the full diagnostic and MAIN LOG path above. This window stays open until a key is pressed.
    pause
    exit /b %RC%
)

echo [OK] BLUE Turbo endpoint is ready on MAIN at http://127.0.0.1:18081/v1.
pause
exit /b 0
