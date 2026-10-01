@echo off
chcp 65001 >nul
rem clear-dist: 清掉全仓库的构建产物目录（dist、build、out），只删 git 忽略的。仓库根 dist 只删里面的东西、留 README.md。
rem 判据与 clear-dist.sh 完全一样，为什么这么判写在那一份的注释里。
rem 用法：双击；或在命令行  ops\scripts\clear-dist.bat [/y]   （/y = 不问直接删）
rem 项目还有别的目录名：set CLEAR_DIST_EXTRA=名字 名字  后再跑，不用改这份。
setlocal EnableExtensions EnableDelayedExpansion
set "GIT_OPTIONAL_LOCKS=0"
set "YES=0"
if /i "%~1"=="/y" set "YES=1"
if /i "%~1"=="-y" set "YES=1"
set "ROOT="
for /f "delims=" %%r in ('git -C "%~dp0." rev-parse --show-toplevel 2^>nul') do set "ROOT=%%r"
if not defined ROOT (
  echo 不在 git 仓库里，或没装 git。
  goto :end
)
cd /d "%ROOT%"
set "NAMES=dist build out .next .output storybook-static %CLEAR_DIST_EXTRA%"
set "LIST=%TEMP%\clear-dist-%RANDOM%%RANDOM%.txt"
type nul > "%LIST%"
set "N=0"
for /f "delims=" %%p in ('git -c core.quotepath^=false ls-files --others --ignored --exclude-standard --directory 2^>nul') do (
  set "P=%%p"
  if "!P:~-1!"=="/" (
    set "D=!P:~0,-1!"
    set "D=!D:/=\!"
    set "B="
    for %%b in ("!D!") do set "B=%%~nxb"
    set "HIT="
    for %%n in (!NAMES!) do if /i "!B!"=="%%n" set "HIT=1"
    if defined HIT if /i "!D!"=="dist" (
      set "HAS="
      for /d %%y in ("dist\*") do set "HAS=1"
      for %%y in ("dist\*") do if /i not "%%~nxy"=="README.md" set "HAS=1"
      if not defined HAS set "HIT="
    )
    if defined HIT (
      set "T="
      for /f "delims=" %%x in ('git ls-files -- "!D!" 2^>nul') do set "T=1"
      if defined T (
        echo   跳过，里面有 git 跟踪的文件：!D!
      ) else (
        >>"%LIST%" echo !D!
        set /a N+=1
      )
    )
  )
)
if "%N%"=="0" (
  echo CLEAR-DIST-OK：没有可清的构建产物
  goto :end
)
echo 下面 %N% 个目录 git 不收、名字是构建产物，可以删：
for /f "usebackq delims=" %%d in ("%LIST%") do if /i "%%d"=="dist" (echo   dist，只删里面的东西，留 README.md) else (echo   %%d)
if "%YES%"=="1" goto :do
set "A="
set /p "A=确认删除？输入 y 回车："
if /i not "!A!"=="y" (
  echo 没删。
  goto :end
)
:do
set "F=0"
for /f "usebackq delims=" %%d in ("%LIST%") do (
  if /i "%%d"=="dist" (
    for /d %%y in ("dist\*") do rd /s /q "%%y"
    for %%y in ("dist\*") do if /i not "%%~nxy"=="README.md" del /f /q "%%y"
  ) else (
    if exist "%%d\" rd /s /q "%%d"
    if exist "%%d\" (
      echo   删不掉：%%d
      set /a F+=1
    )
  )
)
if "%F%"=="0" (echo CLEAR-DIST-OK：删了 %N% 个目录，要用时重新构建) else (echo CLEAR-DIST-FAIL：%F% 个删不掉，多半是文件正被占用或路径太长)
:end
if exist "%LIST%" del "%LIST%" >nul 2>&1
if "%YES%"=="0" pause
endlocal
