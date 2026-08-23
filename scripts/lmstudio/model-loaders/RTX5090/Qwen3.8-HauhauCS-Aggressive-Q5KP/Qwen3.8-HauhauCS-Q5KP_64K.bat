@echo off
chcp 65001 >nul
title Qwen3.8 HauhauCS Aggressive Q5_K_P - 64K VRChat

echo Unloading currently loaded LM Studio models...
lms unload --all

echo Loading Q5_K_P Candidate fallback at 65536 context...
lms load "hauhaucs/qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp-gguf/qwen3.8-27b-uncensored-hauhaucs-aggressive-q5_k_p.gguf" --context-length 65536 --gpu max --parallel 1 --speculative-draft-mtp --speculative-draft-max-tokens 2 --identifier "qwen3.8-27b-hauhaucs-aggressive-q5kp" --yes

if errorlevel 1 (
    echo [ERROR] Q5_K_P Candidate loading failed. Run the JonathanColetti loader to restore Current.
) else (
    echo [OK] Q5_K_P Candidate loaded: 64K / embedded MTP 2 / qwen3.8-27b-hauhaucs-aggressive-q5kp
)
pause
