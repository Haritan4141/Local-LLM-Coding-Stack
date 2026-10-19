@echo off
setlocal
chcp 65001 >nul
title RTX5090 Qwen3.8 Quality Reference

set "REPO_ROOT=%~dp0..\..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Release-ManagedRuntime.ps1" -Profile RTX5090
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo [ERROR] Managed runtime could not be released safely. Quality Reference was not loaded.
    pause
    exit /b %RC%
)

call "%~dp0..\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat"
exit /b %ERRORLEVEL%
