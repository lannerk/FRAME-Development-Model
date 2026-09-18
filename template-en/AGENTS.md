# Entry point (non-Claude platforms)

**The real entry point of this repository is `CLAUDE.md`. Go read it now and follow it.**

Do not infer anything else from this file — the identity command words, the hard laws and the
directory guide are **all in `CLAUDE.md` and the files it points at**.

---

> **Why a one-line pointer instead of a copy**: once two entry documents exist side by side they
> **drift apart, with no symptom at all** — someone edits one, the other still gets auto-loaded,
> and nobody finds out until a session works to an outdated rule. So this file holds only a pointer:
> **a pointer cannot go stale.**
>
> **To support another platform**, add another file it auto-loads, shaped like this one
> (`GEMINI.md`, `.github/copilot-instructions.md`, `.cursor/rules/` …), containing **only the same pointer**.
> Guard: `bash ops/verify/check-entrypoints.sh`.
>
> **The name `CLAUDE.md` cannot change** — the guard scripts use it to locate the repo root.
