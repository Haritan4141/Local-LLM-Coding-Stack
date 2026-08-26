@echo off
setlocal
chcp 65001 >nul
title Release BLUE Daily Profile remotely

for %%I in ("%~dp0..\..\..\..\..") do set "REPO_ROOT=%%~fI"
set "LOG_DIR=%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss-fff"') do set "STAMP=%%I"
set "LOG_FILE=%LOG_DIR%\blue-remote-release-%STAMP%.log"

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Release-BlueManagedRuntimeRemote.ps1" >"%LOG_FILE%" 2>&1
set "RC=%ERRORLEVEL%"
type "%LOG_FILE%"
echo [LOG] %LOG_FILE%
if not "%RC%"=="0" (
    echo [ERROR] Remote BLUE runtime release failed with exit code %RC%.
    pause
)
if "%RC%"=="0" echo [OK] BLUE model runtime released from MAIN.
exit /b %RC%
