@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 JonathanColetti Q5_K_M Vision - 96K Stable Recovery

set "REPO_ROOT=%~dp0..\..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Release-ManagedRuntime.ps1" -Profile RTX5090
if errorlevel 1 (
    echo [ERROR] Managed runtime could not be released safely. Stable was not loaded.
    pause
    exit /b %errorlevel%
)

call "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat"
exit /b %errorlevel%
