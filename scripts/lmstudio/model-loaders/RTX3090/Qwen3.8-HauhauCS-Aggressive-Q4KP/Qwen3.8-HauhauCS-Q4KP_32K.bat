@echo off
chcp 65001 >nul
setlocal
title Qwen3.8 HauhauCS Aggressive Q4_K_P - 32K

set "MANAGED_LOADER=C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk\Load-ManagedModel.mjs"
if not exist "%MANAGED_LOADER%" (
    echo [ERROR] Managed loader not found: %MANAGED_LOADER%
    exit /b 2
)

echo Unloading models on the RTX3090 LM Studio node...
lms unload --all
if errorlevel 1 exit /b %errorlevel%

echo Loading HauhauCS Aggressive Q4_K_P at 32768 context...
node "%MANAGED_LOADER%" --model-key "hauhaucs/qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp-gguf/qwen3.8-27b-uncensored-hauhaucs-aggressive-q4_k_p.gguf" --identifier "qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp" --context 32768 --mtp on
if errorlevel 1 (
    echo [ERROR] HauhauCS Aggressive Q4_K_P load failed.
    exit /b %errorlevel%
)

echo [OK] qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp / 32K / Q8_0 KV / MTP 2
pause
