@echo off
setlocal
cd /d "%~dp0"
call env.bat
if not exist bin\seed_data.exe (
  echo Build the project with build.bat first.
  exit /b 1
)
if not exist data\input mkdir data\input
if not exist data\output mkdir data\output
bin\seed_data.exe
exit /b %errorlevel%