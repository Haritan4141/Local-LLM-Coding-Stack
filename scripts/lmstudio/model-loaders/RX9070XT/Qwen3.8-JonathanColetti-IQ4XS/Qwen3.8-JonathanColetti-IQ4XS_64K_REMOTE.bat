@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-IQ4XS_REMOTE.ps1" -Profile 64K
if errorlevel 1 (
  echo.
  echo [ERROR] RED Jonathan IQ4_XS 64K startup failed with exit code %ERRORLEVEL%.
  pause
  exit /b %ERRORLEVEL%
)
echo.
echo [OK] RED Jonathan IQ4_XS 64K is ready.
pause
