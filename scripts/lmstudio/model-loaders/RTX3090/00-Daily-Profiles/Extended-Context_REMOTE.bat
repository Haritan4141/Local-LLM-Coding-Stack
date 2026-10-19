@echo off
setlocal
chcp 65001 >nul
call "%~dp0..\Qwen3.8-JonathanColetti-IQ4XS-Vision\Qwen3.8-JonathanColetti-IQ4XS-Vision_256K_REMOTE.bat"
exit /b %ERRORLEVEL%
