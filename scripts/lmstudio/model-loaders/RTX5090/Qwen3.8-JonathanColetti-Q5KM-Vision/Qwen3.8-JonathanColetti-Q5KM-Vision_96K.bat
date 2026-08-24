@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 JonathanColetti Q5_K_M Vision - 96K

set "REPO_ROOT=%~dp0..\..\..\..\.."
pushd "%REPO_ROOT%" || goto :repo_error

lms unload --all
if errorlevel 1 goto :runtime_error

node ".\scripts\lmstudio\Load-ManagedModel.mjs" --model-key "qwen3.8-27b-uncensored-vision-q5km" --identifier "qwen3.8-27b-uncensored-vision-q5km" --context 98304 --mtp on --mtp-draft 3 --kv-k q8_0 --kv-v q8_0 --eval-batch 1024 --mmap on --keep-model-in-memory on
if errorlevel 1 goto :runtime_error

node ".\scripts\lmstudio\Test-ManagedModel.mjs" --identifier "qwen3.8-27b-uncensored-vision-q5km" --context 98304 --mtp on --mtp-draft 3 --kv-k q8_0 --kv-v q8_0 --eval-batch 1024 --mmap on --keep-model-in-memory on --vision-required on
if errorlevel 1 goto :runtime_error

popd
echo [OK] Jonathan Q5_K_M Vision 96K Recommended Production profile loaded.
pause
exit /b 0

:runtime_error
set "RC=%ERRORLEVEL%"
popd
echo [ERROR] LM Studio Vision Recommended Production load failed with exit code %RC%.
pause
exit /b %RC%

:repo_error
echo [ERROR] Repository root could not be resolved.
pause
exit /b 1
