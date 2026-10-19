@echo off
setlocal
chcp 65001 >nul
title BLUE Qwen3.8 Quality Reference - Remote

set "REPO_ROOT=%~dp0..\..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Release-BlueManagedRuntimeRemote.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo [ERROR] Managed BLUE runtime/tunnel could not be released safely. Quality Reference was not loaded.
    pause
    exit /b %RC%
)

call "%~dp0..\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat"
exit /b %ERRORLEVEL%
