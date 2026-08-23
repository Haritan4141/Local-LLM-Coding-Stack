@echo off
chcp 65001 >nul
title Qwen3.8-27B LM Studio - 32K Light

echo ==========================================
echo Qwen3.8-27B Uncensored - 32K Light
echo Context Length: 32768
echo ==========================================
echo.
echo Unloading currently loaded LM Studio models...
lms unload --all

echo.
echo Loading qwen3.8-27b-uncensored...
lms load "qwen3.8-27b-uncensored" --context-length 32768 --gpu max --identifier "qwen3.8-27b-uncensored"

echo.
if errorlevel 1 (
    echo [ERROR] Model loading failed.
    echo Please check that LM Studio is running and the model is installed.
) else (
    echo [OK] Loaded successfully.
    echo Context Length: 32768
    echo API Model ID: qwen3.8-27b-uncensored
)
echo.
pause
