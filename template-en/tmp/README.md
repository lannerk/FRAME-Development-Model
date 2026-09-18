# tmp/ — one-off workspace (**not committed**)

Holds **whatever gets generated for packaging, releasing, deploying or moving files**: transfer tgzs, temporary scripts, logs pulled down, copies for diffing,
and anything that is "useless once used, because it can be regenerated at any time", file or directory.

## Four rules

1. **The whole directory is in `.gitignore`, not committed.**
2. **Need to make a one-off file or directory? Make it here.** Don't make it somewhere else and come back to add an ignore rule —
   that is exactly the process that grew six `_to_delete/` directories (17MB / 109 files) before, and in the end the Requester had to say the word to get them cleared.
3. **Put a date in the name**: `2026-09-16-packaging/`, `2026-09-16-upgrade-package.tgz`. Nobody dares delete an undated one next stage.
4. **Whoever makes it cleans it, deleted by yourself at this stage's wrap-up**, with a line in the report saying "this stage's temporary files are cleared".
   **Don't make the Requester run `rm`** (hard law 5). No permission? Ask for it once in the conversation; once is enough.

## What does **not** go here

| Not here | Where it goes | Why |
|---|---|---|
| Specs, reports, review records, supervisor output | `claude-outputs/<role>/` | They get committed — they are the evidence for a later re-check |
| Screenshots, measured data, self-check output | `claude-outputs/developer/` or `shared/` | Same as above; task files reference them by path |
| Build output, upgrade packages, ISOs | `dist/` | Also uncommitted, but it is output, not a draft |
| "The old files this stage replaced" | **Nowhere** | Git has every old version: `git log --oneline -- <file>` + `git show <sha>:<path>` |

**No formal file may reference a path under `tmp/`** — a reference means it isn't temporary,
so move it where it belongs per the promotion table in `claude-outputs/README.md`.
