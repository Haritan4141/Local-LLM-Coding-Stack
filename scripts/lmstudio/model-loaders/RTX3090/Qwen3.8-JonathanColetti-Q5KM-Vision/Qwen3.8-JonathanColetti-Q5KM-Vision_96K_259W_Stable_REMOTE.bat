@echo off
setlocal
chcp 65001 >nul
title Restore BLUE JonathanColetti Q5_K_M Vision 96K Stable remotely

set "REPO_ROOT=%~dp0..\..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Release-BlueManagedRuntimeRemote.ps1"
if errorlevel 1 (
    echo [ERROR] Managed BLUE runtime/tunnel could not be released safely. Stable was not loaded.
    pause
    exit /b %errorlevel%
)

call "%~dp0Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.bat"
exit /b %errorlevel%
