# src/ — source (multiple projects)

```
src/
├── <project subdirectory>/   the main project
│   ├── <code directory>/
│   ├── tools/                self-check scripts that travel with the source (what they scan is the code right here)
│   └── <project metadata: go.mod / package.json / README.md / VERSION …>
└── <second project>/         the one you add later, **created as a sibling, not stuffed inside the first**
```

**Why the extra project layer**: a repo often grows a second project (a server, a CLI, an SDK).
One directory per project, each with its own dependency manifest and its own `tools/`, none of them interfering with the others;
shared things (deployment scripts, service units, the machine list) live in `ops/`, **not inside any one project**.

---

## The source directory rule: what may sit at a project root

**Only these are allowed at a project root**, everything else has a home of its own:

| Allowed | Notes |
|---|---|
| Code directories | Whatever the language/framework conventionally uses |
| `tools/` | Self-check scripts that travel with the source |
| Dependency and metadata files | `go.mod` / `package.json` / `VERSION` / `README.md` … |

**These classes may not appear in a source directory** (where each belongs is in brackets):

| Not allowed | Where it goes | Why |
|---|---|---|
| Deployment / ops scripts | `ops/scripts/`, `ops/units/` | What they deploy is the output, not part of the source; left in the source they get packaged along with it |
| Build output, installers, `*.tgz` | `dist/` (not committed) | Regenerable at any time |
| One-off packages and temporary scripts for moving files | `tmp/` (not committed) | Delete them yourself when done |
| Designs, preview pages, renderings | `product/design/` | Those are design assets |
| Snapshots of the runtime environment's state | `claude-outputs/shared/measurement/` | That is evidence, not source |
| Screenshots, measured output | `claude-outputs/shared/` | Same as above |

### When an unfamiliar file turns up in a source directory, check three things

1. **Who references it?** (`grep -rl` across the whole repo)
2. **Does version control track it?**
3. **Does its content already exist somewhere else?** (a file with the same name, a copy differing only in line endings, output the upstream can regenerate)

Those three answers settle **where it moves, or whether it moves at all**.
The three you hit most in practice: **a one-off transfer package** (zero references, untracked → doesn't move),
**a second copy of the same content** (differing only in line endings or path → keep one),
**a runtime environment snapshot** (looks like source, is actually evidence → into `claude-outputs/`).

## What's inside `src/<project>/` is the language's business, not this template's

**Organize it the way that language/framework officially does** — Go gets `cmd/` `internal/` `pkg/`,
Maven gets `src/main/java`, Python gets a package directory + `pyproject.toml`, a frontend framework gets whatever its scaffolding generates.

**Don't bring another language's habits over, and don't invent your own layout to make it "look tidy".**
The price of going against a language's conventions is **its whole toolchain stops working** (build, test discovery, packaging, IDE indexing),
and every newcomer has to learn your version first.

Which conventions this project uses is written in `ai/specs/tech-stack.md`, with a line in `docs/repo-layout.md` pointing there.
