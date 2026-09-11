@echo off
if not defined MINGW_HOME set "MINGW_HOME=C:\mingw64"
if exist "%~dp0.tools\mingw64\bin\cobc.exe" (
    set "PATH=%~dp0.tools\mingw64\bin;%MINGW_HOME%\bin;%PATH%"
    set "COB_CONFIG_DIR=%~dp0.tools\mingw64\share\gnucobol\config"
    set "COB_COPY_DIR=%~dp0.tools\mingw64\share\gnucobol\copy"
    set "COB_CFLAGS=-I "%~dp0.tools\mingw64\include" -std=gnu11"
    set "COB_LIBS=-L "%~dp0.tools\mingw64\lib" -lcob"
) else (
    set "COB_CFLAGS=%COB_CFLAGS% -std=gnu11"
)
if not defined SQLITE_LIBS (
    if exist "%MINGW_HOME%\lib\libsqlite3.dll.a" (
        set "SQLITE_LIBS=-L "%MINGW_HOME%\lib" -lsqlite3"
    ) else if exist "%MINGW_HOME%\bin\libsqlite3-0.dll" (
        set "SQLITE_LIBS=-L "%MINGW_HOME%\bin" -l:libsqlite3-0.dll"
    ) else (
        set "SQLITE_LIBS=-lsqlite3"
    )
)
exit /b 0
