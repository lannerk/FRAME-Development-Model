@echo off
rem Thin wrapper: all logic lives in the .ps1 of the same name next to this file.
rem Double-click it to open the one runner for every seat, and leave the window open.
rem Every argument goes through to seat-runner.ps1.
rem
rem KEEP THIS FILE PURE ASCII (release.bat says why).
setlocal
cd /d "%~dp0..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0%~n0.ps1" %*
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
