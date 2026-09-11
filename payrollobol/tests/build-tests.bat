@echo off
setlocal
cd /d "%~dp0.."
call env.bat
if not exist tests\.work mkdir tests\.work
where node >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Node 22.13+ is required for SQLite integration assertions.
    exit /b 1
)
set "FLAGS=-x -free -Wall -Wno-missing-newline -I copybooks"
cobc %FLAGS% -o tests\.work\test_calc.exe tests\test_calc.cob src\calc_engine.cob
if errorlevel 1 exit /b 1
cobc %FLAGS% -o tests\.work\verify_master.exe tests\verify_master.cob
if errorlevel 1 exit /b 1
cobc %FLAGS% -o tests\.work\test_db.exe tests\test_db.cob src\calc_engine.cob src\db_logger.cob %SQLITE_LIBS%
if errorlevel 1 exit /b 1
cobc %FLAGS% -o tests\.work\seed_data.exe src\seed_data.cob
if errorlevel 1 exit /b 1
cobc %FLAGS% -o tests\.work\payrollobol.exe src\main.cob src\calc_engine.cob src\db_logger.cob src\report_writer.cob %SQLITE_LIBS%
if errorlevel 1 exit /b 1
tests\.work\test_calc.exe
if errorlevel 1 exit /b 1
node --no-warnings tests\integration.mjs
if errorlevel 1 exit /b 1
exit /b 0
