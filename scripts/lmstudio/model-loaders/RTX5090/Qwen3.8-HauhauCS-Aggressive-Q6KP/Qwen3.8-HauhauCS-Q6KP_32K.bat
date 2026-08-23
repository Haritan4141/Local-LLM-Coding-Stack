@echo off
chcp 65001 >nul
title Qwen3.8 HauhauCS Aggressive - 32K Light

echo ===================================================
echo Qwen3.8-27B HauhauCS Aggressive Q6_K_P - 32K Light
echo Context Length: 32768
echo Candidate API ID: qwen3.8-27b-hauhaucs-aggressive
echo ===================================================
echo.
echo Unloading currently loaded LM Studio models...
lms unload --all

echo.
echo Loading Candidate with embedded MTP...
lms load "hauhaucs/qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp-gguf/qwen3.8-27b-uncensored-hauhaucs-aggressive-q6_k_p.gguf" --context-length 32768 --gpu max --parallel 1 --speculative-draft-mtp --speculative-draft-max-tokens 2 --identifier "qwen3.8-27b-hauhaucs-aggressive" --yes

echo.
if errorlevel 1 (
    echo [ERROR] Candidate loading failed.
    echo Current files were not changed, but LM Studio may now have no loaded model.
) else (
    echo [OK] Candidate loaded successfully.
    echo Context Length: 32768
    echo API Model ID: qwen3.8-27b-hauhaucs-aggressive
    echo MTP: embedded / max draft tokens 2
)
echo.
pause
