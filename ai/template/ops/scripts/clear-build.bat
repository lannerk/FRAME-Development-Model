@echo off
chcp 65001 >nul
rem clear-build: 清掉全仓库的依赖与构建临时目录（node_modules、各类缓存），只删 git 忽略的。构建产物用 clear-dist。
rem 判据与 clear-build.sh 完全一样，为什么这么判写在那一份的注释里。
rem 用法：双击；或在命令行  ops\scripts\clear-build.bat [/y]   （/y = 不问直接删）
rem 项目还有别的目录名：set CLEAR_BUILD_EXTRA=名字 名字  后再跑，不用改这份。
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
set "NAMES=node_modules .pnpm-store .turbo .vite .cache .parcel-cache .svelte-kit .nuxt .angular coverage __pycache__ .pytest_cache .mypy_cache .ruff_cache %CLEAR_BUILD_EXTRA%"
set "LIST=%TEMP%\clear-build-%RANDOM%%RANDOM%.txt"
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
  echo CLEAR-BUILD-OK：没有可清的依赖或构建临时目录
  goto :end
)
echo 下面 %N% 个目录 git 不收、名字是依赖或构建临时目录，可以删：
for /f "usebackq delims=" %%d in ("%LIST%") do echo   %%d
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
  if exist "%%d\" rd /s /q "%%d"
  if exist "%%d\" (
    echo   删不掉：%%d
    set /a F+=1
  )
)
if "%F%"=="0" (echo CLEAR-BUILD-OK：删了 %N% 个目录，要用时重新装依赖) else (echo CLEAR-BUILD-FAIL：%F% 个删不掉，多半是文件正被占用或路径太长)
:end
if exist "%LIST%" del "%LIST%" >nul 2>&1
if "%YES%"=="0" pause
endlocal
