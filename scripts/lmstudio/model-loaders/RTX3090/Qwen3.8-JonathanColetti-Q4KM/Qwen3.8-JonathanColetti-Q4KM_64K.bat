@echo off
chcp 65001 >nul
setlocal
title Qwen3.8 JonathanColetti Q4_K_M - 64K

set "MANAGED_LOADER=C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk\Load-ManagedModel.mjs"
if not exist "%MANAGED_LOADER%" (
    echo [ERROR] Managed loader not found: %MANAGED_LOADER%
    exit /b 2
)

echo Unloading models on the RTX3090 LM Studio node...
lms unload --all
if errorlevel 1 exit /b %errorlevel%

echo Loading JonathanColetti Q4_K_M at 65536 context...
node "%MANAGED_LOADER%" --model-key "jonathancoletti/qwen3.8-27b-uncensored-gguf/qwen3.8-27b-uncensored-q4_k_m.gguf" --identifier "qwen3.8-27b-uncensored@q4_k_m" --context 65536 --mtp on
if errorlevel 1 (
    echo [ERROR] JonathanColetti Q4_K_M load failed.
    exit /b %errorlevel%
)

echo [OK] qwen3.8-27b-uncensored@q4_k_m / 64K / Q8_0 KV / MTP 2
pause
