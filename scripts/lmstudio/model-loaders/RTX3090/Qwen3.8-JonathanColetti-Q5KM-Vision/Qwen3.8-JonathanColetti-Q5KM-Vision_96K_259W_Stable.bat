@echo off
setlocal
chcp 65001 >nul
title BLUE JonathanColetti Q5_K_M Vision - 96K Stable Recovery - 259W

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Stop-ManagedTurbo.ps1" -Profile BLUE -AllowNotRunning
if errorlevel 1 (
    echo [ERROR] Managed BLUE Turbo could not be stopped safely. Stable was not loaded.
    pause
    exit /b %errorlevel%
)

call "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat"
exit /b %errorlevel%
