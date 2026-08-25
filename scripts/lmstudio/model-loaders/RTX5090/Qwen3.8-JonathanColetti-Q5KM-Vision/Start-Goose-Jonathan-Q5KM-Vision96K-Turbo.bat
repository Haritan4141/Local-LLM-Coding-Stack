@echo off
setlocal
chcp 65001 >nul
title Goose - RTX5090 Q5_K_M Vision 96K Standalone Turbo

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Goose-Jonathan-Q5KM-Vision96K-Turbo.ps1"
if errorlevel 1 (
    echo [ERROR] Goose RTX5090 Turbo startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
exit /b 0
