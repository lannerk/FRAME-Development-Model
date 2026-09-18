# The real machine / test environment debug path (all three seats need this)

> **Required for a new project.** All three seats get onto the real machine; this file saves them from figuring it out again every time.
> **Machine details live in `ops/machines.json`; no IPs here.**

## 1. The path

```
         ┌──────────────┐  version ctl  ┌──────────────┐
         │  local repo  │ ◀───────────▶ │ remote repo  │
         └───┬──────▲───┘
             │      │  write back + verify, same round (required)
             ▼      │
        ┌─────────────────┐   deploy    ┌─────────────────────┐
        │ build / package │ ──────────▶ │ test machine (main) │
        └─────────────────┘ ◀─terminal─ └─────────────────────┘
```

| Seat | What it does on the real machine | Over what channel |
|---|---|---|
| **Developer** | change code → build → deploy → verify → write back to the repo the same round | `<deploy script / upload page / terminal>` |
| **Reviewer** | re-check what development handed in: run the self-checks independently, read the code, verify the measured numbers | `<run the build and self-checks in a clean environment>` + read logs over the terminal |
| **Supervisor** | dig into problems, pin down root causes | terminal + reading the repo |

`<If there is a terminal you can get into without a password, write it down here and say why it does not cross the security line —`
`otherwise every seat goes bothering the Requester just to read one line of log (hard law 5).>`

## 2. How to use the build / test environment

```
<the packaging command>
<the commands to unpack, build, and run the tests and self-checks in a clean environment>
```

**Watch the relative paths inside tests**: if test code reads files from the repo through paths like `../../`,
the unpacked directory depth has to match the repo's, or those tests will not find the files.
**Not finding a file must FAIL, not PASS** — "quietly not running" is much harder to spot than "running and erroring".

## 3. Deployment scripts

**Deployment scripts all live in `ops/scripts/`, and you call them with the path** (`powershell -File ops\scripts\<name>.ps1`).
🔴 **No scripts at the repo root** — the top-level list in `ai/rules/layout.md` §1 has no slot for scripts, and
"one thing has exactly one home". **This page used to teach putting a thin shell at the root, which contradicts §1 outright**:
following it, this project really did grow four `.ps1` files at the root (commit `6212162`), found by the Developer seat on
2026-09-16 when the Requester asked why the root did not match the rules. The typing it saves is paid for with a hole in the
root directory, and the next person will use that hole for something else.

**No hard-coded paths or IPs in scripts**: paths come from `ops/paths.ps1`, machines from `ops/machines.json`.
Guard: `ops/verify/check-paths.sh`.

## 4. Paths on the real machine do not go into the repo

`<List the key paths on the real machine: program directory, data directory, service unit, ports>`

**These are not in the repo**, so however the repo's directories change it does not touch them — **directory reshuffles only happen on the repo side**.

## 5. What counts as verified once you are done

- [ ] Every deployment script is under `ops/scripts/`, and **there are no scripts at the repo root**
- [ ] Build in a clean environment + run every self-check, all green
- [ ] See the actual change on the real machine (not "it should have taken effect")
- [ ] Write back to the repo the same round and verify each item

---

## Writing back to the local repo (what to do when the write fails)

**The repo is the only source.** Change things on another machine and you must write back in the same round. The write-back can be refused (the file is held by an editor or antivirus).
**Try in this order, and do not keep retrying the same trick:**

1. **Normal write-back** → then reconcile each file with `sha256sum -c`. **No reconciliation = no write-back.**
2. **Refused → use the rename trick** (a hold usually locks "open", not "rename"):
   ```
   mv oldfile oldfile.bak && cp newfile oldfile && rm oldfile.bak
   ```
3. **Rename trick fails too → change path**: write into `tmp/`, and state in the report "which file did not get written, where the temporary copy is, and how to merge it".
4. **Still no good → ask for permission**, and **do not make the Requester run commands** (hard law 5).

**Three things not to do**: do not retry the same failing method over and over; do not treat "please run this command for me" as a solution;
do not change only the runtime environment and leave the repo alone (the runtime environment is volatile, the repo is the source).
