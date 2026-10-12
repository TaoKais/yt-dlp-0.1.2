@echo off
if "%~1"=="a" (
  if not "%~5"=="-t" exit /b 2
  for %%F in ("%~8\*.txt") do type "%%~fF" >"%~7"
  exit /b 0
)
rem A separate test process would prompt for the password again.
if "%~1"=="t" exit /b 3
exit /b 2
