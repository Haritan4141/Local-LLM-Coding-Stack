@echo off
setlocal
echo RED RX 9070 XT / Jonathan IQ4_XS
echo.
echo   [1] 96K Recommended Candidate
echo   [2] 64K Lower-memory fallback
echo   [0] Cancel
echo.
choice /c 120 /n /m "Select profile: "
if errorlevel 3 goto :cancel
if errorlevel 2 goto :load64
if errorlevel 1 goto :load96

:load96
call "%~dp0Qwen3.8-JonathanColetti-IQ4XS_96K_REMOTE.bat"
exit /b %ERRORLEVEL%

:load64
call "%~dp0Qwen3.8-JonathanColetti-IQ4XS_64K_REMOTE.bat"
exit /b %ERRORLEVEL%

:cancel
exit /b 0
