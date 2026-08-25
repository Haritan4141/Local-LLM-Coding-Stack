@echo off
setlocal
chcp 65001 >nul
call "%~dp0..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat"
exit /b %ERRORLEVEL%
