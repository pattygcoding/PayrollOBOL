@echo off
setlocal
cd /d "%~dp0"
call env.bat
where cobc >nul 2>nul
if errorlevel 1 (
    echo [ERROR] GnuCOBOL 3.2+ x64 is required. See README.md.
    exit /b 1
)
if not exist bin mkdir bin
if not exist data\input mkdir data\input
if not exist data\output mkdir data\output
echo Compiling PayrollOBOL with SQLite integration...
cobc -x -free -Wall -Wno-missing-newline -I copybooks -o bin\payrollobol.exe src\main.cob src\calc_engine.cob src\db_logger.cob src\report_writer.cob %SQLITE_LIBS%
if errorlevel 1 exit /b 1
cobc -x -free -Wall -Wno-missing-newline -I copybooks -o bin\seed_data.exe src\seed_data.cob
if errorlevel 1 exit /b 1
call tests\build-tests.bat
if errorlevel 1 (
    echo [ERROR] Backend tests failed. Build is not validated.
    exit /b 1
)
echo [SUCCESS] Build and backend tests passed.
exit /b 0
