@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 JonathanColetti Q6_K Vision - 64K Coding-Fast

set "REPO_ROOT=%~dp0..\..\..\..\.."
pushd "%REPO_ROOT%" || goto :repo_error

lms unload --all
if errorlevel 1 goto :runtime_error

node ".\scripts\lmstudio\Load-ManagedModel.mjs" --model-key "qwen3.8-27b-uncensored-vision-q6k" --identifier "qwen3.8-27b-uncensored-vision" --context 65536 --mtp on --mtp-draft 4 --kv-k q4_0 --kv-v q4_0 --eval-batch 2048 --mmap on --keep-model-in-memory on --strict-vram-cap off
if errorlevel 1 goto :runtime_error

node ".\scripts\lmstudio\Test-ManagedModel.mjs" --identifier "qwen3.8-27b-uncensored-vision" --context 65536 --mtp on --mtp-draft 4 --kv-k q4_0 --kv-v q4_0 --eval-batch 2048 --mmap on --keep-model-in-memory on --strict-vram-cap off --vision-required on
if errorlevel 1 goto :runtime_error

popd
echo [OK] Jonathan Q6_K Vision 64K Coding-Fast loaded: MTP4 / Q4 / batch2048.
pause
exit /b 0

:runtime_error
set "RC=%ERRORLEVEL%"
popd
echo [ERROR] LM Studio Coding-Fast load failed with exit code %RC%.
pause
exit /b %RC%

:repo_error
echo [ERROR] Repository root could not be resolved.
pause
exit /b 1
