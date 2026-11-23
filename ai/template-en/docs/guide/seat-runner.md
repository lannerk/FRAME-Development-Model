# The runner: AI seats running commands on the Requester's Windows computer

> **Who reads this**: any seat, the moment it cannot run a command in its own session (Law 5, `ai/rules/laws.md`).
> The script is `ops/scripts/seat-runner.ps1` (its header is the authority on how it works); the seats file is `ops/scripts/seat-runner.conf` (the project's own, `seed`).
> Where it came from: in one consumer project three runners each had their own window and served one seat each; the Requester decided "make it one runner that every seat registers with, without getting in each other's way ... from now on, whatever the runner can run, don't come to me" (2026-11-23), and it then went into FRAME as the standard way.

## 1. One order, nothing else

1. **What you can run in your own session, you run yourself** (for example the session's own shell, when the command runs correctly there). Don't go through the runner for that; it only adds a step.
2. **What you cannot run yourself, you hand to the runner**: anything that has to run on Windows (compilers, PowerShell scripts, Windows git), a session that has no shell this time, folders the session cannot reach (sibling projects, the FRAME source).
3. **Only when neither works do you go to the Requester.** First make sure the runner window is simply not open: if it isn't, ask him to open it once. **Do not ask him to run the command for you.**

🔴 **Whatever the runner can run, never ask the Requester to do by hand.**

## 2. What it is

- A small program that stays running. The Requester opens it **once at the repo root and leaves the window open**: double-click `ops\scripts\seat-runner.bat`, or
  `powershell -NoProfile -ExecutionPolicy Bypass -File ops\scripts\seat-runner.ps1`.
- **One window serves every seat of this repository**; **one window per project** (it serves only the repository it sits in).
- It runs the PowerShell scripts each seat writes **under the Requester's account**. He does not see a script before it runs, so:
  - **read your whole script before you hand it in**;
  - 🔴 **the go-ahead has to come from the Requester himself**: an open window only says he agrees to have scripts run for him. Some AI tools also want him to say so **in this session** before they will hand a job in;
    "you may use it", passed on by another seat, does not count (measured: a seat handed in a job on such a relayed word and the tool's safety check refused it). If you are refused, ask him to say it in the session; **do not look for a way around it**.

## 3. How to use it (three steps)

1. **Write the script** where your seat's line in the seats file says, for example `tmp\reviewer\2026-11-23-01\check.ps1`.
2. **Hand in the job**: write `<box>\inbox\<id>.job`; its first line is the script's path from the repo root; a quick job gets a second line `nowait`.
   🔴 **Put the script in place first, then the job file**: a job file is taken the moment it appears, and a script that is not there yet comes back `missing`.
3. **Read the result**: `<box>\outbox\<id>.log` (standard output), `<id>.err.log` (standard error); when it has ended, `<id>.done` holds
   `exit=<code> minutes=<m> script=<path>`; a job that was not run holds `refused` (the path is not where the seat's line says) or `missing` (no such script).

`<id>` and `<name>` are letters, digits, `_` and `-`. **Is the runner open?** The last line of `runner.log` in your box keeps moving;
every seat's jobs are also logged in `tmp\seat-runner\runner.log`, each line starting with the seat's name.

## 4. Two kinds of job

| | Quick job | Long job |
|---|---|---|
| How to mark it | second line `nowait` | no second line |
| What for | what neither builds nor tests: git, reading files, probes, guard runs, letters to another project | builds, tests, evaluations, packaging |
| When it starts | within a second, whatever else is running | one at a time for the whole machine, queued |
| Effect on others | one lane per seat, seats side by side; a seat that hangs holds up nobody | when several seats wait, the order in the seats file decides; within a seat, file name order |
| Limit | 10 minutes | 120 minutes |

- A job past its limit is ended together with the processes it started; `.done` says `exit=timeout`.
- **Builds and tests always go in as long jobs**: two builds at once can run a machine out of page file, and the seats mostly share one build folder.
- Two seats doing git writes at the same time collide on the lock; if that happens, hand the job in again.

## 5. Writing the script (each of these was learned the hard way)

- **Encoding**: a script with non-ASCII text is saved as UTF-8 with a BOM (Windows PowerShell 5.1 does not take UTF-8 without one); start with
  `[Console]::OutputEncoding = [Text.Encoding]::UTF8`; read text with `Get-Content -Encoding UTF8`, or non-ASCII text comes out garbled.
- **bash**: on Windows `bash` is often WSL's. Run the repository's `.sh` files with the one that ships with Git: `C:\Program Files\Git\bin\bash.exe`.
- **Read-only git gets `$env:GIT_OPTIONAL_LOCKS = '0'` first** (`git status` otherwise creates `index.lock` along the way).
- **The working directory is the repo root**; paths come from `ops/paths.ps1`, machines from `ops/machines.json`, nothing hard-coded.
- **One scenario, one script**: the services it starts and the windows it opens are cleaned up in the same script. Split into several jobs, what the first one started belongs to no one.
- **Exit code**: end the script with `exit <code>`; that is what `.done` records.
- To give every job a default environment variable (say, to limit build parallelism), add a line `env | NAME | value` to the seats file instead of setting it in each script.
- To do the same thing around **every long job** (say, trim the build cache back under its limit first), put a wrapper script in `ops\scripts\` and add a line `wrap | ops\scripts\<name>.ps1` to the seats file: the runner then starts long jobs as `<wrapper> -By "<seat> <id>" -Run "<script>"`, and the wrapper runs that script and ends with its exit code. Quick jobs never go through it.

## 6. Sibling projects and the FRAME source

The Requester's projects often sit side by side under one parent folder; a session is usually connected to its own project only, **the runner can reach** `..\<project>`.

- **Reading**: in the job, copy what you need into your own `tmp\<seat>\<date>-<n>\`, then read it from the session.
- **Sending a letter**: use `ops\scripts\mail-out.ps1` only, never write the other project's files by hand:
  `& ops\scripts\mail-out.ps1 -Project <its folder name> -Seat reviewer -RowFile <file with one letter row> [-Attach <details file>] [-Dry]`.
  It delivers only to the Reviewer or Supervisor seat (`ai/mail/README.md`: letters from another project go to those two only), and refuses, saying why, when
  the other project has not opened a mailbox for this one, the mailbox already holds 20 letters, or the same row is already there; `-Attach` puts the details file, under its own name, into the other project's `claude-outputs\shared\`, never over an existing file.
  The other project's working tree then has those changes; its own seats commit them on their round.
- **The Maintainer aligning with the FRAME source**: run the ten steps of `docs/guide/frame-sync.md` inside a job (`home=` in `ai/frame-repo.conf` points at the source).
- **Apart from these three, write nothing into another project.**

## 7. Registering, stopping, starting again

- **Registering a seat**: add a line `name | box | scripts | order` to `seat-runner.conf`; the runner notices the change and reads it again, no restart. A line that does not hold is skipped and the reason logged in `tmp\seat-runner\runner.log`.
- **Stopping**: create an empty file `tmp\seat-runner\STOP` (no new job starts; the runner exits when the running ones end), or close the window (running jobs end with it).
- Starting a second runner while one is open: it refuses and says which one is open.
- 🔴 **When emptying `tmp/`, skip every seat's box and `tmp\seat-runner\`**: clear only your own stage's script folders.
