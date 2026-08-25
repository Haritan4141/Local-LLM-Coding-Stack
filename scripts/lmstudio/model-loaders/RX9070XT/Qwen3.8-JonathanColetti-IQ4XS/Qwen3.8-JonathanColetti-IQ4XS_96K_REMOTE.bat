@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Qwen3.8-JonathanColetti-IQ4XS_REMOTE.ps1" -Profile 96K
if errorlevel 1 (
  echo.
  echo [ERROR] RED Jonathan IQ4_XS 96K startup failed with exit code %ERRORLEVEL%.
  pause
  exit /b %ERRORLEVEL%
)
echo.
echo [OK] RED Jonathan IQ4_XS 96K is ready.
pause
