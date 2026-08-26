@echo off
setlocal
chcp 65001 >nul
title Release RTX5090 Daily Profile

for %%I in ("%~dp0..\..\..\..\..") do set "REPO_ROOT=%%~fI"
set "LOG_DIR=%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss-fff"') do set "STAMP=%%I"
set "LOG_FILE=%LOG_DIR%\rtx5090-release-%STAMP%.log"

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\standalone-turbo\Release-ManagedRuntime.ps1" -Profile RTX5090 >"%LOG_FILE%" 2>&1
set "RC=%ERRORLEVEL%"
type "%LOG_FILE%"
echo [LOG] %LOG_FILE%
if not "%RC%"=="0" (
    echo [ERROR] RTX5090 runtime release failed with exit code %RC%.
    pause
)
if "%RC%"=="0" echo [OK] RTX5090 model runtime released.
exit /b %RC%
