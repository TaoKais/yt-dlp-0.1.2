@echo off
if "%~1"=="a" (
  >"%~6" echo simulated rar content
  exit /b 0
)
if "%~1"=="t" exit /b 0
exit /b 2
