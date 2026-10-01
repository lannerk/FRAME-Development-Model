@echo off
chcp 65001 >nul
rem clear-to-delete: 删掉 AI 会话留在仓库里的 _to_delete 目录，里面有 git 跟踪的文件就不删。
rem 判据与 clear-to-delete.sh 完全一样，为什么这么判写在那一份的注释里。
rem 用法：双击；或在命令行  ops\scripts\clear-to-delete.bat [/y]   （/y = 不问直接删）
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
set "LIST=%TEMP%\clear-to-delete-%RANDOM%%RANDOM%.txt"
type nul > "%LIST%"
set "N=0"
for /f "delims=" %%d in ('dir /s /b /ad _to_delete 2^>nul ^| findstr /v /i /c:"\\node_modules\\" /c:"\\.git\\" /c:"\\_to_delete\\"') do (
  set "T="
  for /f "delims=" %%x in ('git ls-files -- "%%d" 2^>nul') do set "T=1"
  if defined T (
    echo   跳过，里面有 git 跟踪的文件，先在图形客户端里看一眼：%%d
  ) else (
    >>"%LIST%" echo %%d
    set /a N+=1
  )
)
if "%N%"=="0" (
  echo CLEAR-TO-DELETE-OK：没有可清的 _to_delete 目录
  goto :end
)
echo 下面 %N% 个 _to_delete 目录可以删：
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
if "%F%"=="0" (echo CLEAR-TO-DELETE-OK：删了 %N% 个目录) else (echo CLEAR-TO-DELETE-FAIL：%F% 个删不掉，多半是文件正被占用或路径太长)
:end
if exist "%LIST%" del "%LIST%" >nul 2>&1
if "%YES%"=="0" pause
endlocal
