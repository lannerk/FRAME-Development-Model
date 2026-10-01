@echo off
rem Thin wrapper: all logic lives in the .sh of the same name next to this file.
rem This file only finds the Git Bash that ships with Git for Windows and runs that .sh.
rem The same file serves clear-to-delete / clear-build / clear-dist: it picks the .sh by its own name.
rem
rem KEEP THIS FILE PURE ASCII. cmd reads a batch file line by line by byte offset; with multi-byte
rem UTF-8 text in the file (and chcp 65001), the offsets drift and fragments of lines get executed
rem as commands ("'...' is not recognized as an internal or external command"). Measured 2026-10-01.
setlocal
chcp 65001 >nul
cd /d "%~dp0"
set "ARG=%~1"
if /i "%ARG%"=="/y" set "ARG=-y"
set "SH="
set "EXEC="
for /f "delims=" %%g in ('git --exec-path 2^>nul') do set "EXEC=%%g"
if defined EXEC set "EXEC=%EXEC:/=\%"
if defined EXEC if exist "%EXEC%\..\..\..\bin\bash.exe" set "SH=%EXEC%\..\..\..\bin\bash.exe"
if not defined SH if exist "%ProgramFiles%\Git\bin\bash.exe" set "SH=%ProgramFiles%\Git\bin\bash.exe"
if not defined SH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "SH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined SH (
  echo Git Bash was not found. Install Git for Windows, or run in any bash:  bash ops/scripts/%~n0.sh
  pause
  exit /b 2
)
"%SH%" "%~dp0%~n0.sh" %ARG%
set "RC=%ERRORLEVEL%"
if not "%ARG%"=="-y" pause
exit /b %RC%
