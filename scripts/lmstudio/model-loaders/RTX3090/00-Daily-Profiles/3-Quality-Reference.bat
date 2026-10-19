@echo off
setlocal
chcp 65001 >nul
title BLUE Qwen3.8 Quality Reference

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Release-ManagedRuntime.ps1" -Profile BLUE
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo [ERROR] Managed BLUE runtime could not be released safely. Quality Reference was not loaded.
    pause
    exit /b %RC%
)

call "%~dp0..\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat"
exit /b %ERRORLEVEL%
