@echo off
setlocal
cd /d "%~dp0"
call env.bat
if not exist bin\payrollobol.exe (
  echo Build the project with build.bat first.
  exit /b 1
)
bin\payrollobol.exe
exit /b %errorlevel%