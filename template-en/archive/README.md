# archive/ — history no longer maintained

**One way in, no way out.** Obsolete rules, dropped specs and documents from an earlier era move here.

- **Moving here is not deleting**: the numbers and old references stay valid, it is just out of the default reading path, so it costs no tokens at all.
- **Don't start work from here**: most of what's inside rests on premises that have already been overturned.
- If you really need a particular version of a file, **think about version control first**: `git log --oneline -- <old path>` + `git show <sha>:<old path>`.

## A suggested split

| Path | What it is |
|---|---|
| `legacy-<date>/` | A **full snapshot** of the old structure, keeping the pre-migration directory shape as-is. Come here to check "how was it written before" |
| `decisions-ledger.md` | The original old decision ledger, **not a character changed**. The "detail" column of the number-range files points at it |
| `memory/` | The old project memory / current-state originals |
| `reviews/` `deliveries/` | The old review and delivery record originals |
| `standards/` | Old rules superseded by the role handbooks and `ai/rules/` |
| `specs/` | Dropped technical specs |
