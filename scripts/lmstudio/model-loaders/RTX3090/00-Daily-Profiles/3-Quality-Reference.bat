@echo off
setlocal
chcp 65001 >nul
title BLUE Qwen3.8 Quality Reference

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Stop-ManagedTurbo.ps1" -Profile BLUE -AllowNotRunning
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo [ERROR] Managed BLUE Turbo could not be stopped safely. Quality Reference was not loaded.
    pause
    exit /b %RC%
)

call "%~dp0..\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat"
exit /b %ERRORLEVEL%
