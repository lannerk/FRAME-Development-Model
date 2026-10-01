@echo off
chcp 65001 >nul
rem clear-to-delete: remove the _to_delete directories AI sessions leave in the repo, never one holding a git-tracked file.
rem Same criterion as clear-to-delete.sh; the reasons are in that file's comments.
rem Usage: double-click; or on a command line  ops\scripts\clear-to-delete.bat [/y]   (/y = delete without asking)
setlocal EnableExtensions EnableDelayedExpansion
set "GIT_OPTIONAL_LOCKS=0"
set "YES=0"
if /i "%~1"=="/y" set "YES=1"
if /i "%~1"=="-y" set "YES=1"
set "ROOT="
for /f "delims=" %%r in ('git -C "%~dp0." rev-parse --show-toplevel 2^>nul') do set "ROOT=%%r"
if not defined ROOT (
  echo Not inside a git repository, or git is not installed.
  goto :end
)
cd /d "%ROOT%"
set "LIST=%TEMP%\clear-to-delete-%RANDOM%%RANDOM%.txt"
type nul > "%LIST%"
set "N=0"
for /f "delims=" %%d in ('dir /s /b /ad _to_delete 2^>nul ^| findstr /v /i /c:"\\node_modules\\" /c:"\\.git\\" /c:"\\_to_delete\\"') do (
  set "T="
  for /f "delims=" %%x in ('git ls-files -- "%%d" 2^>nul') do set "T=1"
  if defined T (
    echo   skipped, holds git-tracked files; look at it in your git client first: %%d
  ) else (
    >>"%LIST%" echo %%d
    set /a N+=1
  )
)
if "%N%"=="0" (
  echo CLEAR-TO-DELETE-OK: no _to_delete directory to clean
  goto :end
)
echo These %N% _to_delete directories can go:
for /f "usebackq delims=" %%d in ("%LIST%") do echo   %%d
if "%YES%"=="1" goto :do
set "A="
set /p "A=Delete them? Type y and press Enter: "
if /i not "!A!"=="y" (
  echo Nothing deleted.
  goto :end
)
:do
set "F=0"
for /f "usebackq delims=" %%d in ("%LIST%") do (
  if exist "%%d\" rd /s /q "%%d"
  if exist "%%d\" (
    echo   could not delete: %%d
    set /a F+=1
  )
)
if "%F%"=="0" (echo CLEAR-TO-DELETE-OK: deleted %N% directories) else (echo CLEAR-TO-DELETE-FAIL: %F% could not be deleted, usually a file in use or a path too long)
:end
if exist "%LIST%" del "%LIST%" >nul 2>&1
if "%YES%"=="0" pause
endlocal
