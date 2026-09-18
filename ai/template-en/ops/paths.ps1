# ops/paths.ps1 -- in-repo paths are defined here, once
# Every .ps1 starts with:  . (Join-Path $PSScriptRoot "..\paths.ps1")
# Rename a directory later and you change this one file only. Guard: ops/verify/check-paths.sh

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SrcRoot  = Join-Path $RepoRoot "src"              # source root (multi-project: one subdirectory each)
$Proj     = Join-Path $SrcRoot  "<project-subdir>" # the main project's source
$Dist     = Join-Path $RepoRoot "dist"             # build output, not committed
$Tmp      = Join-Path $RepoRoot "tmp"              # temporary, not committed, emptied every stage
$Outputs  = Join-Path $RepoRoot "claude-outputs"   # Claude's scratch area
$Units    = Join-Path $RepoRoot "ops\units"        # systemd units
$Web      = Join-Path $Proj "web"
# Add or remove the lines below to match your project's structure
$Tools    = Join-Path $Proj "tools"
