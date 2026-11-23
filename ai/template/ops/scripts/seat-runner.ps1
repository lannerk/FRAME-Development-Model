# seat-runner: one runner for every seat of this repository. It runs the Windows scripts the seats drop
# into it (checks, builds, git, reading folders a session cannot reach), so that nothing a script can do
# has to be asked of the requester. How and when to use it: docs/guide/seat-runner.md.
# One window per project: it serves only the repository it sits in.
# Start it once from the repository root and leave the window open:
#   powershell -NoProfile -ExecutionPolicy Bypass -File ops\scripts\seat-runner.ps1
#
# Seats: one line each in ops\scripts\seat-runner.conf (name | box | scripts | order). The file is read
#   again whenever it changes, so a seat that adds its line is served without a restart. A line that
#   does not hold is skipped and said in tmp\seat-runner\runner.log.
# What a seat does:
#   1. writes a script where its line says (for example tmp\reviewer\2026-11-23-01\check.ps1);
#   2. writes a job file <box>\inbox\<id>.job whose first line is that script's path from the
#      repository root; a second line "nowait" makes it a quick job;
#   3. reads <box>\outbox\<id>.log (and <id>.err.log) and, when the job has ended, <id>.done
#      ("exit=<code> minutes=<m> script=<path>"; "refused" or "missing" when it was not run).
#   Every job is a line in <box>\runner.log, and in tmp\seat-runner\runner.log with the seat's name.
# Two kinds of job:
#   - a quick job ("nowait"): for what neither builds nor tests (git, reading files, a probe). It
#     starts within a second, whatever else is running. Each seat has its own lane for them: one
#     quick job per seat at a time, the seats side by side, so a seat whose quick job hangs holds up
#     nobody else. 10 minutes at most.
#   - a long job (no second line): one at a time for the whole machine, 120 minutes at most. Two
#     builds at once ran a requester's machine out of page file, and the seats mostly share one build
#     folder. When several seats have one waiting, the lowest "order" goes first; within a seat, the
#     job files in name order.
#   A job that runs past its time is ended with everything it started, and its .done says exit=timeout.
# A job is refused (and logged) unless its id is letters, digits, "_" and "-" and its script is where
#   the seat's line says; so a seat cannot run another seat's scripts or anything outside tmp\.
# Defaults for every job's environment: a line "env | NAME | value" in the seats file (for example a
#   project that must build with one job at a time). A variable already set where the runner was
#   started is left as it is.
# A wrapper for long jobs: a line "wrap | ops\scripts\<name>.ps1" in the seats file. Every long job is then
#   started as  <wrapper> -By "<seat> <id>" -Run "<script>"  and the wrapper runs the script and ends with
#   its exit code (for example a project that trims its build cache before each build). Quick jobs never
#   go through it.
# Stop: create tmp\seat-runner\STOP (no new job starts; the runner ends when the running ones have
#   ended), or close this window or press Ctrl+C (that ends the running jobs too).
# It does not start while another seat-runner of THIS repository is open: two runners on one inbox would
#   each take half the jobs. Runners of other projects are no concern (one window per project): the guard
#   is a mutex named after this repository's path, not a look at the command lines of every PowerShell
#   (that look stopped a second project's runner while the first project's was open, 2026-11-23).
#   -Conf <file>          another seats file (for testing this script)
#   -Box <dir>            the runner's own folder instead of tmp\seat-runner (for testing this script)
#   -QuickMinutes <n>     another limit for quick jobs (for testing this script)
#   -LongMinutes <n>      another limit for long jobs (for testing this script)
#   -Test                 do not look for other runners (for testing this script)
param([string]$Conf = '', [string]$Box = '', [double]$QuickMinutes = 10, [double]$LongMinutes = 120, [switch]$Test)
$ErrorActionPreference = 'Continue'
# paths.ps1 is UTF-8 with a BOM, so Windows PowerShell 5.1 reads it whole; what this script needs from it
# is still checked below.
. (Join-Path $PSScriptRoot '..\paths.ps1')
if (-not $RepoRoot -or -not $Tmp) { Write-Host 'seat-runner: ops\paths.ps1 did not give RepoRoot and Tmp'; exit 1 }
$repo = $RepoRoot
if (-not $Conf) { $Conf = Join-Path $PSScriptRoot 'seat-runner.conf' }
if (-not $Box) { $Box = Join-Path $Tmp 'seat-runner' }
if (-not $Test) {
    # One mutex per repository: the name carries a hash of the repository path, so another project's runner
    # never matches. Windows releases it when this process ends, however it ends.
    $sha = [Security.Cryptography.SHA256]::Create()
    $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($repo.TrimEnd('\').ToLowerInvariant()))).Replace('-', '').Substring(0, 16)
    $script:held = New-Object System.Threading.Mutex($false, "Local\seat-runner-$key")
    $mine = $false
    try { $mine = $script:held.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $mine = $true }
    $pidFile = Join-Path $Box 'runner.pid'
    if (-not $mine) {
        $who = ''
        if (Test-Path $pidFile) { $who = ' (PID ' + (Get-Content -Raw $pidFile).Trim() + ')' }
        Write-Host "seat-runner: a runner for $repo is already open$who. Close that window first, then start this one again."
        exit 1
    }
    New-Item -ItemType Directory -Force -Path $Box | Out-Null
    "$PID" | Set-Content -Encoding ASCII $pidFile
}
New-Item -ItemType Directory -Force -Path $Box | Out-Null
$mainLog = Join-Path $Box 'runner.log'
$stopFile = Join-Path $Box 'STOP'
$given = @{}      # the variables set where the runner was started: an "env" line leaves them alone
foreach ($e in @(Get-ChildItem Env:)) { $given[$e.Name.ToUpper()] = $true }
function Stamp { return (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }
# A line about the runner itself.
function Say($text) {
    $line = (Stamp) + ' ' + $text
    Write-Host $line
    Add-Content -Encoding UTF8 $mainLog $line
}
# A line about a seat's job: to the seat's own runner.log, and with the seat's name to the runner's.
function Note($seat, $text) {
    $line = (Stamp) + ' ' + $text
    Write-Host ("[$($seat.name)] " + $line)
    Add-Content -Encoding UTF8 $seat.log $line
    Add-Content -Encoding UTF8 $mainLog ((Stamp) + " [$($seat.name)] " + $text)
}
# The seats the seats file names, lowest order first. A line that does not hold is said and skipped.
function LoadSeats {
    $list = @()
    $boxes = @{}
    $names = @{}
    $envs = @()
    $script:wrap = ''
    foreach ($raw in @(Get-Content -Encoding UTF8 $Conf -ErrorAction SilentlyContinue)) {
        $line = "$raw".Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $f = @($line.Split('|') | ForEach-Object { $_.Trim() })
        if ($f[0] -eq 'env') {
            if ($f.Count -ne 3 -or $f[1] -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { Say ('seats file: skipped "' + $line + '": an env line is env | NAME | value'); continue }
            if ($given.ContainsKey($f[1].ToUpper())) { continue }
            [Environment]::SetEnvironmentVariable($f[1], $f[2], 'Process')
            $envs += "$($f[1])=$($f[2])"
            continue
        }
        if ($f[0] -eq 'wrap') {
            if ($f.Count -ne 2 -or $f[1] -notmatch '^ops\\scripts\\[A-Za-z0-9_-]+\.ps1$') { Say ('seats file: skipped "' + $line + '": a wrap line is wrap | ops\scripts\<name>.ps1'); continue }
            $script:wrap = $f[1]
            continue
        }
        $bad = ''
        if ($f.Count -ne 4) { $bad = 'it needs four fields: name | box | scripts | order'
        } elseif ($f[0] -notmatch '^[a-z][a-z0-9-]*$') { $bad = 'the name is small letters, digits and "-"'
        } elseif ($f[1] -notmatch '^tmp\\[A-Za-z0-9_\\.-]+$' -or $f[1].Contains('..')) { $bad = 'the box is a folder under tmp\'
        } elseif ($f[2] -notmatch '^tmp\\[A-Za-z0-9_\\.<>-]+\\<name>\.ps1$' -or $f[2].Contains('..')) { $bad = 'the scripts are tmp\...\<name>.ps1'
        } elseif ($f[3] -notmatch '^\d+$') { $bad = 'the order is a number'
        } elseif ($names.ContainsKey($f[0])) { $bad = 'that name is taken'
        } elseif ($boxes.ContainsKey($f[1].ToLower())) { $bad = 'that box is taken' }
        if ($bad) { Say ('seats file: skipped "' + $line + '": ' + $bad); continue }
        $names[$f[0]] = $true
        $boxes[$f[1].ToLower()] = $true
        $seatBox = Join-Path $repo $f[1]
        $seat = @{
            name = $f[0]
            order = [int]$f[3]
            words = $f[2]
            rx = '^' + [regex]::Escape($f[2]).Replace('<date>', '\d{4}-\d{2}-\d{2}').Replace('<n>', '\d+').Replace('<name>', '[A-Za-z0-9_-]+') + '$'
            inbox = Join-Path $seatBox 'inbox'
            outbox = Join-Path $seatBox 'outbox'
            log = Join-Path $seatBox 'runner.log'
        }
        New-Item -ItemType Directory -Force -Path $seat.inbox, $seat.outbox | Out-Null
        $list += $seat
    }
    if ($envs.Count -gt 0) { Say ('job environment: ' + ($envs -join ', ')) }
    if ($script:wrap) { Say ('long jobs go through ' + $script:wrap) }
    return @($list | Sort-Object { $_.order }, { $_.name })
}
# The job files in a seat's inbox, in name order.
function JobsOf($seat) { return @(Get-ChildItem -Path $seat.inbox -Filter '*.job' -File -ErrorAction SilentlyContinue | Sort-Object Name) }
# The lines of a job file that say something.
function JobLines($path) {
    return @(Get-Content -Encoding UTF8 $path -ErrorAction SilentlyContinue | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
}
# Takes a job out of the inbox and starts its script. Returns what Reap needs, or $null when the job
# was not run (its .done says why).
function StartJob($seat, $job, $lines, $how) {
    $id = $job.BaseName
    $rel = ''
    if ($lines.Count -gt 0) { $rel = $lines[0] }
    Remove-Item -Force $job.FullName
    $done = Join-Path $seat.outbox "$id.done"
    if ($id -notmatch '^[A-Za-z0-9_-]+$' -or $rel -notmatch $seat.rx) {
        Note $seat "REFUSED job $id ($rel): not a $($seat.words)"
        'refused' | Set-Content -Encoding UTF8 $done
        return $null
    }
    $script = Join-Path $repo $rel
    if (-not (Test-Path $script)) { Note $seat "job $id - no such script $rel"; 'missing' | Set-Content -Encoding UTF8 $done; return $null }
    Note $seat "job $id - running $rel (output in outbox\$id.log)$how"
    $out = Join-Path $seat.outbox "$id.log"
    $err = Join-Path $seat.outbox "$id.err.log"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
    if (-not $how -and $script:wrap) {
        $wrapper = Join-Path $repo $script:wrap
        if (Test-Path $wrapper) { $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper`" -By `"$($seat.name) $id`" -Run `"$rel`""
        } else { Note $seat "job $id - no such wrapper $($script:wrap); running the script without it" }
    }
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $repo -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
    $null = $p.Handle  # without it ExitCode can come back empty
    return @{ p = $p; seat = $seat; id = $id; rel = $rel; start = (Get-Date); done = $done }
}
# Has that job ended (by itself, or because its time is up)? When it has, its .done is written.
function Reap($run, $minutes) {
    $code = $null
    if ($run.p.HasExited) {
        $code = $run.p.ExitCode
    } elseif (((Get-Date) - $run.start).TotalMinutes -ge $minutes) {
        & taskkill /T /F /PID $run.p.Id | Out-Null
        $code = 'timeout'
    }
    if ($null -eq $code) { return $false }
    $mins = [Math]::Round(((Get-Date) - $run.start).TotalMinutes, 1)
    "exit=$code minutes=$mins script=$($run.rel)" | Set-Content -Encoding UTF8 $run.done
    Note $run.seat "job $($run.id) - finished: exit=$code in $mins min"
    return $true
}
$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say "seat-runner started; repo $repo; seats file $Conf; elevated=$elevated"
$seats = @()
$confStamp = $null
$quick = @{}     # seat name -> the quick job that seat has running
$long = $null    # the one long job running
$stopping = $false
while ($true) {
    if (-not $stopping -and (Test-Path $stopFile)) {
        Remove-Item -Force $stopFile
        $stopping = $true
        Say 'STOP found - no new jobs; the runner ends when the running ones have ended'
    }
    $item = Get-Item $Conf -ErrorAction SilentlyContinue
    $stamp = $null
    if ($item) { $stamp = $item.LastWriteTimeUtc.Ticks }
    if ($stamp -ne $confStamp) {
        $confStamp = $stamp
        $seats = @(LoadSeats)
        Say ('seats: ' + (@($seats | ForEach-Object { "$($_.name)($($_.order))" }) -join ', '))
    }
    foreach ($name in @($quick.Keys)) { if (Reap $quick[$name] $QuickMinutes) { $quick.Remove($name) } }
    if ($long -and (Reap $long $LongMinutes)) { $long = $null }
    if ($stopping) {
        if ($quick.Count -eq 0 -and -not $long) { Say 'runner ends'; break }
        Start-Sleep -Seconds 1
        continue
    }
    $next = $null   # the long job to start: the first one of the first seat that has one
    foreach ($seat in $seats) {
        foreach ($j in (JobsOf $seat)) {
            $l = @(JobLines $j.FullName)   # @(): one line would come back as a string, and [0] its first letter
            if ($l -contains 'nowait') {
                if ($quick.ContainsKey($seat.name)) { continue }
                $run = StartJob $seat $j $l ' [nowait]'
                if ($run) { $quick[$seat.name] = $run }
            } elseif (-not $long -and -not $next) {
                $next = @{ seat = $seat; job = $j; lines = $l }
            }
        }
    }
    if ($next) {
        $run = StartJob $next.seat $next.job $next.lines ''
        if ($run) { $long = $run }
    }
    Start-Sleep -Seconds 1
}
