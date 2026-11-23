# mail-out: puts one letter into a seat's mailbox in another of the requester's projects, for a seat
# whose session cannot reach that project's folder. The projects sit side by side under one parent
# folder, so the other project is ..\<Project> from this repository (docs/guide/seat-runner.md).
# Run it from a seat-runner job (ops\scripts\seat-runner.ps1), for example:
#   & ops\scripts\mail-out.ps1 -Project OtherProject -Seat reviewer -RowFile tmp\supervisor\2026-11-23-03\row.md `
#       -Attach claude-outputs\supervisor\2026-11-23-some-details.md
# What it does, and nothing else:
#   - adds the one table row in -RowFile (UTF-8; date | what to do | where the details are | kind |
#     answer wanted) to ..\<Project>\ai\mail\to-<Seat>\from-<this project>.md, above the empty rows;
#   - with -Attach, copies that file of this repository into ..\<Project>\claude-outputs\shared\ under
#     the same name, so the letter can point at a file its reader can open. An existing file is never
#     overwritten.
# A mailbox table that has its heading row but no |---| row under it gets that row (and says so).
# It refuses (exit 2, and says why) when: the seat is not reviewer or supervisor (ai/mail/README.md:
#   letters from another project go only to those two); the other project has no mailbox file for
#   this project (the requester decides whether there is one, that project's maintainer registers it;
#   this script does not create it); the mailbox already holds 20 unread letters; the same row is
#   already there; the row is not one line of five cells.
# The other project's working tree then has those changes; its own seats commit them on their round.
#   -Dry   say what would be written, write nothing
param([string]$Project = '', [string]$Seat = '', [string]$RowFile = '', [string]$Attach = '', [switch]$Dry)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\paths.ps1')
[Console]::OutputEncoding = [Text.Encoding]::UTF8
function Fail($text) { Write-Output "mail-out: REFUSED: $text"; exit 2 }
if (-not $RepoRoot) { Fail 'ops\paths.ps1 did not give RepoRoot' }
$here = Split-Path -Leaf $RepoRoot
$parent = Split-Path -Parent $RepoRoot
if ($Project -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { Fail 'give -Project <the folder name of the other project>' }
if ($Project -ieq $here) { Fail 'that is this project; write its mailbox file yourself' }
if ($Seat -notmatch '^(reviewer|supervisor)$') { Fail '-Seat is reviewer or supervisor (ai/mail/README.md: letters from another project go only to those two)' }
if (-not $RowFile) { Fail 'give -RowFile <a UTF-8 file with the one table row>' }
$target = Join-Path $parent $Project
$dir = Join-Path $target "ai\mail\to-$Seat"
if (-not (Test-Path $dir)) { Fail "there is no $dir (the projects are expected side by side under $parent)" }
$box = Get-ChildItem -Path $dir -File | Where-Object { $_.Name -ieq "from-$here.md" } | Select-Object -First 1
if (-not $box) {
    $there = (@(Get-ChildItem -Path $dir -File | ForEach-Object { $_.Name }) -join ', ')
    Fail "$Project has no mailbox for $here at $dir\from-$here.md (the requester decides whether there is one; its maintainer registers it). It has: $there"
}
$utf8 = New-Object Text.UTF8Encoding($false)
$rowPath = $RowFile
if (-not [IO.Path]::IsPathRooted($rowPath)) { $rowPath = Join-Path $RepoRoot $rowPath }
if (-not (Test-Path $rowPath)) { Fail "no such row file $RowFile" }
$rows = @([IO.File]::ReadAllLines($rowPath, $utf8) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($rows.Count -ne 1) { Fail "the row file holds $($rows.Count) lines; a letter is one line" }
$row = $rows[0]
if (-not $row.StartsWith('|') -or -not $row.EndsWith('|') -or [regex]::Matches($row, '(?<!\\)\|').Count -ne 6) {
    Fail 'the row is not "| date | what to do | where the details are | kind | answer wanted |" (five cells)'
}
$attachFrom = ''
$attachTo = ''
if ($Attach) {
    $attachFrom = $Attach
    if (-not [IO.Path]::IsPathRooted($attachFrom)) { $attachFrom = Join-Path $RepoRoot $attachFrom }
    if (-not (Test-Path $attachFrom -PathType Leaf)) { Fail "no such file to attach: $Attach" }
    $shared = Join-Path $target 'claude-outputs\shared'
    if (-not (Test-Path $shared)) { Fail "there is no $shared to put the attached file in" }
    $attachTo = Join-Path $shared (Split-Path -Leaf $attachFrom)
    if (Test-Path $attachTo) { Fail "$attachTo is already there; an attached file is never overwritten" }
}
$bytes = [IO.File]::ReadAllBytes($box.FullName)
$bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$text = $utf8.GetString($bytes)
if ($bom) { $text = $text.Substring(1) }
$newline = "`n"
if ($text.Contains("`r`n")) { $newline = "`r`n" }
$lines = @($text -split "`r?`n")
$sep = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\|\s*:?-{3,}') { $sep = $i; break } }
$mended = $false
if ($sep -lt 0) {
    # A mailbox whose table has its heading row but not the |---| row under it (one project's to-reviewer
    # mailbox was like that, 2026-11-23): the row under the heading is put in, then the letter. Anything
    # else is refused.
    $head = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith('|') -and [regex]::Matches($lines[$i], '(?<!\\)\|').Count -eq 6) { $head = $i; break }
    }
    if ($head -lt 0) { Fail "$($box.FullName) has no table to add a row to" }
    $before = @($lines[0..$head])
    $after = @()
    if ($head + 1 -lt $lines.Count) { $after = @($lines[($head + 1)..($lines.Count - 1)]) }
    $lines = @($before + '|---|---|---|---|---|' + $after)
    $sep = $head + 1
    $mended = $true
}
$end = $sep + 1
while ($end -lt $lines.Count -and $lines[$end].TrimStart().StartsWith('|')) { $end++ }
$unread = @()
$blank = @()
for ($i = $sep + 1; $i -lt $end; $i++) {
    if ($lines[$i] -match '^\|(\s*\|)+\s*$') { $blank += $lines[$i] } else { $unread += $lines[$i] }
}
if ($unread.Count -ge 20) { Fail "that mailbox holds $($unread.Count) unread letters (20 at most): put this into your latest letter there, or wait" }
if ($unread -contains $row) { Fail 'that very row is already in the mailbox' }
$out = @()
for ($i = 0; $i -le $sep; $i++) { $out += $lines[$i] }
$out += $unread
$out += $row
if ($blank.Count -gt 1) { $out += $blank[1..($blank.Count - 1)] }
for ($i = $end; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
$result = ($out -join $newline)
if ($bom) { $result = [string][char]0xFEFF + $result }
if ($Dry) {
    Write-Output "mail-out: DRY RUN, nothing written"
    Write-Output "  mailbox: $($box.FullName) ($($unread.Count) unread now, $($unread.Count + 1) after)"
    if ($mended) { Write-Output "  the table there has no |---| row under its heading; it would be added" }
    if ($attachTo) { Write-Output "  attach:  $attachFrom -> $attachTo" }
    Write-Output "  row:     $row"
    exit 0
}
if ($attachTo) { Copy-Item -LiteralPath $attachFrom -Destination $attachTo }
[IO.File]::WriteAllText($box.FullName, $result, $utf8)
Write-Output "mail-out: delivered to $($box.FullName); $($unread.Count + 1) unread there now"
if ($mended) { Write-Output "mail-out: the table there had no |---| row under its heading; added it" }
if ($attachTo) { Write-Output "mail-out: attached $attachTo" }
exit 0
