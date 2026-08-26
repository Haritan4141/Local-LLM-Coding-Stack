@echo off
setlocal
chcp 65001 >nul
title Release BLUE Daily Profile

set "RELEASE_SCRIPT=C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Release-ManagedRuntime.ps1"
if not exist "%RELEASE_SCRIPT%" (
    echo [ERROR] BLUE managed release helper was not found: %RELEASE_SCRIPT%
    pause
    exit /b 3
)
set "LOG_DIR=%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss-fff"') do set "STAMP=%%I"
set "LOG_FILE=%LOG_DIR%\blue-local-release-%STAMP%.log"

powershell -NoProfile -ExecutionPolicy Bypass -File "%RELEASE_SCRIPT%" -Profile BLUE >"%LOG_FILE%" 2>&1
set "RC=%ERRORLEVEL%"
type "%LOG_FILE%"
echo [LOG] %LOG_FILE%
if not "%RC%"=="0" (
    echo [ERROR] BLUE runtime release failed with exit code %RC%.
    pause
)
if "%RC%"=="0" echo [OK] BLUE model runtime released.
exit /b %RC%
