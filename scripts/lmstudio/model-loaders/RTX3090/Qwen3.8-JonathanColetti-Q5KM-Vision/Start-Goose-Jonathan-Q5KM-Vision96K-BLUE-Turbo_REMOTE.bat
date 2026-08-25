@echo off
setlocal
chcp 65001 >nul
title Goose - BLUE Q5_K_M Vision 96K Standalone Turbo Remote

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Goose-Jonathan-Q5KM-Vision96K-BLUE-Turbo_REMOTE.ps1"
if errorlevel 1 (
    echo [ERROR] Goose BLUE Turbo startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
exit /b 0
