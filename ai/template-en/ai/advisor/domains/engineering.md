# Domain practices: general engineering (things to think about when building a product)

> **Not collaboration rules** (those live in `ai/rules/`) -- these are **things to think about when building a product**.
> Consulted on demand; never part of the opening read. Every row was paid for in a real incident, with the source project's traces removed.

## 1. Irreversible actions and rollback

| Practice | Why |
|---|---|
| **Finish every read-only check before an irreversible action** (space, permissions, dependencies, target in use) | Finding out halfway that it does not fit does not bring back what you already deleted |
| **If you cannot identify it, treat it as blocked** (fail-closed) | Letting something through when identification failed means the least certain case gets the most permissive handling |
| **Leave a way back**: a dangerous action gets a "confirm or auto-roll-back" timer | Change networking or permissions remotely and get it wrong, and the channel you would fix it through is gone |
| **A rollback restores the RUNNING state, not just files** | Files are back, the service still runs the old config, and the symptoms are stranger than no rollback at all |
| **Atomic replacement**: write a temp file, then rename -- never edit in place | Interrupted halfway you get either the whole old file or the whole new one, never half |
| **Unmount before deleting a directory** | Someone else's data is under that mount point, and `rm -rf` walks straight through it |

## 2. Timing and waiting

| Practice | Why |
|---|---|
| **Wait for the FACT of readiness, not a fixed number of seconds** | Sleeping 3s is enough on your machine and a random failure on a slow one |
| **Slow work goes async, with a timeout and a watchdog** -- never block the request thread | One stuck dependency drags the whole front end into "I clicked and nothing happened" |
| **Retries back off**; generated output has a ceiling; external calls have a deadline | Unbounded retries turn a transient fault into an avalanche |
| **A local jam must not take down everything**: one broken module, the rest still works | A shared global lock turns a single point of failure into a total one |
| **The server is the source of truth for state**; the client only displays it | Two copies drift, and the user believes the screen |
| **Transient states have to be slowed down deliberately to be measured** (delay the request to 1-2s and look) | The in-between state too fast to see is exactly where the bug lives |

## 3. Consistency and duplication

| Practice | Why |
|---|---|
| **One thing, one implementation**; after a change **search the whole repo for the same shape** | Two copies of one logic means fixing one and leaving a timer on the other |
| **The front end must not be narrower than the back end** | What the UI cannot do, users read as "the system does not support it" |
| **Without a stable ID, do not locate objects by matching text** | One wording change and every match breaks, silently |
| **Prefer what the platform already provides** | Your own copy will not follow upstream's bug fixes |
| **Cache-busting strings are content fingerprints**, never hand-written versions | "Changed it, no effect" is the class humans cannot be trusted to keep in sync |
| **A cache replaces the download, not the verification** | Skip verification on a cache hit and a bad copy is reused forever |

## 4. Delivery and release

| Practice | Why |
|---|---|
| **Reconcile the build**: the artifact's fingerprint must equal a fresh rebuild from source | Otherwise "changed but never written back" and "written back but never built" both look fine |
| **Release builds carry no debug entry point** | A debug port is designed for "only I can reach it", which stops being true once shipped |
| **Fixed but not deployed is not fixed**; after deploying, have a criterion that proves the new one is running | The machine still runs the old build, and every test passed on the new one |
| **Verify the first-time path separately** (first install, first start, empty data) | The old environment is fine and the new user hits a wall on step one |
| **Verify the upgrade path and old data separately** | A clean install working says nothing about an upgrade |
| **Walk the core path for real every round**, do not infer it from unit tests | A unit test that only covers pure functions is no test |
| **Think through cross-platform differences up front** (paths, case, line endings, permission bits) | Almost everything that goes red on another machine is one of these four |

## 5. Security and boundaries

| Practice | Why |
|---|---|
| **Secrets never land in plaintext**; not in logs, errors, or the front end | One screenshot is all it takes |
| **A security exception states its preconditions** (who, under what conditions, what happens when it expires) | An exception with no expiry is a permanent hole |
| **Trust boundaries follow the LISTENING surface**, not the directory layout | What decides who gets in is ports and interfaces, not which folder the code sits in |
| **Feasibility before the interface**: do not draw the button for something you have not proved you can do | Once the button exists, removing it costs you "you cut a feature" |
