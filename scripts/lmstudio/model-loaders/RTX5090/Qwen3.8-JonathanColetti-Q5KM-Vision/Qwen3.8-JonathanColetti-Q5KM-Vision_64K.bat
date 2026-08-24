@echo off
setlocal
chcp 65001 >nul
title Qwen3.8 JonathanColetti Q5_K_M Vision - 64K

set "REPO_ROOT=%~dp0..\..\..\..\.."
pushd "%REPO_ROOT%" || goto :repo_error

lms unload --all
if errorlevel 1 goto :runtime_error

node ".\scripts\lmstudio\Load-ManagedModel.mjs" --model-key "qwen3.8-27b-uncensored-vision-q5km" --identifier "qwen3.8-27b-uncensored-vision-q5km" --context 65536 --mtp off
if errorlevel 1 goto :runtime_error

popd
echo [OK] Jonathan Q5_K_M Vision Candidate loaded at 64K.
pause
exit /b 0

:runtime_error
set "RC=%ERRORLEVEL%"
popd
echo [ERROR] LM Studio Vision Candidate load failed with exit code %RC%.
pause
exit /b %RC%

:repo_error
echo [ERROR] Repository root could not be resolved.
pause
exit /b 1
