@echo off
setlocal
chcp 65001 >nul
title RTX5090 Qwen3.8 Quality Reference

set "REPO_ROOT=%~dp0..\..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Stop-ManagedTurbo.ps1" -Profile RTX5090 -AllowNotRunning
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo [ERROR] Managed Turbo could not be stopped safely. Quality Reference was not loaded.
    pause
    exit /b %RC%
)

call "%~dp0..\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat"
exit /b %ERRORLEVEL%
