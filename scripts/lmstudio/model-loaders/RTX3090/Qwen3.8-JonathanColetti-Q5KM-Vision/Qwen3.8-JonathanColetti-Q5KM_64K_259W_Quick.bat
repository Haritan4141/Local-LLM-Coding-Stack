@echo off
setlocal
chcp 65001 >nul
title BLUE JonathanColetti Q5_K_M Vision - 64K Quick Response Candidate - 259W

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-Q5KM_64K_259W_Quick.ps1"
if errorlevel 1 (
    echo [ERROR] BLUE Quick Response startup failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo [OK] BLUE Quick Response Candidate is ready at http://127.0.0.1:18080/v1.
pause
exit /b 0
