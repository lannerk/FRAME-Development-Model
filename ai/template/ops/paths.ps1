# ops/paths.ps1 —— 仓库内路径只在这里定义一次
# 所有 .ps1 开头写：  . (Join-Path $PSScriptRoot "..\paths.ps1")
# 以后再改目录名，只改这一个文件。守门：ops/verify/check-paths.sh
# English: single source of truth for in-repo paths.

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SrcRoot  = Join-Path $RepoRoot "src"              # 源码根（多项目：一个项目一个子目录）
$Proj     = Join-Path $SrcRoot  "<项目子目录名>"    # 主项目源码
$Dist     = Join-Path $RepoRoot "dist"             # 构建产物，不入库
$Tmp      = Join-Path $RepoRoot "tmp"              # 临时，不入库，每段清空
$Outputs  = Join-Path $RepoRoot "claude-outputs"   # Claude 草稿区
$Units    = Join-Path $RepoRoot "ops\units"        # systemd 单元
$Web      = Join-Path $Proj "web"
# 下面几行按你的项目结构增删
$Tools    = Join-Path $Proj "tools"
